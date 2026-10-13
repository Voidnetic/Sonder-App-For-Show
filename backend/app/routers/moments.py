import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.memory import Memory
from app.models.moment import Moment, moment_participants
from app.models.user import User
from app.schemas.moment import AddParticipantRequest, CreateMomentRequest, MomentResponse
from app.schemas.user import UserResponse
from app.utils import to_utc

router = APIRouter(prefix="/moments", tags=["Moments"])


def _to_response(moment: Moment, db: Session) -> MomentResponse:
    memory_count = db.scalar(select(func.count(Memory.id)).where(Memory.moment_id == moment.id)) or 0
    creator = db.get(User, moment.creator_id)
    now = datetime.now(timezone.utc)
    return MomentResponse(
        id=moment.id,
        title=moment.title,
        creator=UserResponse.model_validate(creator),
        participants=[UserResponse.model_validate(p) for p in moment.participants],
        accent_color=moment.accent_color,
        unlock_at=moment.unlock_at,
        revealed_at=moment.revealed_at,
        is_locked=to_utc(moment.unlock_at) > now,
        memory_count=memory_count,
        friend_count=len(moment.participants),
    )


def _get_moment_for_participant(moment_id: uuid.UUID, current_user: User, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if current_user.id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


@router.post("", response_model=MomentResponse, status_code=status.HTTP_201_CREATED, summary="Create a new moment")
def create_moment(
    body: CreateMomentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    participant_ids = {current_user.id, *body.participant_ids}
    participants = db.scalars(select(User).where(User.id.in_(participant_ids))).all()

    moment = Moment(
        title=body.title,
        creator_id=current_user.id,
        unlock_at=body.unlock_at,
        accent_color=body.accent_color or "#E6E6FA",
    )
    moment.participants = list(participants)
    db.add(moment)
    db.commit()
    db.refresh(moment)
    return _to_response(moment, db)


@router.get("/active", response_model=list[MomentResponse], summary="List the current user's not-yet-unlocked moments")
def list_active_moments(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[MomentResponse]:
    moments = db.scalars(
        select(Moment)
        .join(moment_participants, moment_participants.c.moment_id == Moment.id)
        .where(moment_participants.c.user_id == current_user.id, Moment.unlock_at > func.now())
        .order_by(Moment.unlock_at.asc())
    ).all()
    return [_to_response(m, db) for m in moments]


@router.get("/archive", response_model=list[MomentResponse], summary="List the current user's unlocked moments")
def list_archive_moments(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[MomentResponse]:
    moments = db.scalars(
        select(Moment)
        .join(moment_participants, moment_participants.c.moment_id == Moment.id)
        .where(moment_participants.c.user_id == current_user.id, Moment.unlock_at <= func.now())
        .order_by(Moment.unlock_at.desc())
    ).all()
    return [_to_response(m, db) for m in moments]


@router.get("/{moment_id}", response_model=MomentResponse, summary="Get moment details")
def get_moment(
    moment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    return _to_response(moment, db)


@router.post("/{moment_id}/participants", response_model=MomentResponse, summary="Invite another participant")
def add_participant(
    moment_id: uuid.UUID,
    body: AddParticipantRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if moment.creator_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the creator can add participants")

    new_participant = db.get(User, body.user_id)
    if new_participant is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

    if new_participant.id not in {p.id for p in moment.participants}:
        moment.participants.append(new_participant)
        db.commit()
        db.refresh(moment)
    return _to_response(moment, db)


@router.post("/{moment_id}/reveal", response_model=MomentResponse, summary="Mark a moment as revealed once it has unlocked")
def reveal_moment(
    moment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    now = datetime.now(timezone.utc)
    if to_utc(moment.unlock_at) > now:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This moment has not unlocked yet")
    if moment.revealed_at is None:
        moment.revealed_at = now
        db.commit()
        db.refresh(moment)
    return _to_response(moment, db)
