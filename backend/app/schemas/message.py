import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.message import MessageType
from app.schemas.user import UserResponse


class CreateMessageRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class MessageResponse(BaseModel):
    id: uuid.UUID
    moment_id: uuid.UUID
    author: UserResponse | None
    type: MessageType
    text: str
    created_at: datetime
