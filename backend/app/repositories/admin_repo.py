import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import (
    AuditLog,
    Auditorium,
    Cinema,
    Movie,
    Order,
    Seat,
    Showtime,
    ShowtimeSeat,
    Ticket,
)


class AdminRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ---------- Movies ----------
    async def create_movie(self, movie: Movie) -> Movie:
        self.db.add(movie)
        await self.db.flush()
        await self.db.refresh(movie)
        return movie

    async def get_movie(self, movie_id: uuid.UUID) -> Movie | None:
        return (await self.db.execute(select(Movie).where(Movie.id == movie_id))).scalar_one_or_none()

    # ---------- Cinemas & Auditoriums ----------
    async def get_cinema(self, cinema_id: uuid.UUID) -> Cinema | None:
        return (await self.db.execute(select(Cinema).where(Cinema.id == cinema_id))).scalar_one_or_none()

    async def get_auditorium_by_name(self, cinema_id: uuid.UUID, name: str) -> Auditorium | None:
        stmt = select(Auditorium).where(Auditorium.cinema_id == cinema_id, Auditorium.name == name)
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def get_auditorium(self, auditorium_id: uuid.UUID) -> Auditorium | None:
        return (await self.db.execute(select(Auditorium).where(Auditorium.id == auditorium_id))).scalar_one_or_none()

    async def create_auditorium_with_seats(self, auditorium: Auditorium, seats: list[Seat]) -> Auditorium:
        self.db.add(auditorium)
        await self.db.flush()
        for s in seats:
            s.auditorium_id = auditorium.id
        self.db.add_all(seats)
        await self.db.flush()
        await self.db.refresh(auditorium)
        return auditorium

    async def get_seats_by_auditorium(self, auditorium_id: uuid.UUID) -> list[Seat]:
        stmt = select(Seat).where(Seat.auditorium_id == auditorium_id)
        return list((await self.db.execute(stmt)).scalars().all())

    # ---------- Showtimes ----------
    async def has_overlapping_showtime(
        self,
        auditorium_id: uuid.UUID,
        start_time: datetime,
        end_time: datetime,
        exclude_showtime_id: uuid.UUID | None = None,
    ) -> bool:
        stmt = select(func.count(Showtime.id)).where(
            Showtime.auditorium_id == auditorium_id,
            Showtime.status == "SCHEDULED",
            Showtime.start_time < end_time,
            Showtime.end_time > start_time,
        )
        if exclude_showtime_id:
            stmt = stmt.where(Showtime.id != exclude_showtime_id)
        count = (await self.db.execute(stmt)).scalar_one()
        return count > 0

    async def create_showtime_with_seats(
        self,
        showtime: Showtime,
        seats: list[Seat],
        vip_surcharge: Decimal,
    ) -> Showtime:
        self.db.add(showtime)
        await self.db.flush()
        st_seats = [
            ShowtimeSeat(
                showtime_id=showtime.id,
                seat_id=seat.id,
                price=showtime.base_price + (vip_surcharge if seat.seat_zone == "VIP" else Decimal("0.00")),
                status="AVAILABLE",
            )
            for seat in seats
        ]
        self.db.add_all(st_seats)
        await self.db.flush()
        await self.db.refresh(showtime)
        return showtime

    async def get_showtime_full(self, showtime_id: uuid.UUID) -> tuple[Showtime, Movie, Auditorium, Cinema] | None:
        stmt = (
            select(Showtime, Movie, Auditorium, Cinema)
            .join(Movie, Movie.id == Showtime.movie_id)
            .join(Auditorium, Auditorium.id == Showtime.auditorium_id)
            .join(Cinema, Cinema.id == Auditorium.cinema_id)
            .where(Showtime.id == showtime_id)
        )
        row = (await self.db.execute(stmt)).first()
        return (row[0], row[1], row[2], row[3]) if row else None

    async def count_confirmed_orders(self, showtime_id: uuid.UUID) -> int:
        stmt = select(func.count(Order.id)).where(
            Order.showtime_id == showtime_id,
            Order.status.in_(["CONFIRMED", "USED"]),
        )
        return (await self.db.execute(stmt)).scalar_one()

    async def cancel_showtime_cascade(self, showtime: Showtime, now_utc: datetime) -> int:
        showtime.status = "CANCELLED"
        showtime.updated_at = now_utc

        # Mark CONFIRMED orders as REFUNDED; PENDING_PAYMENT orders as CANCELLED
        confirmed_ids_stmt = select(Order.id).where(
            Order.showtime_id == showtime.id,
            Order.status == "CONFIRMED",
        )
        confirmed_order_ids = list((await self.db.execute(confirmed_ids_stmt)).scalars().all())

        if confirmed_order_ids:
            await self.db.execute(
                update(Order)
                .where(Order.id.in_(confirmed_order_ids))
                .values(status="REFUNDED", updated_at=now_utc)
            )
            await self.db.execute(
                update(Ticket)
                .where(Ticket.order_id.in_(confirmed_order_ids))
                .values(status="REFUNDED")
            )

        await self.db.execute(
            update(Order)
            .where(Order.showtime_id == showtime.id, Order.status == "PENDING_PAYMENT")
            .values(status="CANCELLED", updated_at=now_utc)
        )

        # Release all non-blocked seats
        await self.db.execute(
            update(ShowtimeSeat)
            .where(ShowtimeSeat.showtime_id == showtime.id, ShowtimeSeat.status != "BLOCKED")
            .values(
                status="AVAILABLE",
                held_by_order_id=None,
                hold_expires_at=None,
                version=ShowtimeSeat.version + 1,
                updated_at=now_utc,
            )
        )
        return len(confirmed_order_ids)

    # ---------- Orders & Audit Logs ----------
    async def list_orders_by_cinemas(
        self,
        cinema_ids: list[uuid.UUID] | None,
        status_filter: str | None = None,
    ) -> list[tuple[Order, uuid.UUID]]:
        stmt = (
            select(Order, Auditorium.cinema_id)
            .join(Showtime, Showtime.id == Order.showtime_id)
            .join(Auditorium, Auditorium.id == Showtime.auditorium_id)
            .order_by(Order.created_at.desc())
        )
        if cinema_ids is not None:
            stmt = stmt.where(Auditorium.cinema_id.in_(cinema_ids))
        if status_filter:
            stmt = stmt.where(Order.status == status_filter)
        return [(row[0], row[1]) for row in (await self.db.execute(stmt)).all()]

    async def write_audit_log(
        self,
        actor_user_id: uuid.UUID | None,
        action: str,
        entity_type: str,
        entity_id: uuid.UUID,
        metadata_json: dict,
    ) -> None:
        self.db.add(
            AuditLog(
                actor_user_id=actor_user_id,
                action=action,
                entity_type=entity_type,
                entity_id=entity_id,
                metadata_json=metadata_json,
            )
        )
