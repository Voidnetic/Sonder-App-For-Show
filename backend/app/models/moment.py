import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, Table, and_, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

# Who is in a moment. A friend who was added is 'invited' until they accept; declining deletes the row.
JOINED = "joined"
INVITED = "invited"

moment_participants = Table(
    "moment_participants",
    Base.metadata,
    Column("moment_id", UUID(as_uuid=True), ForeignKey("moments.id"), primary_key=True),
    Column("user_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
    Column("status", String(10), nullable=False, server_default=JOINED),
    Column("invited_by", UUID(as_uuid=True), ForeignKey("users.id"), nullable=True),
    Column("joined_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    # When this person first opened the unlocked capsule (it then moves from Home to their Past Vault).
    Column("opened_at", DateTime(timezone=True), nullable=True),
)


def _joined_members():
    return and_(Moment.id == moment_participants.c.moment_id, moment_participants.c.status == JOINED)


def _member_user():
    from app.models.user import User

    return User.id == moment_participants.c.user_id


class Moment(Base):
    __tablename__ = "moments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    creator_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    accent_color: Mapped[str] = mapped_column(String(7), nullable=False, default="#E6E6FA")
    unlock_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revealed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # People who have joined (accepted). Invited people aren't in it until they accept, so they can't see the
    # photos or the chat. Read-only: memberships are written through `moment_participants` (see app.groups).
    participants = relationship(
        "User",
        secondary=moment_participants,
        primaryjoin=_joined_members,
        secondaryjoin=_member_user,
        viewonly=True,
        lazy="selectin",
    )
