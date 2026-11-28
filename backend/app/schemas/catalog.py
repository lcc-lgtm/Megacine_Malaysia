import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


# ---------- Movies ----------
class MovieCreateDTO(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    synopsis: str | None = None
    duration_minutes: int = Field(..., gt=0, le=600)
    rating: str | None = Field(default=None, max_length=15)
    language: str = Field(default="English", max_length=50)
    poster_url: str | None = Field(default=None, max_length=500)
    genre: str | None = Field(default=None, max_length=50)
    trailer_url: str | None = Field(default=None, max_length=500)
    selection_week: str | None = Field(default=None, max_length=20)
    release_date: date | None = None
    status: Literal["COMING_SOON", "NOW_SHOWING", "ARCHIVED"] = "COMING_SOON"


class MovieUpdateDTO(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    synopsis: str | None = None
    duration_minutes: int | None = Field(default=None, gt=0, le=600)
    rating: str | None = Field(default=None, max_length=15)
    language: str | None = Field(default=None, max_length=50)
    poster_url: str | None = Field(default=None, max_length=500)
    genre: str | None = Field(default=None, max_length=50)
    trailer_url: str | None = Field(default=None, max_length=500)
    selection_week: str | None = Field(default=None, max_length=20)
    release_date: date | None = None
    status: Literal["COMING_SOON", "NOW_SHOWING", "ARCHIVED"] | None = None


class MovieDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    synopsis: str | None = None
    duration_minutes: int
    rating: str | None = None
    language: str
    poster_url: str | None = None
    genre: str | None = None
    trailer_url: str | None = None
    selection_week: str | None = None
    release_date: date | None = None
    status: str
    created_at: datetime
    updated_at: datetime


# ---------- Auditoriums & Seats ----------
class AuditoriumCreateDTO(BaseModel):
    name: str = Field(..., min_length=1, max_length=60)
    total_rows: int = Field(..., gt=0, le=50)
    total_cols: int = Field(..., gt=0, le=50)
    vip_rows: list[str] = Field(default_factory=list, description="Row labels marked as VIP, e.g. ['E']")


class AuditoriumDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    cinema_id: uuid.UUID
    name: str
    total_rows: int
    total_cols: int
    seats_created: int = 0


# ---------- Showtimes & Real-Time Seat Map ----------
class ShowtimeCreateDTO(BaseModel):
    movie_id: uuid.UUID
    auditorium_id: uuid.UUID
    start_time: datetime
    end_time: datetime | None = Field(
        default=None,
        description="Optional; defaults to start_time + movie.duration_minutes + 15m buffer",
    )
    base_price: Decimal = Field(..., ge=0)
    vip_surcharge: Decimal = Field(default=Decimal("5.00"), ge=0)


class ShowtimeUpdateDTO(BaseModel):
    start_time: datetime | None = None
    end_time: datetime | None = None
    base_price: Decimal | None = Field(default=None, ge=0)
    status: Literal["SCHEDULED", "COMPLETED"] | None = None


class ShowtimeDTO(BaseModel):
    id: uuid.UUID
    movie_id: uuid.UUID
    movie_title: str
    cinema_id: uuid.UUID
    cinema_name: str
    auditorium_id: uuid.UUID
    auditorium_name: str
    start_time: datetime
    end_time: datetime
    base_price: Decimal
    status: str


class ShowtimeSeatItemDTO(BaseModel):
    showtime_seat_id: uuid.UUID
    seat_id: uuid.UUID
    row_label: str
    seat_number: int
    seat_zone: str
    seat_type: str
    price: Decimal
    status: str  # Projected real-time status (expired HELD -> AVAILABLE)
    version: int


class ShowtimeSeatMapDTO(BaseModel):
    showtime_id: uuid.UUID
    auditorium_name: str
    total_rows: int
    total_cols: int
    seats: list[ShowtimeSeatItemDTO]


class ShowtimeCancelResponseDTO(BaseModel):
    showtime_id: uuid.UUID
    status: str
    refunded_orders_count: int


# ---------- Admin Order View ----------
class AdminOrderSummaryDTO(BaseModel):
    id: uuid.UUID
    order_no: str
    user_id: uuid.UUID
    showtime_id: uuid.UUID
    cinema_id: uuid.UUID
    status: str
    total_amount: Decimal
    hold_expires_at: datetime
    created_at: datetime


# ---------- Bookmarks & Recommendations ----------
class BookmarkToggleResponseDTO(BaseModel):
    movie_id: uuid.UUID
    bookmarked: bool


class RecommendedMoviesResponseDTO(BaseModel):
    preferred_genres: list[str]
    bookmarked_movie_ids: list[uuid.UUID]
    movies: list[MovieDTO]
