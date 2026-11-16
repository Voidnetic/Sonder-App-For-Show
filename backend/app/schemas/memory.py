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
    mine: bool = False
    # Hidden from the user's own view (only listed with include_hidden=true).
    hidden: bool = False


class LockedMemoryResponse(BaseModel):
    """Placeholder returned while the moment is still locked - hides the photo."""

    id: uuid.UUID
    moment_id: uuid.UUID
    author: UserResponse
    locked: bool = True
    captured_at: datetime
    mine: bool = False
    # Only for the user's own photos, so they can check, swap or delete them before the reveal.
    image_url: str | None = None
