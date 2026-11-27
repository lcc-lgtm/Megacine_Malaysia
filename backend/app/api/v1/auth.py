# backend/app/api/v1/auth.py
from fastapi import APIRouter, Depends
from app.api.deps import get_current_user
from app.schemas.auth import CurrentUserDTO

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/me", response_model=CurrentUserDTO)
async def get_me(current_user: CurrentUserDTO = Depends(get_current_user)) -> CurrentUserDTO:
    return current_user
