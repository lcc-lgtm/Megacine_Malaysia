# backend/app/repositories/ops_repo.py
from datetime import datetime
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Order, ShowtimeSeat


class OpsRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def expire_stale_orders_and_seats(self, now_utc: datetime) -> tuple[int, int]:
        # 1. Batch-mark expired PENDING_PAYMENT orders as EXPIRED
        order_stmt = (
            update(Order)
            .where(Order.status == "PENDING_PAYMENT", Order.hold_expires_at < now_utc)
            .values(status="EXPIRED", updated_at=now_utc)
        )
        order_res = await self.db.execute(order_stmt)

        # 2. Release expired HELD seats back to AVAILABLE with optimistic version bump
        seat_stmt = (
            update(ShowtimeSeat)
            .where(ShowtimeSeat.status == "HELD", ShowtimeSeat.hold_expires_at < now_utc)
            .values(
                status="AVAILABLE",
                held_by_order_id=None,
                hold_expires_at=None,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
        )
        seat_res = await self.db.execute(seat_stmt)
        return (order_res.rowcount or 0, seat_res.rowcount or 0)
