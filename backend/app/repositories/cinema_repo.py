from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Auditorium, Cinema


class CinemaRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_active_cinemas(self) -> list[Cinema]:
        stmt = select(Cinema).where(Cinema.is_active.is_(True)).order_by(Cinema.name.asc())
        return list((await self.db.execute(stmt)).scalars().all())

    async def list_all_auditoriums(self) -> list[Auditorium]:
        stmt = select(Auditorium).order_by(Auditorium.name.asc())
        return list((await self.db.execute(stmt)).scalars().all())
