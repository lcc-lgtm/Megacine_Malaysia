import uuid
from datetime import date, datetime, time, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Auditorium, Cinema, Movie, Seat, Showtime, ShowtimeSeat


class CatalogRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_movies(self, status_filter: str | None = None) -> list[Movie]:
        stmt = select(Movie).order_by(Movie.release_date.desc().nullslast(), Movie.created_at.desc())
        if status_filter:
            stmt = stmt.where(Movie.status == status_filter)
        else:
            stmt = stmt.where(Movie.status.in_(["NOW_SHOWING", "COMING_SOON"]))
        return list((await self.db.execute(stmt)).scalars().all())

    async def get_movie_by_id(self, movie_id: uuid.UUID) -> Movie | None:
        return (await self.db.execute(select(Movie).where(Movie.id == movie_id))).scalar_one_or_none()

    async def list_showtimes(
        self,
        movie_id: uuid.UUID | None = None,
        cinema_id: uuid.UUID | None = None,
        show_date: date | None = None,
    ) -> list[tuple[Showtime, Movie, Auditorium, Cinema]]:
        stmt = (
            select(Showtime, Movie, Auditorium, Cinema)
            .join(Movie, Movie.id == Showtime.movie_id)
            .join(Auditorium, Auditorium.id == Showtime.auditorium_id)
            .join(Cinema, Cinema.id == Auditorium.cinema_id)
            .where(Showtime.status == "SCHEDULED", Cinema.is_active.is_(True))
            .order_by(Showtime.start_time.asc())
        )
        if movie_id:
            stmt = stmt.where(Showtime.movie_id == movie_id)
        if cinema_id:
            stmt = stmt.where(Cinema.id == cinema_id)
        if show_date:
            day_start = datetime.combine(show_date, time.min, tzinfo=timezone.utc)
            day_end = datetime.combine(show_date, time.max, tzinfo=timezone.utc)
            stmt = stmt.where(Showtime.start_time >= day_start, Showtime.start_time <= day_end)

        return list((await self.db.execute(stmt)).all())

    async def get_showtime_with_auditorium(self, showtime_id: uuid.UUID) -> tuple[Showtime, Auditorium] | None:
        stmt = (
            select(Showtime, Auditorium)
            .join(Auditorium, Auditorium.id == Showtime.auditorium_id)
            .where(Showtime.id == showtime_id)
        )
        row = (await self.db.execute(stmt)).first()
        return (row[0], row[1]) if row else None

    async def list_showtime_seats(self, showtime_id: uuid.UUID) -> list[tuple[ShowtimeSeat, Seat]]:
        stmt = (
            select(ShowtimeSeat, Seat)
            .join(Seat, Seat.id == ShowtimeSeat.seat_id)
            .where(ShowtimeSeat.showtime_id == showtime_id)
            .order_by(Seat.row_label.asc(), Seat.seat_number.asc())
        )
        return list((await self.db.execute(stmt)).all())
