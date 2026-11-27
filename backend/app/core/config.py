from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


def _to_asyncpg_url(url: str) -> str:
    if url.startswith("postgresql+asyncpg://"):
        return url
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+asyncpg://", 1)
    return url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_ENV: str = "development"
    DATABASE_URL: str
    DIRECT_DATABASE_URL: str
    SUPABASE_URL: str
    SUPABASE_JWKS_URL: str

    SEAT_HOLD_SECONDS: int = 300
    REFUND_CUTOFF_MINUTES: int = 60
    MAX_SEATS_PER_ORDER: int = 6
    CRON_SECRET: str
    CORS_ORIGINS: str = "http://localhost:5500"

    @property
    def async_database_url(self) -> str:
        return _to_asyncpg_url(self.DATABASE_URL)

    @property
    def async_direct_database_url(self) -> str:
        return _to_asyncpg_url(self.DIRECT_DATABASE_URL)

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
