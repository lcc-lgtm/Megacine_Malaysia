from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.entities import User
from app.schemas.auth import CurrentUserDTO, UserProfileUpdateDTO

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/me", response_model=CurrentUserDTO)
async def get_me(current_user: CurrentUserDTO = Depends(get_current_user)) -> CurrentUserDTO:
    return current_user


@router.patch("/me", response_model=CurrentUserDTO)
async def update_me(
    payload: UserProfileUpdateDTO,
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CurrentUserDTO:
    user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.full_name = payload.full_name.strip()
    await db.commit()
    await db.refresh(user)
    return CurrentUserDTO(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_active=user.is_active,
        roles=current_user.roles,
    )
