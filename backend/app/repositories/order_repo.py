import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import (
    AuditLog,
    Order,
    OrderItem,
    Payment,
    Refund,
    Seat,
    Showtime,
    ShowtimeSeat,
    Ticket,
)


class OrderRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_order_by_idempotency_key(self, idempotency_key: str) -> Order | None:
        stmt = select(Order).where(Order.idempotency_key == idempotency_key)
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def get_order_by_id(self, order_id: uuid.UUID) -> Order | None:
        return (await self.db.execute(select(Order).where(Order.id == order_id))).scalar_one_or_none()

    async def get_showtime(self, showtime_id: uuid.UUID) -> Showtime | None:
        return (await self.db.execute(select(Showtime).where(Showtime.id == showtime_id))).scalar_one_or_none()

    async def atomic_lock_seats(
        self,
        showtime_id: uuid.UUID,
        seat_ids: list[uuid.UUID],
        now_utc: datetime,
        hold_expires_at: datetime,
    ) -> list[tuple[uuid.UUID, Decimal]]:
        # Core 5-line anti-oversell SQL: atomic lazy reclamation + optimistic version bump
        stmt = (
            update(ShowtimeSeat)
            .where(
                ShowtimeSeat.showtime_id == showtime_id,
                ShowtimeSeat.id.in_(seat_ids),
                or_(
                    ShowtimeSeat.status == "AVAILABLE",
                    (ShowtimeSeat.status == "HELD") & (ShowtimeSeat.hold_expires_at < now_utc),
                ),
            )
            .values(
                status="HELD",
                hold_expires_at=hold_expires_at,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
            .returning(ShowtimeSeat.id, ShowtimeSeat.price)
        )
        rows = (await self.db.execute(stmt)).all()
        return [(r[0], r[1]) for r in rows]

    async def bind_held_seats_to_order(self, seat_ids: list[uuid.UUID], order_id: uuid.UUID) -> None:
        stmt = (
            update(ShowtimeSeat)
            .where(ShowtimeSeat.id.in_(seat_ids))
            .values(held_by_order_id=order_id)
        )
        await self.db.execute(stmt)

    async def create_order_and_items(self, order: Order, items: list[OrderItem]) -> Order:
        self.db.add(order)
        await self.db.flush()
        for item in items:
            item.order_id = order.id
        self.db.add_all(items)
        await self.db.flush()
        return order

    async def list_user_orders(self, user_id: uuid.UUID) -> list[Order]:
        stmt = select(Order).where(Order.user_id == user_id).order_by(Order.created_at.desc())
        return list((await self.db.execute(stmt)).scalars().all())

    async def get_order_items_with_seats(self, order_id: uuid.UUID) -> list[tuple[OrderItem, Seat]]:
        stmt = (
            select(OrderItem, Seat)
            .join(ShowtimeSeat, ShowtimeSeat.id == OrderItem.showtime_seat_id)
            .join(Seat, Seat.id == ShowtimeSeat.seat_id)
            .where(OrderItem.order_id == order_id)
            .order_by(Seat.row_label.asc(), Seat.seat_number.asc())
        )
        return [(r[0], r[1]) for r in (await self.db.execute(stmt)).all()]

    async def get_tickets_by_order(self, order_id: uuid.UUID) -> list[Ticket]:
        stmt = select(Ticket).where(Ticket.order_id == order_id).order_by(Ticket.issued_at.asc())
        return list((await self.db.execute(stmt)).scalars().all())

    # ---------- Payments ----------
    async def get_payment_by_idempotency_key(self, idempotency_key: str) -> Payment | None:
        stmt = select(Payment).where(Payment.idempotency_key == idempotency_key)
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def get_succeeded_payment(self, order_id: uuid.UUID) -> Payment | None:
        stmt = select(Payment).where(Payment.order_id == order_id, Payment.status == "SUCCEEDED")
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def create_payment(self, payment: Payment) -> Payment:
        self.db.add(payment)
        await self.db.flush()
        return payment

    async def mark_order_expired_and_release(self, order: Order, now_utc: datetime) -> None:
        order.status = "EXPIRED"
        order.updated_at = now_utc
        await self.db.execute(
            update(ShowtimeSeat)
            .where(ShowtimeSeat.held_by_order_id == order.id, ShowtimeSeat.status == "HELD")
            .values(
                status="AVAILABLE",
                held_by_order_id=None,
                hold_expires_at=None,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
        )

    async def mark_order_seats_sold(self, order_id: uuid.UUID, now_utc: datetime) -> int:
        stmt = (
            update(ShowtimeSeat)
            .where(ShowtimeSeat.held_by_order_id == order_id, ShowtimeSeat.status == "HELD")
            .values(
                status="SOLD",
                hold_expires_at=None,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
        )
        res = await self.db.execute(stmt)
        return res.rowcount or 0

    async def create_tickets(self, tickets: list[Ticket]) -> list[Ticket]:
        self.db.add_all(tickets)
        await self.db.flush()
        return tickets

    # ---------- Refunds & Audit ----------
    async def execute_refund_updates(
        self,
        order: Order,
        refund: Refund,
        now_utc: datetime,
    ) -> Refund:
        self.db.add(refund)
        order.status = "REFUNDED"
        order.updated_at = now_utc

        await self.db.execute(
            update(Ticket).where(Ticket.order_id == order.id).values(status="REFUNDED")
        )
        await self.db.execute(
            update(ShowtimeSeat)
            .where(ShowtimeSeat.held_by_order_id == order.id)
            .values(
                status="AVAILABLE",
                held_by_order_id=None,
                hold_expires_at=None,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
        )
        await self.db.flush()
        return refund

    async def write_audit_log(
        self,
        actor_user_id: uuid.UUID | None,
        action: str,
        entity_type: str,
        entity_id: uuid.UUID,
        metadata_json: dict,
    ) -> None:
        self.db.add(
            AuditLog(
                actor_user_id=actor_user_id,
                action=action,
                entity_type=entity_type,
                entity_id=entity_id,
                metadata_json=metadata_json,
            )
        )
