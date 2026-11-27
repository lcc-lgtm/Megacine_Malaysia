import uuid
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Auditorium, Movie, Seat, Showtime
from app.repositories.admin_repo import AdminRepository
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


def _row_index_to_label(idx: int) -> str:
    label = ""
    n = idx
    while True:
        label = chr(ord("A") + (n % 26)) + label
        n = n // 26 - 1
        if n < 0:
            break
    return label


class AdminService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = AdminRepository(db)

    def _is_platform_admin(self, user: CurrentUserDTO) -> bool:
        return any(r.code == "PLATFORM_ADMIN" for r in user.roles)

    def _assert_cinema_access(self, user: CurrentUserDTO, cinema_id: uuid.UUID) -> None:
        if self._is_platform_admin(user):
            return
        allowed = {r.cinema_id for r in user.roles if r.code == "CINEMA_ADMIN" and r.cinema_id}
        if cinema_id not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied for the requested cinema scope",
            )

    # ---------- Movies ----------
    async def create_movie(self, payload: MovieCreateDTO) -> MovieDTO:
        movie = Movie(**payload.model_dump())
        created = await self.repo.create_movie(movie)
        await self.db.commit()
        return MovieDTO.model_validate(created)

    async def update_movie(self, movie_id: uuid.UUID, payload: MovieUpdateDTO) -> MovieDTO:
        movie = await self.repo.get_movie(movie_id)
        if not movie:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(movie, field, value)
        await self.db.commit()
        await self.db.refresh(movie)
        return MovieDTO.model_validate(movie)

    # ---------- Auditoriums & Batch Seats ----------
    async def create_auditorium(
        self,
        cinema_id: uuid.UUID,
        payload: AuditoriumCreateDTO,
        actor: CurrentUserDTO,
    ) -> AuditoriumDTO:
        self._assert_cinema_access(actor, cinema_id)

        cinema = await self.repo.get_cinema(cinema_id)
        if not cinema:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cinema not found")

        existing = await self.repo.get_auditorium_by_name(cinema_id, payload.name)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Auditorium name already exists in this cinema",
            )

        vip_row_set = {r.strip().upper() for r in payload.vip_rows}
        auditorium = Auditorium(
            cinema_id=cinema_id,
            name=payload.name,
            total_rows=payload.total_rows,
            total_cols=payload.total_cols,
        )
        seats: list[Seat] = []
        for r_idx in range(payload.total_rows):
            row_label = _row_index_to_label(r_idx)
            zone = "VIP" if row_label in vip_row_set else "STANDARD"
            for col in range(1, payload.total_cols + 1):
                seats.append(
                    Seat(
                        row_label=row_label,
                        seat_number=col,
                        seat_zone=zone,
                        seat_type="STANDARD",
                    )
                )

        created = await self.repo.create_auditorium_with_seats(auditorium, seats)
        await self.db.commit()
        return AuditoriumDTO(
            id=created.id,
            cinema_id=created.cinema_id,
            name=created.name,
            total_rows=created.total_rows,
            total_cols=created.total_cols,
            seats_created=len(seats),
        )

    # ---------- Showtimes ----------
    async def create_showtime(self, payload: ShowtimeCreateDTO, actor: CurrentUserDTO) -> ShowtimeDTO:
        auditorium = await self.repo.get_auditorium(payload.auditorium_id)
        if not auditorium:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Auditorium not found")
        self._assert_cinema_access(actor, auditorium.cinema_id)

        movie = await self.repo.get_movie(payload.movie_id)
        if not movie:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")

        end_time = payload.end_time or (
            payload.start_time + timedelta(minutes=movie.duration_minutes + 15)
        )
        if end_time <= payload.start_time:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="end_time must be after start_time")

        if await self.repo.has_overlapping_showtime(auditorium.id, payload.start_time, end_time):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="SHOWTIME_OVERLAP")

        seats = await self.repo.get_seats_by_auditorium(auditorium.id)
        if not seats:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Auditorium has no seats configured")

        showtime = Showtime(
            movie_id=movie.id,
            auditorium_id=auditorium.id,
            start_time=payload.start_time,
            end_time=end_time,
            base_price=payload.base_price,
            status="SCHEDULED",
        )
        created = await self.repo.create_showtime_with_seats(showtime, seats, payload.vip_surcharge)
        await self.db.commit()

        full = await self.repo.get_showtime_full(created.id)
        st, mv, aud, cin = full
        return ShowtimeDTO(
            id=st.id,
            movie_id=mv.id,
            movie_title=mv.title,
            cinema_id=cin.id,
            cinema_name=cin.name,
            auditorium_id=aud.id,
            auditorium_name=aud.name,
            start_time=st.start_time,
            end_time=st.end_time,
            base_price=st.base_price,
            status=st.status,
        )

    async def update_showtime(
        self,
        showtime_id: uuid.UUID,
        payload: ShowtimeUpdateDTO,
        actor: CurrentUserDTO,
    ) -> ShowtimeDTO:
        full = await self.repo.get_showtime_full(showtime_id)
        if not full:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Showtime not found")
        st, mv, aud, cin = full
        self._assert_cinema_access(actor, cin.id)

        updates = payload.model_dump(exclude_unset=True)
        if any(k in updates for k in ("start_time", "end_time", "base_price")):
            if await self.repo.count_confirmed_orders(st.id) > 0:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Cannot modify time or price of a showtime with confirmed orders",
                )

        new_start = updates.get("start_time", st.start_time)
        new_end = updates.get("end_time", st.end_time)
        if new_end <= new_start:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="end_time must be after start_time")

        if await self.repo.has_overlapping_showtime(aud.id, new_start, new_end, exclude_showtime_id=st.id):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="SHOWTIME_OVERLAP")

        for field, value in updates.items():
            setattr(st, field, value)

        await self.db.commit()
        await self.db.refresh(st)
        return ShowtimeDTO(
            id=st.id,
            movie_id=mv.id,
            movie_title=mv.title,
            cinema_id=cin.id,
            cinema_name=cin.name,
            auditorium_id=aud.id,
            auditorium_name=aud.name,
            start_time=st.start_time,
            end_time=st.end_time,
            base_price=st.base_price,
            status=st.status,
        )

    async def cancel_showtime(self, showtime_id: uuid.UUID, actor: CurrentUserDTO) -> ShowtimeCancelResponseDTO:
        full = await self.repo.get_showtime_full(showtime_id)
        if not full:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Showtime not found")
        st, mv, aud, cin = full
        self._assert_cinema_access(actor, cin.id)

        if st.status == "CANCELLED":
            return ShowtimeCancelResponseDTO(showtime_id=st.id, status=st.status, refunded_orders_count=0)

        now_utc = datetime.now(timezone.utc)
        refunded_count = await self.repo.cancel_showtime_cascade(st, now_utc)
        await self.repo.write_audit_log(
            actor_user_id=actor.id,
            action="SHOWTIME_CANCELLED",
            entity_type="showtime",
            entity_id=st.id,
            metadata_json={
                "cinema_id": str(cin.id),
                "movie_title": mv.title,
                "refunded_orders_count": refunded_count,
            },
        )
        await self.db.commit()
        return ShowtimeCancelResponseDTO(
            showtime_id=st.id,
            status="CANCELLED",
            refunded_orders_count=refunded_count,
        )

    # ---------- Cinema-Scoped Orders ----------
    async def list_admin_orders(
        self,
        actor: CurrentUserDTO,
        cinema_id: uuid.UUID | None = None,
        status_filter: str | None = None,
    ) -> list[AdminOrderSummaryDTO]:
        if self._is_platform_admin(actor):
            target_cinemas = [cinema_id] if cinema_id else None
        else:
            allowed = [r.cinema_id for r in actor.roles if r.code == "CINEMA_ADMIN" and r.cinema_id]
            if cinema_id:
                if cinema_id not in allowed:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied for the requested cinema scope",
                    )
                target_cinemas = [cinema_id]
            else:
                target_cinemas = allowed

        rows = await self.repo.list_orders_by_cinemas(target_cinemas, status_filter)
        return [
            AdminOrderSummaryDTO(
                id=order.id,
                order_no=order.order_no,
                user_id=order.user_id,
                showtime_id=order.showtime_id,
                cinema_id=cid,
                status=order.status,
                total_amount=order.total_amount,
                hold_expires_at=order.hold_expires_at,
                created_at=order.created_at,
            )
            for order, cid in rows
        ]
