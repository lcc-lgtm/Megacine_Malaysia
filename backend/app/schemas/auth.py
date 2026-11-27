# backend/app/schemas/auth.py
import uuid
from pydantic import BaseModel


class RoleAssignmentDTO(BaseModel):
    code: str
    cinema_id: uuid.UUID | None = None


class CurrentUserDTO(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str | None = None
    is_active: bool
    roles: list[RoleAssignmentDTO]
