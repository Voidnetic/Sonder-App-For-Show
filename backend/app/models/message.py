import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class MessageType(str, enum.Enum):
    SYSTEM = "system"
    USER = "user"


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    moment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("moments.id"), nullable=False)
    author_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    type: Mapped[MessageType] = mapped_column(
        Enum(MessageType, name="message_type", values_callable=lambda e: [m.value for m in e]),
        default=MessageType.USER,
        nullable=False,
    )
    text: Mapped[str] = mapped_column(String(2000), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
