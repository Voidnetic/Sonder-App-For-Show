import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

AVATAR_COLORS = ["#E6E6FA", "#FFFACD", "#E0F8E6", "#FFD9C0"]


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    # Unique, lowercase handle (see app.usernames). Log in with it instead of the email, find friends by it.
    username: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True)
    # A new email address waiting for its emailed code (when the server sends email).
    pending_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # None for accounts created with Google sign-in.
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Google's stable account id ("sub" claim), set once the account is linked to Google.
    google_sub: Mapped[str | None] = mapped_column(String(255), nullable=True, unique=True)
    # True once Google has confirmed this person owns the email address.
    email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    avatar_color: Mapped[str] = mapped_column(String(7), nullable=False, default=AVATAR_COLORS[0])
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    @property
    def google_linked(self) -> bool:
        return self.google_sub is not None

    @property
    def has_password(self) -> bool:
        return self.password_hash is not None
