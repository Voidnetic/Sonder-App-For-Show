import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.memory import Memory, MemoryHide
from app.models.moment import Moment
from app.models.user import User
from app.schemas.memory import LockedMemoryResponse, MemoryResponse
from app.schemas.user import UserResponse
from app.relationships import blocked_ids
from app.storage import delete_photo, photo_url, save_photo
from app.utils import to_utc

router = APIRouter(prefix="/moments/{moment_id}/memories", tags=["Memories"])

# Content type -> file extension used when saving the upload.
ALLOWED_CONTENT_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "image/heic": ".heic"}
MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024  # 8MB


def _get_moment_for_participant(moment_id: uuid.UUID, current_user: User, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if current_user.id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


def _is_locked(moment: Moment) -> bool:
    return to_utc(moment.unlock_at) > datetime.now(timezone.utc)


async def _save_upload(file: UploadFile) -> str:
    """Checks the photo and stores it; returns its storage reference."""
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only jpeg, png, webp or heic photos are allowed")
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Photo must be smaller than 8MB")
    if not contents:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The photo is empty")
    # Uploading to R2 is blocking network I/O, so keep it off the event loop.
    return await run_in_threadpool(save_photo, contents, ALLOWED_CONTENT_TYPES[file.content_type], file.content_type)


def _full(memory: Memory, author: User, viewer: User, hidden: bool = False) -> MemoryResponse:
    return MemoryResponse(
        id=memory.id,
        moment_id=memory.moment_id,
        author=UserResponse.model_validate(author),
        image_url=photo_url(memory.image_url),
        caption=memory.caption,
        captured_at=memory.captured_at,
        mine=memory.author_id == viewer.id,
        hidden=hidden,
    )


def _own_locked_memory(moment_id: uuid.UUID, memory_id: uuid.UUID, current_user: User, db: Session) -> Memory:
    """The user's own photo in a moment that is still counting down (the only time it can change)."""
    moment = _get_moment_for_participant(moment_id, current_user, db)
    memory = db.get(Memory, memory_id)
    if memory is None or memory.moment_id != moment_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")
    if memory.author_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You can only change your own photos")
    if not _is_locked(moment):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "This moment has unlocked, so its photos are permanent. You can hide it instead."
        )
    return memory


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
    image_ref = await _save_upload(file)
    memory = Memory(moment_id=moment_id, author_id=current_user.id, image_url=image_ref, caption=caption)
    db.add(memory)
    db.commit()
    db.refresh(memory)
    return _full(memory, current_user, current_user)


@router.get(
    "",
    response_model=None,
    summary="List memories for a moment - other people's photos are hidden (locked placeholders) until it unlocks",
)
def list_memories(
    moment_id: uuid.UUID,
    include_hidden: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MemoryResponse | LockedMemoryResponse]:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    blocked = blocked_ids(current_user.id, db)
    memories = [
        m
        for m in db.scalars(
            select(Memory).where(Memory.moment_id == moment_id).order_by(Memory.captured_at.asc())
        ).all()
        if m.author_id not in blocked
    ]

    if _is_locked(moment):
        # Your own photos come with their link, so you can check, swap or delete them before the reveal.
        return [
            LockedMemoryResponse(
                id=m.id,
                moment_id=m.moment_id,
                author=UserResponse.model_validate(db.get(User, m.author_id)),
                captured_at=m.captured_at,
                mine=m.author_id == current_user.id,
                image_url=photo_url(m.image_url) if m.author_id == current_user.id else None,
            )
            for m in memories
        ]

    hidden = set(
        db.scalars(
            select(MemoryHide.memory_id).where(
                MemoryHide.user_id == current_user.id, MemoryHide.memory_id.in_([m.id for m in memories])
            )
        ).all()
    )
    return [
        _full(m, db.get(User, m.author_id), current_user, hidden=m.id in hidden)
        for m in memories
        if include_hidden or m.id not in hidden
    ]


@router.put(
    "/{memory_id}",
    response_model=MemoryResponse,
    summary="Swap your photo for another one (only while the moment is still counting down)",
)
async def replace_memory(
    moment_id: uuid.UUID,
    memory_id: uuid.UUID,
    file: UploadFile = File(...),
    caption: str | None = Form(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MemoryResponse:
    memory = _own_locked_memory(moment_id, memory_id, current_user, db)
    new_ref = await _save_upload(file)
    old_ref = memory.image_url
    memory.image_url = new_ref
    if caption is not None:
        memory.caption = caption
    db.commit()
    db.refresh(memory)
    delete_photo(old_ref)
    return _full(memory, current_user, current_user)


@router.delete(
    "/{memory_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete your photo (only while the moment is still counting down)",
)
def delete_memory(
    moment_id: uuid.UUID,
    memory_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    memory = _own_locked_memory(moment_id, memory_id, current_user, db)
    ref = memory.image_url
    db.delete(memory)
    db.commit()
    delete_photo(ref)


def _visible_memory(moment_id: uuid.UUID, memory_id: uuid.UUID, current_user: User, db: Session) -> Memory:
    _get_moment_for_participant(moment_id, current_user, db)
    memory = db.get(Memory, memory_id)
    if memory is None or memory.moment_id != moment_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")
    return memory


@router.post("/{memory_id}/hide", status_code=status.HTTP_204_NO_CONTENT, summary="Hide a photo from your own view")
def hide_memory(
    moment_id: uuid.UUID,
    memory_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    _visible_memory(moment_id, memory_id, current_user, db)
    if db.get(MemoryHide, (current_user.id, memory_id)) is None:
        db.add(MemoryHide(user_id=current_user.id, memory_id=memory_id))
        db.commit()


@router.delete("/{memory_id}/hide", status_code=status.HTTP_204_NO_CONTENT, summary="Show a hidden photo again")
def unhide_memory(
    moment_id: uuid.UUID,
    memory_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    _visible_memory(moment_id, memory_id, current_user, db)
    db.execute(delete(MemoryHide).where(MemoryHide.user_id == current_user.id, MemoryHide.memory_id == memory_id))
    db.commit()
