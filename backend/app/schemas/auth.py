import uuid
from pydantic import BaseModel, Field


class RoleAssignmentDTO(BaseModel):
    code: str
    cinema_id: uuid.UUID | None = None


class CurrentUserDTO(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str | None = None
    is_active: bool
    roles: list[RoleAssignmentDTO]


class UserProfileUpdateDTO(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=120)
