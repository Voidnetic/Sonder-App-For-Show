import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.deps import get_current_user
from app.models.memory import Memory
from app.models.message import Message, MessageType
from app.models.moment import Moment
from app.models.user import User
from app.schemas.message import CreateMessageRequest, MessageResponse
from app.schemas.user import UserResponse
from app.push import notify_in_background, notify_users
from app.relationships import blocked_ids
from app.security import decode_access_token
from app.storage import photo_url
from app.utils import to_utc
from app.ws_manager import manager

router = APIRouter(tags=["Hangout"])


def _to_response(message: Message, db: Session) -> MessageResponse:
    author = db.get(User, message.author_id) if message.author_id else None
    photo = db.get(Memory, message.memory_id) if message.memory_id else None
    return MessageResponse(
        id=message.id,
        moment_id=message.moment_id,
        author=UserResponse.model_validate(author) if author else None,
        type=message.type,
        text=message.text,
        created_at=message.created_at,
        memory_id=photo.id if photo else None,
        memory_image_url=photo_url(photo.image_url) if photo else None,
    )


def _reply_photo(moment: Moment, memory_id: uuid.UUID | None, db: Session) -> uuid.UUID | None:
    """Checks a photo being replied to is in this moment and has been revealed."""
    if memory_id is None:
        return None
    memory = db.get(Memory, memory_id)
    if memory is None or memory.moment_id != moment.id or to_utc(moment.unlock_at) > datetime.now(timezone.utc):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can only reply to photos once the moment unlocks")
    return memory.id


def _assert_participant(moment_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if user_id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


def _chat_recipients(moment: Moment, author_id: uuid.UUID, db: Session) -> list[uuid.UUID]:
    """Everyone else in the moment, except people who blocked the author (or were blocked by them)."""
    hidden = blocked_ids(author_id, db)
    return [p.id for p in moment.participants if p.id != author_id and p.id not in hidden]


def _chat_notification(moment: Moment, author_name: str, text: str) -> tuple[str, str, dict[str, str]]:
    preview = text if len(text) <= 120 else text[:117] + "..."
    return moment.title, f"{author_name}: {preview}", {"type": "chat", "moment_id": str(moment.id)}


def _persist_message(
    moment_id: uuid.UUID, author_id: uuid.UUID, text: str, db: Session, memory_id: uuid.UUID | None = None
) -> Message:
    message = Message(moment_id=moment_id, author_id=author_id, type=MessageType.USER, text=text, memory_id=memory_id)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message


@router.get(
    "/moments/{moment_id}/messages",
    response_model=list[MessageResponse],
    summary="Get Hangout chat history for a moment",
)
def list_messages(
    moment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MessageResponse]:
    _assert_participant(moment_id, current_user.id, db)
    messages = db.scalars(
        select(Message).where(Message.moment_id == moment_id).order_by(Message.created_at.asc())
    ).all()
    # Live messages from blocked people are filtered by the app, which knows its block list.
    hidden = blocked_ids(current_user.id, db)
    return [_to_response(m, db) for m in messages if m.author_id not in hidden]


@router.post(
    "/moments/{moment_id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a Hangout chat message (also broadcast live to connected WebSocket clients)",
)
async def send_message(
    moment_id: uuid.UUID,
    body: CreateMessageRequest,
    background: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    moment = _assert_participant(moment_id, current_user.id, db)
    memory_id = _reply_photo(moment, body.memory_id, db)
    message = _persist_message(moment_id, current_user.id, body.text, db, memory_id)
    response = _to_response(message, db)
    background.add_task(
        notify_users,
        _chat_recipients(moment, current_user.id, db),
        *_chat_notification(moment, current_user.name, body.text),
    )
    await manager.broadcast(moment_id, response.model_dump(mode="json"))
    return response


@router.websocket("/ws/moments/{moment_id}")
async def hangout_websocket(websocket: WebSocket, moment_id: uuid.UUID, token: str = "") -> None:
    """
    Live connection for the Hangout tab.

    Connect with `?token=<JWT access token>`. Incoming JSON frames:
      {"text": "..."}      a chat message: saved and rebroadcast to everyone in the moment's room
      {"typing": true}     started / stopped typing: passed on to the others, never saved
    The server also sends {"event": "presence", "user_ids": [...]} whenever someone opens or leaves.
    """
    user_id = decode_access_token(token)
    if user_id is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    db = SessionLocal()
    try:
        moment = db.get(Moment, moment_id)
        if moment is None or user_id not in {p.id for p in moment.participants}:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    finally:
        db.close()

    await manager.connect(moment_id, websocket, user_id)
    try:
        while True:
            try:
                payload = await websocket.receive_json()
            except ValueError:
                continue  # ignore frames that aren't valid JSON
            if isinstance(payload, dict) and isinstance(payload.get("typing"), bool):
                await manager.broadcast(
                    moment_id,
                    {"event": "typing", "user_id": str(user_id), "typing": payload["typing"]},
                    exclude=websocket,
                )
                continue
            raw_text = payload.get("text") if isinstance(payload, dict) else None
            text = raw_text.strip()[:2000] if isinstance(raw_text, str) else ""
            if not text:
                continue

            session = SessionLocal()
            try:
                room = session.get(Moment, moment_id)
                try:
                    raw_photo = payload.get("memory_id")
                    memory_id = _reply_photo(room, uuid.UUID(raw_photo), session) if raw_photo and room else None
                except (HTTPException, ValueError, TypeError):
                    continue  # not a photo in this moment (yet): drop the frame
                message = _persist_message(moment_id, user_id, text, session, memory_id)
                response = _to_response(message, session)
                room = session.get(Moment, moment_id)
                recipients = _chat_recipients(room, user_id, session) if room else []
                author_name = response.author.name if response.author else "Someone"
                notification = _chat_notification(room, author_name, text) if room else None
            finally:
                session.close()
            if notification:
                notify_in_background(recipients, *notification)

            await manager.broadcast(moment_id, response.model_dump(mode="json"))
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(moment_id, websocket)
