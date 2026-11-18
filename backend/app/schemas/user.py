import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    email: EmailStr
    avatar_color: str
    username: str | None = None


class UserProfileResponse(UserResponse):
    memory_count: int
    active_moment_count: int
    friend_count: int
    email_verified: bool = False
    google_linked: bool = False
    has_password: bool = True
    is_admin: bool = False
    verification_required: bool = False
    # A new email address waiting for the code sent to it.
    pending_email: str | None = None


class UpdateUserRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    username: str | None = Field(default=None, min_length=1, max_length=40)
    avatar_color: str | None = Field(default=None, pattern=r"^#([0-9A-Fa-f]{6})$")


Relationship = Literal["none", "friend", "outgoing", "incoming"]


class UserSearchResult(UserResponse):
    # Lets the Add Friends screen show "Add", "Requested", "Accept" or "Friends" straight away.
    relationship: Relationship = "none"
    request_id: uuid.UUID | None = None
