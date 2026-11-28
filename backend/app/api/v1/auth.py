from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_user
from app.core.custom_hash import encode_custom_hash, verify_custom_hash
from app.core.database import get_db
from app.models.entities import User
from app.schemas.auth import CurrentUserDTO, CustomHashVerifyDTO, UserProfileUpdateDTO

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/me", response_model=CurrentUserDTO)
async def get_me(
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CurrentUserDTO:
    user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one_or_none()
    return CurrentUserDTO(
        id=current_user.id,
        email=current_user.email,
        full_name=user.full_name if user else current_user.full_name,
        is_active=current_user.is_active,
        has_custom_hash=bool(user and user.custom_password_hash),
        roles=current_user.roles,
    )


@router.patch("/me", response_model=CurrentUserDTO)
async def update_me(
    payload: UserProfileUpdateDTO,
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CurrentUserDTO:
    user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()

    if payload.raw_password is not None:
        try:
            user.custom_password_hash = encode_custom_hash(payload.raw_password)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc

    await db.commit()
    await db.refresh(user)
    return CurrentUserDTO(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_active=user.is_active,
        has_custom_hash=bool(user.custom_password_hash),
        roles=current_user.roles,
    )


@router.post("/verify-custom-hash")
async def verify_my_custom_hash(
    payload: CustomHashVerifyDTO,
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one_or_none()
    if not user or not user.custom_password_hash:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Custom password hash not set")
    matched = verify_custom_hash(payload.raw_password, user.custom_password_hash)
    return {"matched": matched, "stored_hash_length": len(user.custom_password_hash)}
