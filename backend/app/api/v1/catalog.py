import uuid
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.schemas.catalog import MovieDTO, ShowtimeDTO, ShowtimeSeatMapDTO
from app.services.catalog_service import CatalogService

router = APIRouter(tags=["Catalog & Seat Map"])


@router.get("/movies", response_model=list[MovieDTO])
async def list_movies(
    status: str | None = Query(default=None, description="COMING_SOON | NOW_SHOWING | ARCHIVED"),
    db: AsyncSession = Depends(get_db),
) -> list[MovieDTO]:
    return await CatalogService(db).list_movies(status)


@router.get("/movies/{movie_id}", response_model=MovieDTO)
async def get_movie(movie_id: uuid.UUID, db: AsyncSession = Depends(get_db)) -> MovieDTO:
    return await CatalogService(db).get_movie(movie_id)


@router.get("/showtimes", response_model=list[ShowtimeDTO])
async def list_showtimes(
    movie_id: uuid.UUID | None = Query(default=None),
    cinema_id: uuid.UUID | None = Query(default=None),
    show_date: date | None = Query(default=None, alias="date"),
    db: AsyncSession = Depends(get_db),
) -> list[ShowtimeDTO]:
    return await CatalogService(db).list_showtimes(movie_id, cinema_id, show_date)


@router.get("/showtimes/{showtime_id}/seats", response_model=ShowtimeSeatMapDTO)
async def get_showtime_seats(
    showtime_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
) -> ShowtimeSeatMapDTO:
    return await CatalogService(db).get_seat_map(showtime_id)
