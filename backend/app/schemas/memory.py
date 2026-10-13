import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.user import UserResponse


class MemoryResponse(BaseModel):
    """Full memory payload - only returned once the moment has unlocked."""

    id: uuid.UUID
    moment_id: uuid.UUID
    author: UserResponse
    image_url: str
    caption: str | None
    captured_at: datetime


class LockedMemoryResponse(BaseModel):
    """Placeholder returned while the moment is still locked - hides the photo."""

    id: uuid.UUID
    moment_id: uuid.UUID
    author: UserResponse
    locked: bool = True
    captured_at: datetime
