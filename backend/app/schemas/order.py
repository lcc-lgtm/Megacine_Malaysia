import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, Field


class OrderCreateDTO(BaseModel):
    showtime_id: uuid.UUID
    showtime_seat_ids: list[uuid.UUID] = Field(..., min_length=1, max_length=6)


class OrderItemDTO(BaseModel):
    id: uuid.UUID
    showtime_seat_id: uuid.UUID
    row_label: str
    seat_number: int
    seat_zone: str
    unit_price: Decimal


class TicketDTO(BaseModel):
    id: uuid.UUID
    ticket_code: str
    qr_payload: str
    status: str
    issued_at: datetime
    used_at: datetime | None = None


class OrderDTO(BaseModel):
    id: uuid.UUID
    order_no: str
    user_id: uuid.UUID
    showtime_id: uuid.UUID
    status: str
    subtotal_amount: Decimal
    discount_amount: Decimal
    total_amount: Decimal
    hold_expires_at: datetime
    created_at: datetime
    items: list[OrderItemDTO] = Field(default_factory=list)
    tickets: list[TicketDTO] = Field(default_factory=list)


class PaymentRequestDTO(BaseModel):
    scenario: Literal["SUCCEEDED", "FAILED", "TIMEOUT"] = "SUCCEEDED"


class PaymentResultDTO(BaseModel):
    payment_id: uuid.UUID
    provider: str
    provider_tx_id: str
    payment_status: str
    order_id: uuid.UUID
    order_status: str
    amount: Decimal
    message: str
    tickets: list[TicketDTO] = Field(default_factory=list)


class RefundRequestDTO(BaseModel):
    reason: str | None = Field(default="Customer requested refund", max_length=255)


class RefundResponseDTO(BaseModel):
    refund_id: uuid.UUID
    order_id: uuid.UUID
    order_status: str
    refund_status: str
    amount: Decimal
    reason: str | None = None
