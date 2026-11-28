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
    has_custom_hash: bool = False
    roles: list[RoleAssignmentDTO]


class UserProfileUpdateDTO(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    raw_password: str | None = Field(default=None, min_length=8, max_length=12)


class CustomHashVerifyDTO(BaseModel):
    raw_password: str = Field(..., min_length=8, max_length=12)
