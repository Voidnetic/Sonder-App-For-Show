import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user, get_verified_user
from app.groups import accept_invite, add_member, delete_moment, leave_moment, mark_opened, membership, remove_member
from app.models.memory import Memory
from app.models.moment import INVITED, JOINED, Moment, moment_participants
from app.models.user import User
from app.schemas.moment import AddParticipantRequest, CreateMomentRequest, MomentResponse
from app.schemas.user import UserResponse
from app.push import notify_users
from app.relationships import friend_ids
from app.utils import to_utc

router = APIRouter(prefix="/moments", tags=["Moments"])


def _to_response(moment: Moment, db: Session, viewer: User) -> MomentResponse:
    memory_count = db.scalar(select(func.count(Memory.id)).where(Memory.moment_id == moment.id)) or 0
    latest = db.scalar(
        select(Memory).where(Memory.moment_id == moment.id).order_by(Memory.captured_at.desc()).limit(1)
    )
    latest_author = db.get(User, latest.author_id) if latest else None
    creator = db.get(User, moment.creator_id)
    now = datetime.now(timezone.utc)
    is_locked = to_utc(moment.unlock_at) > now
    mine = membership(moment.id, viewer.id, db)
    inviter = db.get(User, mine.invited_by) if mine is not None and mine.invited_by else None
    pending_count = (
        db.scalar(
            select(func.count())
            .select_from(moment_participants)
            .where(moment_participants.c.moment_id == moment.id, moment_participants.c.status == INVITED)
        )
        or 0
    )
    opened_at = mine.opened_at if mine is not None else None
    return MomentResponse(
        id=moment.id,
        title=moment.title,
        creator=UserResponse.model_validate(creator),
        participants=[UserResponse.model_validate(p) for p in moment.participants],
        accent_color=moment.accent_color,
        unlock_at=moment.unlock_at,
        revealed_at=moment.revealed_at,
        is_locked=is_locked,
        memory_count=memory_count,
        friend_count=len(moment.participants),
        last_captured_at=latest.captured_at if latest else None,
        last_captured_by=UserResponse.model_validate(latest_author) if latest_author else None,
        my_status=mine.status if mine is not None else JOINED,
        invited_by=UserResponse.model_validate(inviter) if inviter else None,
        opened_at=opened_at,
        is_ready=not is_locked and opened_at is None,
        pending_count=pending_count,
    )


