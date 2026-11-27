# backend/app/services/ops_service.py
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.ops_repo import OpsRepository
from app.schemas.ops import CleanupHoldsResponseDTO


class OpsService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = OpsRepository(db)

    async def run_hold_cleanup(self) -> CleanupHoldsResponseDTO:
        now_utc = datetime.now(timezone.utc)
        expired_orders, released_seats = await self.repo.expire_stale_orders_and_seats(now_utc)
        await self.db.commit()
        return CleanupHoldsResponseDTO(
            status="ok",
            expired_orders_count=expired_orders,
            released_seats_count=released_seats,
            executed_at=now_utc,
        )
