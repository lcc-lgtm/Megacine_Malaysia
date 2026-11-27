import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.models.entities import Order, OrderItem, Payment, Refund, Ticket
from app.repositories.order_repo import OrderRepository
from app.schemas.auth import CurrentUserDTO
from app.schemas.order import (
    OrderCreateDTO,
    OrderDTO,
    OrderItemDTO,
    PaymentRequestDTO,
    PaymentResultDTO,
    RefundRequestDTO,
    RefundResponseDTO,
    TicketDTO,
)


class OrderService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = OrderRepository(db)
        self.settings = get_settings()

    async def _build_order_dto(self, order: Order) -> OrderDTO:
        item_rows = await self.repo.get_order_items_with_seats(order.id)
        tickets = await self.repo.get_tickets_by_order(order.id)
        return OrderDTO(
            id=order.id,
            order_no=order.order_no,
            user_id=order.user_id,
            showtime_id=order.showtime_id,
            status=order.status,
            subtotal_amount=order.subtotal_amount,
            discount_amount=order.discount_amount,
            total_amount=order.total_amount,
            hold_expires_at=order.hold_expires_at,
            created_at=order.created_at,
            items=[
                OrderItemDTO(
                    id=item.id,
                    showtime_seat_id=item.showtime_seat_id,
                    row_label=seat.row_label,
                    seat_number=seat.seat_number,
                    seat_zone=seat.seat_zone,
                    unit_price=item.unit_price,
                )
                for item, seat in item_rows
            ],
            tickets=[
                TicketDTO(
                    id=t.id,
                    ticket_code=t.ticket_code,
                    qr_payload=t.qr_payload,
                    status=t.status,
                    issued_at=t.issued_at,
                    used_at=t.used_at,
                )
                for t in tickets
            ],
        )

    async def create_order(
        self,
        payload: OrderCreateDTO,
        idempotency_key: str,
        actor: CurrentUserDTO,
    ) -> OrderDTO:
        unique_seat_ids = sorted(set(payload.showtime_seat_ids))
        if not unique_seat_ids or len(unique_seat_ids) > self.settings.MAX_SEATS_PER_ORDER:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="MAX_SEATS_EXCEEDED",
            )

        # 1. Idempotency replay check
        existing = await self.repo.get_order_by_idempotency_key(idempotency_key)
        if existing:
            if existing.user_id != actor.id:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="IDEMPOTENCY_KEY_CONFLICT")
            return await self._build_order_dto(existing)

        # 2. Validate showtime is open for booking
        now_utc = datetime.now(timezone.utc)
        showtime = await self.repo.get_showtime(payload.showtime_id)
        if not showtime or showtime.status != "SCHEDULED":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Showtime not available")
        if showtime.start_time <= now_utc:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Showtime has already started")

        # 3. Atomic anti-overselling seat lock
        hold_expires_at = now_utc + timedelta(seconds=self.settings.SEAT_HOLD_SECONDS)
        locked = await self.repo.atomic_lock_seats(
            showtime_id=showtime.id,
            seat_ids=unique_seat_ids,
            now_utc=now_utc,
            hold_expires_at=hold_expires_at,
        )
        if len(locked) != len(unique_seat_ids):
            await self.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="SEAT_UNAVAILABLE",
            )

        # 4. Create Order, OrderItems, and bind held_by_order_id in the same transaction
        subtotal = sum((price for _, price in locked), Decimal("0.00"))
        order_no = f"MC{now_utc.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
        order = Order(
            order_no=order_no,
            user_id=actor.id,
            showtime_id=showtime.id,
            status="PENDING_PAYMENT",
            subtotal_amount=subtotal,
            discount_amount=Decimal("0.00"),
            total_amount=subtotal,
            hold_expires_at=hold_expires_at,
            idempotency_key=idempotency_key,
        )
        items = [
            OrderItem(showtime_seat_id=st_seat_id, unit_price=price)
            for st_seat_id, price in locked
        ]
        try:
            await self.repo.create_order_and_items(order, items)
            await self.repo.bind_held_seats_to_order(unique_seat_ids, order.id)
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            replayed = await self.repo.get_order_by_idempotency_key(idempotency_key)
            if replayed and replayed.user_id == actor.id:
                return await self._build_order_dto(replayed)
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ORDER_CREATION_CONFLICT")

        return await self._build_order_dto(order)

    async def list_my_orders(self, actor: CurrentUserDTO) -> list[OrderDTO]:
        orders = await self.repo.list_user_orders(actor.id)
        return [await self._build_order_dto(o) for o in orders]

    async def get_my_order(self, order_id: uuid.UUID, actor: CurrentUserDTO) -> OrderDTO:
        order = await self.repo.get_order_by_id(order_id)
        if not order or order.user_id != actor.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
        return await self._build_order_dto(order)

    async def pay_order(
        self,
        order_id: uuid.UUID,
        payload: PaymentRequestDTO,
        idempotency_key: str,
        actor: CurrentUserDTO,
    ) -> tuple[int, PaymentResultDTO]:
        # 1. Payment idempotency replay check
        existing_pay = await self.repo.get_payment_by_idempotency_key(idempotency_key)
        if existing_pay:
            order = await self.repo.get_order_by_id(existing_pay.order_id)
            if not order or order.user_id != actor.id:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="IDEMPOTENCY_KEY_CONFLICT")
            tickets = await self.repo.get_tickets_by_order(order.id)
            http_code = (
                status.HTTP_200_OK
                if existing_pay.status == "SUCCEEDED"
                else (status.HTTP_402_PAYMENT_REQUIRED if existing_pay.status == "FAILED" else status.HTTP_504_GATEWAY_TIMEOUT)
            )
            return http_code, PaymentResultDTO(
                payment_id=existing_pay.id,
                provider=existing_pay.provider,
                provider_tx_id=existing_pay.provider_tx_id,
                payment_status=existing_pay.status,
                order_id=order.id,
                order_status=order.status,
                amount=existing_pay.amount,
                message="Idempotent payment replay",
                tickets=[
                    TicketDTO(
                        id=t.id,
                        ticket_code=t.ticket_code,
                        qr_payload=t.qr_payload,
                        status=t.status,
                        issued_at=t.issued_at,
                        used_at=t.used_at,
                    )
                    for t in tickets
                ],
            )

        # 2. Ownership & status validation
        order = await self.repo.get_order_by_id(order_id)
        if not order or order.user_id != actor.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
        if order.status == "CONFIRMED":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ORDER_ALREADY_PAID")
        if order.status != "PENDING_PAYMENT":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ORDER_NOT_PAYABLE")

        # 3. Hold window expiration guard
        now_utc = datetime.now(timezone.utc)
        if order.hold_expires_at < now_utc:
            await self.repo.mark_order_expired_and_release(order, now_utc)
            await self.db.commit()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ORDER_EXPIRED")

        # 4. Mock Payment Adapter execution
        provider_tx_id = f"MOCK-{uuid.uuid4().hex[:12].upper()}"
        if payload.scenario == "FAILED":
            payment = await self.repo.create_payment(
                Payment(
                    order_id=order.id,
                    provider="MOCK_PAY",
                    provider_tx_id=provider_tx_id,
                    amount=order.total_amount,
                    status="FAILED",
                    idempotency_key=idempotency_key,
                )
            )
            await self.db.commit()
            return status.HTTP_402_PAYMENT_REQUIRED, PaymentResultDTO(
                payment_id=payment.id,
                provider=payment.provider,
                provider_tx_id=payment.provider_tx_id,
                payment_status="FAILED",
                order_id=order.id,
                order_status=order.status,
                amount=payment.amount,
                message="Mock payment failed; retry allowed before hold expires",
            )

        if payload.scenario == "TIMEOUT":
            payment = await self.repo.create_payment(
                Payment(
                    order_id=order.id,
                    provider="MOCK_PAY",
                    provider_tx_id=provider_tx_id,
                    amount=order.total_amount,
                    status="UNKNOWN",
                    idempotency_key=idempotency_key,
                )
            )
            await self.db.commit()
            return status.HTTP_504_GATEWAY_TIMEOUT, PaymentResultDTO(
                payment_id=payment.id,
                provider=payment.provider,
                provider_tx_id=payment.provider_tx_id,
                payment_status="UNKNOWN",
                order_id=order.id,
                order_status=order.status,
                amount=payment.amount,
                message="Mock payment gateway timeout; retry allowed before hold expires",
            )

        # SUCCEEDED -> Atomic confirm order, mark seats SOLD, issue QR e-tickets
        payment = await self.repo.create_payment(
            Payment(
                order_id=order.id,
                provider="MOCK_PAY",
                provider_tx_id=provider_tx_id,
                amount=order.total_amount,
                status="SUCCEEDED",
                idempotency_key=idempotency_key,
            )
        )
        order.status = "CONFIRMED"
        order.updated_at = now_utc

        sold_count = await self.repo.mark_order_seats_sold(order.id, now_utc)
        item_rows = await self.repo.get_order_items_with_seats(order.id)
        if sold_count != len(item_rows):
            await self.db.rollback()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="SEAT_HOLD_LOST")

        new_tickets: list[Ticket] = []
        for item, seat in item_rows:
            t_code = f"TKT-{uuid.uuid4().hex[:10].upper()}"
            qr = f"MEGACINE|{order.order_no}|{t_code}|{seat.row_label}{seat.seat_number}"
            new_tickets.append(
                Ticket(
                    order_id=order.id,
                    order_item_id=item.id,
                    ticket_code=t_code,
                    qr_payload=qr,
                    status="VALID",
                )
            )
        await self.repo.create_tickets(new_tickets)
        await self.db.commit()

        return status.HTTP_200_OK, PaymentResultDTO(
            payment_id=payment.id,
            provider=payment.provider,
            provider_tx_id=payment.provider_tx_id,
            payment_status="SUCCEEDED",
            order_id=order.id,
            order_status="CONFIRMED",
            amount=payment.amount,
            message="Payment succeeded and e-tickets issued",
            tickets=[
                TicketDTO(
                    id=t.id,
                    ticket_code=t.ticket_code,
                    qr_payload=t.qr_payload,
                    status=t.status,
                    issued_at=t.issued_at,
                    used_at=t.used_at,
                )
                for t in new_tickets
            ],
        )

    async def refund_order(
        self,
        order_id: uuid.UUID,
        payload: RefundRequestDTO,
        actor: CurrentUserDTO,
    ) -> RefundResponseDTO:
        order = await self.repo.get_order_by_id(order_id)
        if not order or order.user_id != actor.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
        if order.status != "CONFIRMED":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only CONFIRMED orders can be refunded")

        showtime = await self.repo.get_showtime(order.showtime_id)
        if not showtime:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Showtime not found")

        now_utc = datetime.now(timezone.utc)
        cutoff = timedelta(minutes=self.settings.REFUND_CUTOFF_MINUTES)
        if showtime.start_time - now_utc < cutoff:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="REFUND_CUTOFF_PASSED")

        payment = await self.repo.get_succeeded_payment(order.id)
        if not payment:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No succeeded payment found for order")

        refund = Refund(
            order_id=order.id,
            payment_id=payment.id,
            amount=order.total_amount,
            reason=payload.reason,
            status="SUCCEEDED",
        )
        await self.repo.execute_refund_updates(order, refund, now_utc)
        await self.repo.write_audit_log(
            actor_user_id=actor.id,
            action="ORDER_REFUNDED",
            entity_type="order",
            entity_id=order.id,
            metadata_json={
                "order_no": order.order_no,
                "refund_id": str(refund.id),
                "amount": str(order.total_amount),
                "reason": payload.reason,
            },
        )
        await self.db.commit()

        return RefundResponseDTO(
            refund_id=refund.id,
            order_id=order.id,
            order_status="REFUNDED",
            refund_status="SUCCEEDED",
            amount=refund.amount,
            reason=refund.reason,
        )
