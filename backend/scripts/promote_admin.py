import asyncio
import sys
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from app.core.database import AsyncSessionLocal
from app.models.entities import Role, User, UserRole


async def promote(email: str) -> None:
    async with AsyncSessionLocal() as db:
        user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
        if not user:
            print(f"User '{email}' not found in public.users. Log in once via Admin Web or /api/v1/auth/me first.")
            return
        role = (await db.execute(select(Role).where(Role.code == "PLATFORM_ADMIN"))).scalar_one_or_none()
        if not role:
            print("PLATFORM_ADMIN role missing. Run `python -m scripts.seed_roles` first.")
            return
        stmt = (
            insert(UserRole)
            .values(user_id=user.id, role_id=role.id, cinema_id=None)
            .on_conflict_do_nothing(constraint="uq_user_roles_scope")
        )
        await db.execute(stmt)
        await db.commit()
        print(f"Promoted '{email}' to PLATFORM_ADMIN successfully!")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python -m scripts.promote_admin <user_email>")
        sys.exit(1)
    asyncio.run(promote(sys.argv[1]))
