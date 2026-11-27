import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import require_roles
from app.core.database import get_db
from app.schemas.auth import CurrentUserDTO
from app.schemas.catalog import (
    AdminOrderSummaryDTO,
    AuditoriumCreateDTO,
    AuditoriumDTO,
    MovieCreateDTO,
    MovieDTO,
    MovieUpdateDTO,
    ShowtimeCancelResponseDTO,
    ShowtimeCreateDTO,
    ShowtimeDTO,
    ShowtimeUpdateDTO,
)
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Cinema Admin"])
admin_guard = require_roles("PLATFORM_ADMIN", "CINEMA_ADMIN")


@router.post("/movies", response_model=MovieDTO, status_code=status.HTTP_201_CREATED)
async def create_movie(
    payload: MovieCreateDTO,
    _: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> MovieDTO:
    return await AdminService(db).create_movie(payload)


@router.patch("/movies/{movie_id}", response_model=MovieDTO)
async def update_movie(
    movie_id: uuid.UUID,
    payload: MovieUpdateDTO,
    _: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> MovieDTO:
    return await AdminService(db).update_movie(movie_id, payload)


@router.post(
    "/cinemas/{cinema_id}/auditoriums",
    response_model=AuditoriumDTO,
    status_code=status.HTTP_201_CREATED,
)
async def create_auditorium(
    cinema_id: uuid.UUID,
    payload: AuditoriumCreateDTO,
    actor: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> AuditoriumDTO:
    return await AdminService(db).create_auditorium(cinema_id, payload, actor)


@router.post("/showtimes", response_model=ShowtimeDTO, status_code=status.HTTP_201_CREATED)
async def create_showtime(
    payload: ShowtimeCreateDTO,
    actor: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> ShowtimeDTO:
    return await AdminService(db).create_showtime(payload, actor)


@router.patch("/showtimes/{showtime_id}", response_model=ShowtimeDTO)
async def update_showtime(
    showtime_id: uuid.UUID,
    payload: ShowtimeUpdateDTO,
    actor: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> ShowtimeDTO:
    return await AdminService(db).update_showtime(showtime_id, payload, actor)


@router.post("/showtimes/{showtime_id}/cancel", response_model=ShowtimeCancelResponseDTO)
async def cancel_showtime(
    showtime_id: uuid.UUID,
    actor: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> ShowtimeCancelResponseDTO:
    return await AdminService(db).cancel_showtime(showtime_id, actor)


@router.get("/orders", response_model=list[AdminOrderSummaryDTO])
async def list_admin_orders(
    cinema_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    actor: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> list[AdminOrderSummaryDTO]:
    return await AdminService(db).list_admin_orders(actor, cinema_id, status_filter)
