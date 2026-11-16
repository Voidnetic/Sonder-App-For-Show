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
    # Who added the newest photo and when ("Ahmed added a memory 10 min ago"). The photo stays hidden.
    last_captured_at: datetime | None = None
    last_captured_by: UserResponse | None = None
    friend_count: int
    # For the person asking:
    # "joined", or "invited" while they haven't accepted yet (see /moments/invitations).
    my_status: str = "joined"
    invited_by: UserResponse | None = None
    # When they first opened it after it unlocked. Unlocked but not opened yet = "Ready to Open" on Home.
    opened_at: datetime | None = None
    is_ready: bool = False
    # How many friends are invited but haven't accepted yet.
    pending_count: int = 0
