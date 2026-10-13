import uuid

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    email: EmailStr
    avatar_color: str


class UserProfileResponse(UserResponse):
    memory_count: int
    active_moment_count: int
    friend_count: int


class UpdateUserRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    avatar_color: str | None = Field(default=None, pattern=r"^#([0-9A-Fa-f]{6})$")
