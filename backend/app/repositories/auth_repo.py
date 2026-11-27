# backend/app/repositories/auth_repo.py
import uuid
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Role, User, UserRole


class AuthRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def upsert_user(self, user_id: uuid.UUID, email: str, full_name: str | None) -> User:
        stmt = (
            insert(User)
            .values(id=user_id, email=email, full_name=full_name)
            .on_conflict_do_update(
                index_elements=["id"],
                set_={"email": email},
            )
            .returning(User)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one()

    async def ensure_default_customer_role(self, user_id: uuid.UUID) -> None:
        role_stmt = select(Role.id).where(Role.code == "CUSTOMER")
        customer_role_id = (await self.db.execute(role_stmt)).scalar_one_or_none()
        if customer_role_id is None:
            return
        assign_stmt = (
            insert(UserRole)
            .values(user_id=user_id, role_id=customer_role_id, cinema_id=None)
            .on_conflict_do_nothing(constraint="uq_user_roles_scope")
        )
        await self.db.execute(assign_stmt)

    async def get_user_roles(self, user_id: uuid.UUID) -> list[tuple[str, uuid.UUID | None]]:
        stmt = (
            select(Role.code, UserRole.cinema_id)
            .join(Role, Role.id == UserRole.role_id)
            .where(UserRole.user_id == user_id)
        )
        rows = (await self.db.execute(stmt)).all()
        return [(row[0], row[1]) for row in rows]
