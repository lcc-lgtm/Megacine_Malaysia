import uuid
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


# ==============================================================================
# 1.1 Identity & Multi-Cinema RBAC Domain
# ==============================================================================
class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    full_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Role(Base):
    __tablename__ = "roles"
    __table_args__ = (
        CheckConstraint("code IN ('CUSTOMER','CINEMA_ADMIN','PLATFORM_ADMIN')", name="ck_roles_code"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class UserRole(Base):
    __tablename__ = "user_roles"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "role_id",
            "cinema_id",
            name="uq_user_roles_scope",
            postgresql_nulls_not_distinct=True,
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("roles.id", ondelete="RESTRICT"), nullable=False)
    cinema_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("cinemas.id", ondelete="CASCADE"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


# ==============================================================================
# 1.2 Movie, Cinema & Showtime Domain
# ==============================================================================
class Movie(Base):
    __tablename__ = "movies"
    __table_args__ = (
        CheckConstraint("duration_minutes > 0 AND duration_minutes <= 600", name="ck_movies_duration"),
        CheckConstraint("status IN ('COMING_SOON','NOW_SHOWING','ARCHIVED')", name="ck_movies_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    synopsis: Mapped[str | None] = mapped_column(Text, nullable=True)
    duration_minutes: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    rating: Mapped[str | None] = mapped_column(String(15), nullable=True)
    language: Mapped[str] = mapped_column(String(50), nullable=False, server_default=text("'English'"))
    poster_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    genre: Mapped[str | None] = mapped_column(String(50), nullable=True)
    trailer_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    selection_week: Mapped[str | None] = mapped_column(String(20), nullable=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'COMING_SOON'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Cinema(Base):
    __tablename__ = "cinemas"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    address: Mapped[str] = mapped_column(String(300), nullable=False)
    city: Mapped[str] = mapped_column(String(80), nullable=False)
    state: Mapped[str] = mapped_column(String(80), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Auditorium(Base):
    __tablename__ = "auditoriums"
    __table_args__ = (
        CheckConstraint("total_rows > 0 AND total_rows <= 50", name="ck_auditoriums_rows"),
        CheckConstraint("total_cols > 0 AND total_cols <= 50", name="ck_auditoriums_cols"),
        UniqueConstraint("cinema_id", "name", name="uq_auditoriums_cinema_name"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    cinema_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cinemas.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    total_rows: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    total_cols: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Seat(Base):
    __tablename__ = "seats"
    __table_args__ = (
        CheckConstraint("seat_number > 0", name="ck_seats_number"),
        CheckConstraint("seat_zone IN ('STANDARD','VIP')", name="ck_seats_zone"),
        CheckConstraint("seat_type IN ('STANDARD','TWIN','WHEELCHAIR')", name="ck_seats_type"),
        UniqueConstraint("auditorium_id", "row_label", "seat_number", name="uq_seats_auditorium_pos"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    auditorium_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("auditoriums.id", ondelete="CASCADE"), nullable=False)
    row_label: Mapped[str] = mapped_column(String(5), nullable=False)
    seat_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    seat_zone: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'STANDARD'"))
    seat_type: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'STANDARD'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class Showtime(Base):
    __tablename__ = "showtimes"
    __table_args__ = (
        CheckConstraint("end_time > start_time", name="ck_showtimes_time_range"),
        CheckConstraint("base_price >= 0", name="ck_showtimes_base_price"),
        CheckConstraint("status IN ('SCHEDULED','CANCELLED','COMPLETED')", name="ck_showtimes_status"),
        Index("idx_showtimes_auditorium_time", "auditorium_id", "start_time", "end_time"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    movie_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("movies.id", ondelete="RESTRICT"), nullable=False)
    auditorium_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("auditoriums.id", ondelete="RESTRICT"), nullable=False)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    base_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'SCHEDULED'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class ShowtimeSeat(Base):
    __tablename__ = "showtime_seats"
    __table_args__ = (
        CheckConstraint("price >= 0", name="ck_showtime_seats_price"),
        CheckConstraint("status IN ('AVAILABLE','HELD','SOLD','BLOCKED')", name="ck_showtime_seats_status"),
        CheckConstraint("version >= 1", name="ck_showtime_seats_version"),
        UniqueConstraint("showtime_id", "seat_id", name="uq_showtime_seats_pair"),
        Index(
            "idx_showtime_seats_hold_expiry",
            "status",
            "hold_expires_at",
            postgresql_where=text("status = 'HELD'"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    showtime_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("showtimes.id", ondelete="CASCADE"), nullable=False)
    seat_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("seats.id", ondelete="RESTRICT"), nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'AVAILABLE'"))
    held_by_order_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("orders.id", ondelete="SET NULL", use_alter=True, name="fk_showtime_seats_held_by_order_id"),
        nullable=True,
    )
    hold_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("1"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


# ==============================================================================
# 1.3 Order, E-Ticket, Payment & Refund Domain
# ==============================================================================
class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint(
            "status IN ('PENDING_PAYMENT','CONFIRMED','USED','CANCELLED','EXPIRED','REFUND_PENDING','PARTIALLY_REFUNDED','REFUNDED')",
            name="ck_orders_status",
        ),
        CheckConstraint("subtotal_amount >= 0", name="ck_orders_subtotal"),
        CheckConstraint("discount_amount >= 0", name="ck_orders_discount"),
        CheckConstraint("total_amount >= 0", name="ck_orders_total"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    order_no: Mapped[str] = mapped_column(String(32), nullable=False, unique=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    showtime_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("showtimes.id", ondelete="RESTRICT"), nullable=False)
    status: Mapped[str] = mapped_column(String(25), nullable=False, server_default=text("'PENDING_PAYMENT'"))
    subtotal_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, server_default=text("0.00"))
    total_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    hold_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        CheckConstraint("unit_price >= 0", name="ck_order_items_unit_price"),
        UniqueConstraint("order_id", "showtime_seat_id", name="uq_order_items_seat"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    showtime_seat_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("showtime_seats.id", ondelete="RESTRICT"), nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class Ticket(Base):
    __tablename__ = "tickets"
    __table_args__ = (
        CheckConstraint("status IN ('VALID','USED','CANCELLED','REFUNDED')", name="ck_tickets_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    order_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("order_items.id", ondelete="CASCADE"), nullable=False, unique=True)
    ticket_code: Mapped[str] = mapped_column(String(40), nullable=False, unique=True)
    qr_payload: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'VALID'"))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Payment(Base):
    __tablename__ = "payments"
    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_payments_amount"),
        CheckConstraint("status IN ('PENDING','SUCCEEDED','FAILED','UNKNOWN')", name="ck_payments_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="RESTRICT"), nullable=False)
    provider: Mapped[str] = mapped_column(String(30), nullable=False, server_default=text("'MOCK_PAY'"))
    provider_tx_id: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'PENDING'"))
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Refund(Base):
    __tablename__ = "refunds"
    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_refunds_amount"),
        CheckConstraint("status IN ('PENDING','SUCCEEDED','FAILED')", name="ck_refunds_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="RESTRICT"), nullable=False)
    payment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("payments.id", ondelete="RESTRICT"), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'PENDING'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


# ==============================================================================
# 1.4 System Governance Domain
# ==============================================================================
class AuditLog(Base):
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("idx_audit_logs_entity", "entity_type", "entity_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action: Mapped[str] = mapped_column(String(60), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(40), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    metadata_json: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class UserBookmark(Base):
    __tablename__ = "user_bookmarks"
    __table_args__ = (
        UniqueConstraint("user_id", "movie_id", name="uq_user_bookmarks_pair"),
        Index("idx_user_bookmarks_user", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    movie_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("movies.id", ondelete="CASCADE"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
