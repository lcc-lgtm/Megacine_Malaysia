import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import get_settings
from app.core.database import Base
from app.models import entities  # noqa: F401 - load all 15 table definitions


async def init_db() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.async_direct_database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    print("Created all 15 Phase 1 tables in Supabase successfully.")


if __name__ == "__main__":
    asyncio.run(init_db())
