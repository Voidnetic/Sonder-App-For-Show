"""Permanently deleting an account and everything that belongs to it."""

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.memory import Memory
from app.models.message import Message
from app.models.moment import Moment
from app.models.user import User
from app.storage import delete_photo


def delete_memory(memory: Memory, db: Session) -> None:
    delete_photo(memory.image_url)
    db.delete(memory)


def delete_user_account(user: User, db: Session) -> None:
    """
    Deletes the user, their photos (files included), chat messages, friendships, blocks and reports.
    Moments they created that other people are still in are handed over to another participant,
    so friends don't lose their shared memories. Moments with nobody else in them are deleted.
    """
    # Their own photos, wherever they were posted.
    for memory in db.scalars(select(Memory).where(Memory.author_id == user.id)).all():
        delete_memory(memory, db)
    db.execute(delete(Message).where(Message.author_id == user.id))

    for moment in db.scalars(select(Moment).where(Moment.creator_id == user.id)).all():
        others = [p for p in moment.participants if p.id != user.id]
        if others:
            moment.creator_id = others[0].id
        else:
            for memory in db.scalars(select(Memory).where(Memory.moment_id == moment.id)).all():
                delete_memory(memory, db)
            db.delete(moment)

    db.flush()
    # Friendships, blocks, moment memberships and the user's reports go with the row (ON DELETE CASCADE /
    # SET NULL in the schema).
    db.delete(user)
    db.commit()
