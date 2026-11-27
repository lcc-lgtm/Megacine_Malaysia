import asyncio
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import pytest
pytestmark = pytest.mark.asyncio(loop_scope="session")
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, update
from app.api.deps import get_current_user
from app.core.database import AsyncSessionLocal
from app.main import app
from app.models.entities import (
    AuditLog,
    Auditorium,
    Cinema,
    Movie,
    Order,
    Payment,
    Refund,
    Seat,
    Showtime,
    ShowtimeSeat,
    User,
)
from app.schemas.auth import CurrentUserDTO, RoleAssignmentDTO


@pytest.fixture
async def test_fixture_data():
    """Seed isolated test cinema/movie/showtime/seats/users and clean up afterward."""
    user_a_id = uuid.uuid4()
    user_b_id = uuid.uuid4()
    cinema_id = uuid.uuid4()
    movie_id = uuid.uuid4()

    async with AsyncSessionLocal() as db:
        db.add_all([
            User(id=user_a_id, email=f"test_a_{user_a_id.hex[:6]}@megacine.test", full_name="User A"),
            User(id=user_b_id, email=f"test_b_{user_b_id.hex[:6]}@megacine.test", full_name="User B"),
        ])
        cinema = Cinema(id=cinema_id, name=f"Test Cinema {cinema_id.hex[:6]}", address="KL", city="KL", state="WP")
        db.add(cinema)
        await db.flush()

        aud = Auditorium(cinema_id=cinema.id, name="Test Hall", total_rows=1, total_cols=3)
        db.add(aud)
        await db.flush()

        seats = [Seat(auditorium_id=aud.id, row_label="A", seat_number=i, seat_zone="STANDARD") for i in (1, 2, 3)]
        db.add_all(seats)
        await db.flush()

        movie = Movie(id=movie_id, title="Pytest Movie", duration_minutes=120, release_date=date.today(), status="NOW_SHOWING")
        db.add(movie)
        await db.flush()

        start_utc = datetime.now(timezone.utc) + timedelta(hours=3)
        showtime = Showtime(
            movie_id=movie.id,
            auditorium_id=aud.id,
            start_time=start_utc,
            end_time=start_utc + timedelta(minutes=135),
            base_price=Decimal("20.00"),
            status="SCHEDULED",
        )
        db.add(showtime)
        await db.flush()

        st_seats = [
            ShowtimeSeat(showtime_id=showtime.id, seat_id=s.id, price=Decimal("20.00"), status="AVAILABLE")
            for s in seats
        ]
        db.add_all(st_seats)
        await db.commit()

        data = {
            "user_a": CurrentUserDTO(id=user_a_id, email="a@test", is_active=True, roles=[RoleAssignmentDTO(code="CUSTOMER")]),
            "user_b": CurrentUserDTO(id=user_b_id, email="b@test", is_active=True, roles=[RoleAssignmentDTO(code="CUSTOMER")]),
            "showtime_id": showtime.id,
            "seat_ids": [s.id for s in st_seats],
            "cinema_id": cinema.id,
            "movie_id": movie.id,
        }

    yield data

    # Clean up test records in FK-safe order
    async with AsyncSessionLocal() as db:
        await db.execute(delete(AuditLog).where(AuditLog.actor_user_id.in_([user_a_id, user_b_id])))
        await db.execute(delete(Refund).where(Refund.order_id.in_(
            Order.__table__.select().with_only_columns(Order.id).where(Order.user_id.in_([user_a_id, user_b_id]))
        )))
        await db.execute(delete(Payment).where(Payment.order_id.in_(
            Order.__table__.select().with_only_columns(Order.id).where(Order.user_id.in_([user_a_id, user_b_id]))
        )))
        await db.execute(
            update(ShowtimeSeat)
            .where(ShowtimeSeat.showtime_id == data["showtime_id"])
            .values(held_by_order_id=None)
        )
        await db.execute(delete(Order).where(Order.user_id.in_([user_a_id, user_b_id])))
        await db.execute(delete(Showtime).where(Showtime.id == data["showtime_id"]))
        await db.execute(delete(Movie).where(Movie.id == movie_id))
        await db.execute(delete(Cinema).where(Cinema.id == cinema_id))
        await db.execute(delete(User).where(User.id.in_([user_a_id, user_b_id])))
        await db.commit()
    app.dependency_overrides.clear()


async def test_tc_seat_04_concurrent_anti_overselling(test_fixture_data):
    """TC-SEAT-04: 20 concurrent requests compete for the exact same seat; strictly 1 wins."""
    app.dependency_overrides[get_current_user] = lambda: test_fixture_data["user_a"]
    target_seat = str(test_fixture_data["seat_ids"][0])
    showtime_id = str(test_fixture_data["showtime_id"])

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        async def attempt_book(idx: int):
            return await client.post(
                "/api/v1/orders",
                headers={"Idempotency-Key": f"stress-{uuid.uuid4().hex}-{idx}"},
                json={"showtime_id": showtime_id, "showtime_seat_ids": [target_seat]},
            )

        responses = await asyncio.gather(*(attempt_book(i) for i in range(20)))

    status_codes = [r.status_code for r in responses]
    assert status_codes.count(201) == 1, f"Expected strictly 1 winner, got {status_codes}"
    assert status_codes.count(409) == 19, f"Expected 19 conflicts, got {status_codes}"


