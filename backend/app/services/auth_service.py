# backend/app/services/auth_service.py
import uuid
from typing import Any
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.auth_repo import AuthRepository
from app.schemas.auth import CurrentUserDTO, RoleAssignmentDTO


class AuthService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = AuthRepository(db)

    async def sync_and_get_user(self, jwt_payload: dict[str, Any]) -> CurrentUserDTO:
        user_id = uuid.UUID(jwt_payload["sub"])
        email = jwt_payload.get("email") or f"{user_id}@placeholder.local"
        user_meta = jwt_payload.get("user_metadata") or {}
        full_name = user_meta.get("full_name") or user_meta.get("name")

        user = await self.repo.upsert_user(user_id=user_id, email=email, full_name=full_name)
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is inactive")

        await self.repo.ensure_default_customer_role(user_id=user_id)
        roles_raw = await self.repo.get_user_roles(user_id=user_id)
        await self.db.commit()

        return CurrentUserDTO(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            is_active=user.is_active,
            roles=[RoleAssignmentDTO(code=code, cinema_id=cid) for code, cid in roles_raw],
        )
