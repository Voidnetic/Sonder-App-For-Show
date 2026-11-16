"""Who is in a moment (group): invites, joining, leaving and deleting."""

import uuid
from datetime import datetime

from sqlalchemy import delete, insert, select, update
from sqlalchemy.orm import Session

from app.accounts import delete_memory
from app.models.memory import Memory
from app.models.moment import INVITED, JOINED, Moment, moment_participants


def membership(moment_id: uuid.UUID, user_id: uuid.UUID, db: Session):
    """The person's row in the moment (status, invited_by, opened_at), or None if they aren't in it."""
    return db.execute(
        select(moment_participants).where(
            moment_participants.c.moment_id == moment_id, moment_participants.c.user_id == user_id
        )
    ).first()


def add_member(
    moment_id: uuid.UUID, user_id: uuid.UUID, db: Session, *, invited_by: uuid.UUID | None = None
) -> bool:
    """Joins the creator straight in; anyone else is invited. Returns False if they were already in it."""
    if membership(moment_id, user_id, db) is not None:
        return False
    db.execute(
        insert(moment_participants).values(
            moment_id=moment_id,
            user_id=user_id,
            status=INVITED if invited_by else JOINED,
            invited_by=invited_by,
        )
    )
    return True


def accept_invite(moment_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> None:
    db.execute(
        update(moment_participants)
        .where(moment_participants.c.moment_id == moment_id, moment_participants.c.user_id == user_id)
        .values(status=JOINED)
    )


def remove_member(moment_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> None:
    db.execute(
        delete(moment_participants).where(
            moment_participants.c.moment_id == moment_id, moment_participants.c.user_id == user_id
        )
    )


def mark_opened(moment_id: uuid.UUID, user_id: uuid.UUID, when: datetime, db: Session) -> None:
    db.execute(
        update(moment_participants)
        .where(
            moment_participants.c.moment_id == moment_id,
            moment_participants.c.user_id == user_id,
            moment_participants.c.opened_at.is_(None),
        )
        .values(opened_at=when)
    )


def joined_member_ids(moment_id: uuid.UUID, db: Session) -> list[uuid.UUID]:
    return list(
        db.scalars(
            select(moment_participants.c.user_id)
            .where(moment_participants.c.moment_id == moment_id, moment_participants.c.status == JOINED)
            .order_by(moment_participants.c.joined_at)
        ).all()
    )


def delete_moment(moment: Moment, db: Session) -> None:
    """Deletes the moment for everyone: its photos (files included), chat and memberships."""
    for memory in db.scalars(select(Memory).where(Memory.moment_id == moment.id)).all():
        delete_memory(memory, db)
    db.flush()
    # Chat messages and memberships go with the row (ON DELETE CASCADE in the schema).
    db.delete(moment)


def leave_moment(moment: Moment, user_id: uuid.UUID, db: Session) -> bool:
    """
    Takes the person out of the moment. Their photos stay for everyone else (history is kept).
    If they made it, someone else who joined takes it over. If nobody who joined is left, the moment is
    deleted. Returns True when it was deleted.
    """
    remove_member(moment.id, user_id, db)
    others = joined_member_ids(moment.id, db)
    if not others:
        delete_moment(moment, db)
        return True
    if moment.creator_id == user_id:
        moment.creator_id = others[0]
    return False
