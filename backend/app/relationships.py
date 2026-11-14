"""Who can see and contact whom: friendships and blocks."""

import uuid

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.friendship import Friendship, FriendshipStatus
from app.models.safety import Block


def blocked_ids(user_id: uuid.UUID, db: Session) -> set[uuid.UUID]:
    """Everyone this user blocked, plus everyone who blocked this user. Blocks hide both ways."""
    rows = db.execute(
        select(Block.blocker_id, Block.blocked_id).where(
            or_(Block.blocker_id == user_id, Block.blocked_id == user_id)
        )
    ).all()
    return {blocked if blocker == user_id else blocker for blocker, blocked in rows}


def is_blocked_between(a: uuid.UUID, b: uuid.UUID, db: Session) -> bool:
    return b in blocked_ids(a, db)


def friend_ids(user_id: uuid.UUID, db: Session) -> set[uuid.UUID]:
    rows = db.execute(
        select(Friendship.requester_id, Friendship.recipient_id).where(
            Friendship.status == FriendshipStatus.ACCEPTED,
            or_(Friendship.requester_id == user_id, Friendship.recipient_id == user_id),
        )
    ).all()
    return {recipient if requester == user_id else requester for requester, recipient in rows}


def friendship_between(a: uuid.UUID, b: uuid.UUID, db: Session) -> Friendship | None:
    return db.scalar(
        select(Friendship).where(
            or_(
                (Friendship.requester_id == a) & (Friendship.recipient_id == b),
                (Friendship.requester_id == b) & (Friendship.recipient_id == a),
            )
        )
    )
