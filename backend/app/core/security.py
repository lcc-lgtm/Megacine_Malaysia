import secrets
from functools import lru_cache
from typing import Any
import jwt
from jwt import PyJWKClient, PyJWTError
from fastapi import HTTPException, status
from app.core.config import get_settings


@lru_cache
def _get_jwk_client() -> PyJWKClient:
    settings = get_settings()
    # Cache Supabase ES256 public keys in memory for 1 hour
    return PyJWKClient(settings.SUPABASE_JWKS_URL, cache_keys=True, lifespan=3600)


def verify_supabase_jwt(token: str) -> dict[str, Any]:
    try:
        jwk_client = _get_jwk_client()
        signing_key = jwk_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            audience="authenticated",
            options={"require": ["exp", "sub"]},
        )
        return payload
    except PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


def verify_cron_token(provided_token: str) -> None:
    settings = get_settings()
    if not provided_token or not secrets.compare_digest(provided_token, settings.CRON_SECRET):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid cron token",
        )
