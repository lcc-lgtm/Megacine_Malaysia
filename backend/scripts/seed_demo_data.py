import asyncio
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.entities import Auditorium, Cinema, Movie, Seat, Showtime, ShowtimeSeat


async def seed_demo() -> None:
    async with AsyncSessionLocal() as db:
        existing_cinema = (
            await db.execute(select(Cinema).where(Cinema.name == "Megacine KLCC"))
        ).scalar_one_or_none()
        if existing_cinema:
            print("Demo data already seeded. Skipping.")
            return

        cinema = Cinema(
            name="Megacine KLCC",
            address="Suria KLCC, Kuala Lumpur City Centre",
            city="Kuala Lumpur",
            state="WP Kuala Lumpur",
        )
        db.add(cinema)
        await db.flush()

        auditorium = Auditorium(
            cinema_id=cinema.id,
            name="Hall 1",
            total_rows=5,
            total_cols=8,
        )
        db.add(auditorium)
        await db.flush()

        seats: list[Seat] = []
        for row_idx, row_label in enumerate(["A", "B", "C", "D", "E"]):
            zone = "VIP" if row_label == "E" else "STANDARD"
            for col in range(1, 9):
                seats.append(
                    Seat(
                        auditorium_id=auditorium.id,
                        row_label=row_label,
                        seat_number=col,
                        seat_zone=zone,
                        seat_type="STANDARD",
                    )
                )
        db.add_all(seats)
        await db.flush()

        m1 = Movie(
            title="Dune: Messiah",
            synopsis="Paul Atreides faces the consequences of his rise to imperial power.",
            duration_minutes=155,
            rating="P12",
            language="English",
            release_date=date.today(),
            status="NOW_SHOWING",
        )
        m2 = Movie(
            title="Sheriff: Narko Integriti",
            synopsis="Malaysian action thriller following an integrity unit officer.",
            duration_minutes=132,
            rating="16",
            language="Bahasa Melayu",
            release_date=date.today(),
            status="NOW_SHOWING",
        )
        db.add_all([m1, m2])
        await db.flush()

        start_utc = datetime.now(timezone.utc) + timedelta(days=1)
        showtime = Showtime(
            movie_id=m1.id,
            auditorium_id=auditorium.id,
            start_time=start_utc,
            end_time=start_utc + timedelta(minutes=m1.duration_minutes + 15),
            base_price=Decimal("20.00"),
            status="SCHEDULED",
        )
        db.add(showtime)
        await db.flush()

        st_seats = [
            ShowtimeSeat(
                showtime_id=showtime.id,
                seat_id=s.id,
                price=Decimal("25.00") if s.seat_zone == "VIP" else Decimal("20.00"),
                status="AVAILABLE",
            )
            for s in seats
        ]
        db.add_all(st_seats)
        await db.commit()
        print(f"Seeded demo data! cinema_id={cinema.id}, showtime_id={showtime.id}")


if __name__ == "__main__":
    asyncio.run(seed_demo())
