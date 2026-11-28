from collections import defaultdict
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.cinema_repo import CinemaRepository
from app.schemas.cinema import AuditoriumBriefDTO, CinemaWithAuditoriumsDTO


class CinemaService:
    def __init__(self, db: AsyncSession) -> None:
        self.repo = CinemaRepository(db)

    async def list_cinemas_with_auditoriums(self) -> list[CinemaWithAuditoriumsDTO]:
        cinemas = await self.repo.list_active_cinemas()
        auditoriums = await self.repo.list_all_auditoriums()
        by_cinema = defaultdict(list)
        for aud in auditoriums:
            by_cinema[aud.cinema_id].append(AuditoriumBriefDTO.model_validate(aud))
        return [
            CinemaWithAuditoriumsDTO(
                id=c.id,
                name=c.name,
                address=c.address,
                city=c.city,
                state=c.state,
                auditoriums=by_cinema[c.id],
            )
            for c in cinemas
        ]
