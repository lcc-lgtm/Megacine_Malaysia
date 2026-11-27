import uuid
from datetime import date, datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.catalog_repo import CatalogRepository
from app.schemas.catalog import (
    MovieDTO,
    ShowtimeDTO,
    ShowtimeSeatItemDTO,
    ShowtimeSeatMapDTO,
)


class CatalogService:
    def __init__(self, db: AsyncSession) -> None:
        self.repo = CatalogRepository(db)

    async def list_movies(self, status_filter: str | None = None) -> list[MovieDTO]:
        movies = await self.repo.list_movies(status_filter)
        return [MovieDTO.model_validate(m) for m in movies]

    async def get_movie(self, movie_id: uuid.UUID) -> MovieDTO:
        movie = await self.repo.get_movie_by_id(movie_id)
        if not movie:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")
        return MovieDTO.model_validate(movie)

    async def list_showtimes(
        self,
        movie_id: uuid.UUID | None = None,
        cinema_id: uuid.UUID | None = None,
        show_date: date | None = None,
    ) -> list[ShowtimeDTO]:
        rows = await self.repo.list_showtimes(movie_id, cinema_id, show_date)
        return [
            ShowtimeDTO(
                id=st.id,
                movie_id=movie.id,
                movie_title=movie.title,
                cinema_id=cinema.id,
                cinema_name=cinema.name,
                auditorium_id=aud.id,
                auditorium_name=aud.name,
                start_time=st.start_time,
                end_time=st.end_time,
                base_price=st.base_price,
                status=st.status,
            )
            for st, movie, aud, cinema in rows
        ]

    async def get_seat_map(self, showtime_id: uuid.UUID) -> ShowtimeSeatMapDTO:
        pair = await self.repo.get_showtime_with_auditorium(showtime_id)
        if not pair:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Showtime not found")
        st, aud = pair

        now_utc = datetime.now(timezone.utc)
        rows = await self.repo.list_showtime_seats(st.id)

        seat_items: list[ShowtimeSeatItemDTO] = []
        for st_seat, phys_seat in rows:
            # Primary lazy projection: expired HELD seats immediately appear AVAILABLE
            effective_status = st_seat.status
            if st_seat.status == "HELD" and st_seat.hold_expires_at and st_seat.hold_expires_at < now_utc:
                effective_status = "AVAILABLE"

            seat_items.append(
                ShowtimeSeatItemDTO(
                    showtime_seat_id=st_seat.id,
                    seat_id=phys_seat.id,
                    row_label=phys_seat.row_label,
                    seat_number=phys_seat.seat_number,
                    seat_zone=phys_seat.seat_zone,
                    seat_type=phys_seat.seat_type,
                    price=st_seat.price,
                    status=effective_status,
                    version=st_seat.version,
                )
            )

        return ShowtimeSeatMapDTO(
            showtime_id=st.id,
            auditorium_name=aud.name,
            total_rows=aud.total_rows,
            total_cols=aud.total_cols,
            seats=seat_items,
        )
