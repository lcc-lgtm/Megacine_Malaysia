# backend/app/api/internal/ops.py
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import verify_cron_token
from app.schemas.ops import CleanupHoldsResponseDTO, HealthResponseDTO
from app.services.ops_service import OpsService

router = APIRouter(tags=["Operations"])


@router.get("/health", response_model=HealthResponseDTO)
async def health_check() -> HealthResponseDTO:
    settings = get_settings()
    return HealthResponseDTO(
        status="ok",
        environment=settings.APP_ENV,
        timestamp=datetime.now(timezone.utc),
    )


@router.get("/internal/jobs/cleanup-holds", response_model=CleanupHoldsResponseDTO)
async def cleanup_expired_holds(
    token: str = Query(..., description="Shared CRON_SECRET token"),
    db: AsyncSession = Depends(get_db),
) -> CleanupHoldsResponseDTO:
    verify_cron_token(token)
    service = OpsService(db)
    return await service.run_hold_cleanup()