def _get_moment_for_participant(moment_id: uuid.UUID, current_user: User, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    if moment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moment not found")
    if current_user.id not in {p.id for p in moment.participants}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not part of this moment")
    return moment


def _my_moments(current_user: User, *conditions):
    """Moments the user has joined (not just been invited to), filtered by `conditions`."""
    return (
        select(Moment)
        .join(moment_participants, moment_participants.c.moment_id == Moment.id)
        .where(moment_participants.c.user_id == current_user.id, moment_participants.c.status == JOINED, *conditions)
    )


def _invite_push(background: BackgroundTasks, moment: Moment, inviter: User, user_ids: list[uuid.UUID]) -> None:
    if user_ids:
        background.add_task(
            notify_users,
            user_ids,
            f"{inviter.name} invited you to {moment.title} 📸",
            "Open Sonder to accept or decline.",
            {"type": "moment_invite", "moment_id": str(moment.id)},
        )


@router.post("", response_model=MomentResponse, status_code=status.HTTP_201_CREATED, summary="Create a new moment")
def create_moment(
    body: CreateMomentRequest,
    background: BackgroundTasks,
    current_user: User = Depends(get_verified_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    # Only friends can be added, so nobody can be pulled into a moment by a stranger (or someone they blocked).
    friends = friend_ids(current_user.id, db)
    invited = set(body.participant_ids) - {current_user.id}
    if invited - friends:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can only add friends to a moment")

    moment = Moment(
        title=body.title,
        creator_id=current_user.id,
        unlock_at=body.unlock_at,
        accent_color=body.accent_color or "#E6E6FA",
    )
    db.add(moment)
    db.flush()
    # The creator is in straight away; friends get an invite they accept or decline.
    add_member(moment.id, current_user.id, db)
    for user_id in invited:
        add_member(moment.id, user_id, db, invited_by=current_user.id)
    db.commit()
    db.refresh(moment)
    _invite_push(background, moment, current_user, list(invited))
    return _to_response(moment, db, current_user)


@router.get(
    "/active",
    response_model=list[MomentResponse],
    summary="Moments for Home: still counting down, or unlocked but not opened yet (Ready to Open)",
)
def list_active_moments(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[MomentResponse]:
    unlocked = Moment.unlock_at <= func.now()
    moments = db.scalars(
        _my_moments(current_user, or_(~unlocked, moment_participants.c.opened_at.is_(None)))
        # Ready to Open first (oldest first), then the countdowns, soonest first.
        .order_by(case((unlocked, 0), else_=1), Moment.unlock_at.asc())
    ).all()
    return [_to_response(m, db, current_user) for m in moments]


@router.get(
    "/archive",
    response_model=list[MomentResponse],
    summary="The Past Vault: unlocked moments the user has opened",
)
def list_archive_moments(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[MomentResponse]:
    moments = db.scalars(
        _my_moments(current_user, and_(Moment.unlock_at <= func.now(), moment_participants.c.opened_at.is_not(None)))
        .order_by(Moment.unlock_at.desc())
    ).all()
    return [_to_response(m, db, current_user) for m in moments]


@router.get("/invitations", response_model=list[MomentResponse], summary="Moments a friend invited the user to")
def list_invitations(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[MomentResponse]:
    moments = db.scalars(
        select(Moment)
        .join(moment_participants, moment_participants.c.moment_id == Moment.id)
        .where(moment_participants.c.user_id == current_user.id, moment_participants.c.status == INVITED)
        .order_by(moment_participants.c.joined_at.desc())
    ).all()
    return [_to_response(m, db, current_user) for m in moments]


def _get_invite(moment_id: uuid.UUID, current_user: User, db: Session) -> Moment:
    moment = db.get(Moment, moment_id)
    mine = membership(moment_id, current_user.id, db) if moment else None
    if moment is None or mine is None or mine.status != INVITED:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "This invitation is no longer open")
    return moment


@router.post("/{moment_id}/accept", response_model=MomentResponse, summary="Accept an invitation and join the moment")
def accept_invitation(
    moment_id: uuid.UUID,
    background: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    moment = _get_invite(moment_id, current_user, db)
    inviter = membership(moment_id, current_user.id, db).invited_by
    accept_invite(moment_id, current_user.id, db)
    db.commit()
    db.refresh(moment)
    if inviter:
        background.add_task(
            notify_users,
            [inviter],
            moment.title,
            f"{current_user.name} joined 🎉",
            {"type": "moment_joined", "moment_id": str(moment.id)},
        )
    return _to_response(moment, db, current_user)


@router.post("/{moment_id}/decline", status_code=status.HTTP_204_NO_CONTENT, summary="Decline an invitation")
def decline_invitation(
    moment_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    _get_invite(moment_id, current_user, db)
    remove_member(moment_id, current_user.id, db)
    db.commit()


@router.get("/{moment_id}", response_model=MomentResponse, summary="Get moment details")
def get_moment(
    moment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MomentResponse:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    return _to_response(moment, db, current_user)


@router.post("/{moment_id}/participants", response_model=MomentResponse, summary="Invite another friend")
def add_participant(
    moment_id: uuid.UUID,
    body: AddParticipantRequest,
    background: BackgroundTasks,
    current_user: User = Depends(get_verified_user),
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
    if new_participant.id not in friend_ids(current_user.id, db):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can only add friends to a moment")

    if add_member(moment.id, new_participant.id, db, invited_by=current_user.id):
        db.commit()
        db.refresh(moment)
        _invite_push(background, moment, current_user, [new_participant.id])
    return _to_response(moment, db, current_user)


@router.post(
    "/{moment_id}/reveal",
    response_model=MomentResponse,
    summary="Open an unlocked moment: the first time, it moves from Home to the user's Past Vault",
)
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
    mark_opened(moment.id, current_user.id, now, db)
    db.commit()
    db.refresh(moment)
    return _to_response(moment, db, current_user)


@router.post(
    "/{moment_id}/leave",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Leave a moment. Your photos stay for the others; if nobody is left, the moment is deleted",
)
def leave(moment_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    leave_moment(moment, current_user.id, db)
    db.commit()


@router.delete(
    "/{moment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a moment for everyone, with its photos and chat (only whoever made it)",
)
def delete(moment_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    moment = _get_moment_for_participant(moment_id, current_user, db)
    if moment.creator_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the person who made this moment can delete it")
    delete_moment(moment, db)
    db.commit()
