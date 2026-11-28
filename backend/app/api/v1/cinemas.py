from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.schemas.cinema import CinemaWithAuditoriumsDTO
from app.services.cinema_service import CinemaService

router = APIRouter(prefix="/cinemas", tags=["Cinemas"])


@router.get("", response_model=list[CinemaWithAuditoriumsDTO])
async def list_cinemas(db: AsyncSession = Depends(get_db)) -> list[CinemaWithAuditoriumsDTO]:
    return await CinemaService(db).list_cinemas_with_auditoriums()
