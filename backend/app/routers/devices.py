from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.device import DeviceToken
from app.models.user import User

router = APIRouter(prefix="/devices", tags=["Push notifications"])


class DeviceRequest(BaseModel):
    token: str = Field(min_length=10, max_length=4096, description="The Firebase Cloud Messaging token of this phone")
    platform: str = Field(default="android", pattern="^(android|ios|web)$")


@router.post("", status_code=status.HTTP_204_NO_CONTENT, summary="Register this phone for push notifications")
def register_device(
    body: DeviceRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    # A phone that changes hands (log out, someone else logs in) moves to the new account.
    statement = insert(DeviceToken).values(token=body.token, user_id=current_user.id, platform=body.platform)
    db.execute(
        statement.on_conflict_do_update(
            index_elements=[DeviceToken.token],
            set_={"user_id": current_user.id, "platform": body.platform, "updated_at": func.now()},
        )
    )
    db.commit()


@router.post(
    "/unregister", status_code=status.HTTP_204_NO_CONTENT, summary="Stop push notifications to this phone (log out)"
)
def unregister_device(
    body: DeviceRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    db.execute(delete(DeviceToken).where(DeviceToken.token == body.token, DeviceToken.user_id == current_user.id))
    db.commit()
