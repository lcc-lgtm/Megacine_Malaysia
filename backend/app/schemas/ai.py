import uuid
from typing import Any, Literal
from pydantic import BaseModel, Field

AllowedModel = Literal["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-4-hydrogen"]


class AIChatRequestDTO(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=1000)
    location: str | None = Field(default=None, max_length=100)
    model: AllowedModel | None = None


class AISeatPickRequestDTO(BaseModel):
    showtime_id: uuid.UUID
    party_size: int = Field(default=2, ge=1, le=6)
    preference: str = Field(default="center back seats with best view", max_length=300)
    model: AllowedModel | None = None


class AIAutofillMovieRequestDTO(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    notes: str = Field(default="", max_length=300)
    model: AllowedModel | None = None


class AIResponseDTO(BaseModel):
    reply: str
    config: dict[str, Any] = Field(default_factory=dict)
    model_used: str
