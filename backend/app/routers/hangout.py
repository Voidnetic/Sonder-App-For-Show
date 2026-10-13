import uuid

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.deps import get_current_user
from app.models.message import Message, MessageType
from app.models.moment import Moment
from app.models.user import User
from app.schemas.message import CreateMessageRequest, MessageResponse
from app.schemas.user import UserResponse
from app.security import decode_access_token
from app.ws_manager import manager

router = APIRouter(tags=["Hangout"])


def _to_response(message: Message, db: Session) -> MessageResponse:
    author = db.get(User, message.author_id) if message.author_id else None
    return MessageResponse(
        id=message.id,
        moment_id=message.moment_id,
        author=UserResponse.model_validate(author) if author else None,
        type=message.type,
        text=message.text,
        created_at=message.created_at,
    )


def _assert_participant(moment_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if user_id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


def _persist_message(moment_id: uuid.UUID, author_id: uuid.UUID, text: str, db: Session) -> Message:
    message = Message(moment_id=moment_id, author_id=author_id, type=MessageType.USER, text=text)
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
    return [_to_response(m, db) for m in messages]


@router.post(
    "/moments/{moment_id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a Hangout chat message (also broadcast live to connected WebSocket clients)",
)
async def send_message(
    moment_id: uuid.UUID,
    body: CreateMessageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    _assert_participant(moment_id, current_user.id, db)
    message = _persist_message(moment_id, current_user.id, body.text, db)
    response = _to_response(message, db)
    await manager.broadcast(moment_id, response.model_dump(mode="json"))
    return response


@router.websocket("/ws/moments/{moment_id}")
async def hangout_websocket(websocket: WebSocket, moment_id: uuid.UUID, token: str = "") -> None:
    """
    Live connection for the Hangout tab.

    Connect with `?token=<JWT access token>`. Incoming JSON `{"text": "..."}` frames are
    persisted and rebroadcast to every client connected to this moment's room.
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

    await manager.connect(moment_id, websocket)
    try:
        while True:
            payload = await websocket.receive_json()
            text = (payload or {}).get("text", "").strip()
            if not text:
                continue

            session = SessionLocal()
            try:
                message = _persist_message(moment_id, user_id, text, session)
                response = _to_response(message, session)
            finally:
                session.close()

            await manager.broadcast(moment_id, response.model_dump(mode="json"))
    except WebSocketDisconnect:
        manager.disconnect(moment_id, websocket)
