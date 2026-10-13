import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.deps import get_current_user
from app.models.memory import Memory
from app.models.moment import Moment
from app.models.user import User
from app.schemas.memory import LockedMemoryResponse, MemoryResponse
from app.schemas.user import UserResponse
from app.utils import to_utc

router = APIRouter(prefix="/moments/{moment_id}/memories", tags=["Memories"])

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024  # 8MB


def _get_moment_for_participant(moment_id: uuid.UUID, current_user: User, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if current_user.id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


@router.post(
    "",
    response_model=MemoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Capture a memory (photo) into a moment - hidden from everyone until the moment unlocks",
)
async def capture_memory(
    moment_id: uuid.UUID,
    file: UploadFile = File(...),
    caption: str | None = Form(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MemoryResponse:
    _get_moment_for_participant(moment_id, current_user, db)

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only jpeg, png, webp or heic photos are allowed")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Photo must be smaller than 8MB")

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    extension = Path(file.filename or "").suffix or ".jpg"
    filename = f"{uuid.uuid4().hex}{extension}"
    (upload_dir / filename).write_bytes(contents)

    memory = Memory(
        moment_id=moment_id,
        author_id=current_user.id,
        image_url=f"/uploads/{filename}",
        caption=caption,
    )
    db.add(memory)
    db.commit()
    db.refresh(memory)

    return MemoryResponse(
        id=memory.id,
        moment_id=memory.moment_id,
        author=UserResponse.model_validate(current_user),
        image_url=memory.image_url,
        caption=memory.caption,
        captured_at=memory.captured_at,
    )


@router.get(
    "",
    summary="List memories for a moment - photos are hidden (locked placeholders) until the moment unlocks",
)
def list_memories(
    moment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MemoryResponse] | list[LockedMemoryResponse]:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    memories = db.scalars(
        select(Memory).where(Memory.moment_id == moment_id).order_by(Memory.captured_at.asc())
    ).all()

    is_locked = to_utc(moment.unlock_at) > datetime.now(timezone.utc)
    if is_locked:
        return [
            LockedMemoryResponse(
                id=m.id,
                moment_id=m.moment_id,
                author=UserResponse.model_validate(db.get(User, m.author_id)),
                captured_at=m.captured_at,
            )
            for m in memories
        ]

    return [
        MemoryResponse(
            id=m.id,
            moment_id=m.moment_id,
            author=UserResponse.model_validate(db.get(User, m.author_id)),
            image_url=m.image_url,
            caption=m.caption,
            captured_at=m.captured_at,
        )
        for m in memories
    ]
