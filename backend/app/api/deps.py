# backend/app/api/deps.py
from collections.abc import Callable
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.security import verify_supabase_jwt
from app.schemas.auth import CurrentUserDTO
from app.services.auth_service import AuthService

bearer_scheme = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> CurrentUserDTO:
    payload = verify_supabase_jwt(credentials.credentials)
    service = AuthService(db)
    return await service.sync_and_get_user(payload)


def require_roles(*allowed_roles: str) -> Callable:
    async def _guard(current_user: CurrentUserDTO = Depends(get_current_user)) -> CurrentUserDTO:
        user_role_codes = {r.code for r in current_user.roles}
        if not user_role_codes.intersection(allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient role permissions",
            )
        return current_user

    return _guard