async def test_tc_pay_and_refund_full_lifecycle(test_fixture_data):
    """TC-PAY-01..04 & TC-REF-02/04: Idempotency, FAILED/TIMEOUT/SUCCEEDED retry, QR tickets & Refund."""
    app.dependency_overrides[get_current_user] = lambda: test_fixture_data["user_a"]
    seat_id = str(test_fixture_data["seat_ids"][1])
    showtime_id = str(test_fixture_data["showtime_id"])
    ord_key = f"ord-idem-{uuid.uuid4().hex}"

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Create order + idempotency replay
        r1 = await client.post(
            "/api/v1/orders",
            headers={"Idempotency-Key": ord_key},
            json={"showtime_id": showtime_id, "showtime_seat_ids": [seat_id]},
        )
        r2 = await client.post(
            "/api/v1/orders",
            headers={"Idempotency-Key": ord_key},
            json={"showtime_id": showtime_id, "showtime_seat_ids": [seat_id]},
        )
        assert r1.status_code == 201 and r2.status_code == 201
        assert r1.json()["id"] == r2.json()["id"]
        order_id = r1.json()["id"]

        # 2. Payment FAILED (402) & TIMEOUT (504) keep order PENDING_PAYMENT
        p_fail = await client.post(
            f"/api/v1/orders/{order_id}/pay",
            headers={"Idempotency-Key": f"pay-fail-{uuid.uuid4().hex}"},
            json={"scenario": "FAILED"},
        )
        assert p_fail.status_code == 402
        assert p_fail.json()["order_status"] == "PENDING_PAYMENT"

        p_to = await client.post(
            f"/api/v1/orders/{order_id}/pay",
            headers={"Idempotency-Key": f"pay-to-{uuid.uuid4().hex}"},
            json={"scenario": "TIMEOUT"},
        )
        assert p_to.status_code == 504
        assert p_to.json()["payment_status"] == "UNKNOWN"

        # 3. Payment SUCCEEDED + Replay Idempotency
        pay_ok_key = f"pay-ok-{uuid.uuid4().hex}"
        p_ok1 = await client.post(
            f"/api/v1/orders/{order_id}/pay",
            headers={"Idempotency-Key": pay_ok_key},
            json={"scenario": "SUCCEEDED"},
        )
        p_ok2 = await client.post(
            f"/api/v1/orders/{order_id}/pay",
            headers={"Idempotency-Key": pay_ok_key},
            json={"scenario": "SUCCEEDED"},
        )
        assert p_ok1.status_code == 200 and p_ok2.status_code == 200
        assert p_ok1.json()["order_status"] == "CONFIRMED"
        assert len(p_ok1.json()["tickets"]) == 1
        assert p_ok1.json()["tickets"][0]["ticket_code"] == p_ok2.json()["tickets"][0]["ticket_code"]

        # 4. Refund (>= 60 mins before showtime) releases seat back to AVAILABLE
        ref = await client.post(
            f"/api/v1/orders/{order_id}/refund",
            json={"reason": "Plan changed"},
        )
        assert ref.status_code == 200
        assert ref.json()["order_status"] == "REFUNDED"

        seat_map = await client.get(f"/api/v1/showtimes/{showtime_id}/seats")
        target = next(s for s in seat_map.json()["seats"] if s["showtime_seat_id"] == seat_id)
        assert target["status"] == "AVAILABLE"


async def test_tc_seat_03_sql_atomic_lazy_reclamation(test_fixture_data):
    """TC-SEAT-03: User B immediately reclaims an expired HELD seat before UptimeRobot runs."""
    seat_id = test_fixture_data["seat_ids"][2]
    showtime_id = str(test_fixture_data["showtime_id"])

    # User A holds seat
    app.dependency_overrides[get_current_user] = lambda: test_fixture_data["user_a"]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r_a = await client.post(
            "/api/v1/orders",
            headers={"Idempotency-Key": f"lazy-a-{uuid.uuid4().hex}"},
            json={"showtime_id": showtime_id, "showtime_seat_ids": [str(seat_id)]},
        )
        assert r_a.status_code == 201

    # Simulate hold expiration 10 seconds ago
    async with AsyncSessionLocal() as db:
        await db.execute(
            update(ShowtimeSeat)
            .where(ShowtimeSeat.id == seat_id)
            .values(hold_expires_at=datetime.now(timezone.utc) - timedelta(seconds=10))
        )
        await db.commit()

    # User B immediately reclaims the seat
    app.dependency_overrides[get_current_user] = lambda: test_fixture_data["user_b"]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r_b = await client.post(
            "/api/v1/orders",
            headers={"Idempotency-Key": f"lazy-b-{uuid.uuid4().hex}"},
            json={"showtime_id": showtime_id, "showtime_seat_ids": [str(seat_id)]},
        )
        assert r_b.status_code == 201

