# backend/app/schemas/ops.py
from datetime import datetime
from pydantic import BaseModel


class HealthResponseDTO(BaseModel):
    status: str
    environment: str
    timestamp: datetime


class CleanupHoldsResponseDTO(BaseModel):
    status: str
    expired_orders_count: int
    released_seats_count: int
    executed_at: datetime
