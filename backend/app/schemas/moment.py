import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.user import UserResponse


class CreateMomentRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120, examples=["Birthday Night"])
    participant_ids: list[uuid.UUID] = Field(
        default_factory=list, description="Friends invited to this moment (the creator is added automatically)"
    )
    unlock_at: datetime = Field(description="When the moment unlocks for everyone")
    accent_color: str | None = Field(default=None, pattern=r"^#([0-9A-Fa-f]{6})$")


class AddParticipantRequest(BaseModel):
    user_id: uuid.UUID


class MomentResponse(BaseModel):
    id: uuid.UUID
    title: str
    creator: UserResponse
    participants: list[UserResponse]
    accent_color: str
    unlock_at: datetime
    revealed_at: datetime | None
    is_locked: bool
    memory_count: int
    friend_count: int
