import uuid
from pydantic import BaseModel, ConfigDict


class AuditoriumBriefDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    total_rows: int
    total_cols: int


class CinemaWithAuditoriumsDTO(BaseModel):
    id: uuid.UUID
    name: str
    address: str
    city: str
    state: str
    auditoriums: list[AuditoriumBriefDTO]
