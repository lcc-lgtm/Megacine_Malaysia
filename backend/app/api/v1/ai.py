from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_user, require_roles
from app.core.database import get_db
from app.schemas.ai import (
    AIAutofillMovieRequestDTO,
    AIChatRequestDTO,
    AIResponseDTO,
    AISeatPickRequestDTO,
)
from app.schemas.auth import CurrentUserDTO
from app.services.ai_service import SUPPORTED_MODELS, AIService

router = APIRouter(prefix="/ai", tags=["AI Assistant"])
admin_guard = require_roles("PLATFORM_ADMIN", "CINEMA_ADMIN")


@router.get("/models")
async def list_ai_models() -> dict:
    return {"models": list(SUPPORTED_MODELS)}


@router.post("/chat", response_model=AIResponseDTO)
async def ai_chat(
    payload: AIChatRequestDTO,
    x_google_access_token: str | None = Header(default=None),
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AIResponseDTO:
    return await AIService(db, google_oauth_token=x_google_access_token).chat_concierge(
        current_user.id, payload.prompt, payload.location, model=payload.model
    )


@router.post("/seat-pick", response_model=AIResponseDTO)
async def ai_seat_pick(
    payload: AISeatPickRequestDTO,
    x_google_access_token: str | None = Header(default=None),
    _: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AIResponseDTO:
    return await AIService(db, google_oauth_token=x_google_access_token).pick_best_seats(
        payload.showtime_id, payload.party_size, payload.preference, model=payload.model
    )


@router.post("/admin/autofill-movie", response_model=AIResponseDTO)
async def ai_admin_autofill(
    payload: AIAutofillMovieRequestDTO,
    x_google_access_token: str | None = Header(default=None),
    _: CurrentUserDTO = Depends(admin_guard),
    db: AsyncSession = Depends(get_db),
) -> AIResponseDTO:
    return await AIService(db, google_oauth_token=x_google_access_token).autofill_movie(
        payload.title, payload.notes, model=payload.model
    )
