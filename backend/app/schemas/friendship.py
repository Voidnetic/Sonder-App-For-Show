import uuid

from pydantic import BaseModel, ConfigDict

from app.models.friendship import FriendshipStatus
from app.schemas.user import UserResponse


class AddFriendRequest(BaseModel):
    recipient_id: uuid.UUID


class FriendResponse(UserResponse):
    synced: bool = True


class FriendRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    requester: UserResponse
    recipient: UserResponse
    status: FriendshipStatus
