import asyncio
from sqlalchemy.dialects.postgresql import insert
from app.core.database import AsyncSessionLocal
from app.models.entities import Role

DEFAULT_ROLES = [
    {"code": "CUSTOMER", "name": "Customer"},
    {"code": "CINEMA_ADMIN", "name": "Cinema Administrator"},
    {"code": "PLATFORM_ADMIN", "name": "Platform Administrator"},
]


async def seed() -> None:
    async with AsyncSessionLocal() as session:
        stmt = insert(Role).values(DEFAULT_ROLES).on_conflict_do_nothing(index_elements=["code"])
        await session.execute(stmt)
        await session.commit()
    print("Seeded default roles successfully.")


if __name__ == "__main__":
    asyncio.run(seed())
