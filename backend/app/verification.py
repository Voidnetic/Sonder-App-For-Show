"""Six-digit email codes for verifying an address and resetting a password."""

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.email_code import EmailCode
from app.models.user import User

CODE_LIFETIME = timedelta(minutes=15)
RESEND_AFTER = timedelta(seconds=60)
MAX_PER_HOUR = 6
MAX_ATTEMPTS = 5


def verification_required(user: User) -> bool:
    """Only when the server can send email: otherwise accounts work exactly as before."""
    return settings.email_enabled and not user.email_verified


def _hash(code: str) -> str:
    return hmac.new(settings.jwt_secret.encode(), code.encode(), hashlib.sha256).hexdigest()


def new_code(user: User, purpose: str, db: Session) -> str:
    """Creates a code (rate-limited) and returns it so the caller can email it. Older codes stop working."""
    now = datetime.now(timezone.utc)
    recent = db.scalars(
        select(EmailCode.created_at).where(
            EmailCode.user_id == user.id, EmailCode.purpose == purpose, EmailCode.created_at > now - timedelta(hours=1)
        )
    ).all()
    if any(created > now - RESEND_AFTER for created in recent):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Please wait a minute before asking for another code")
    if len(recent) >= MAX_PER_HOUR:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many codes requested. Try again in an hour.")

    for old in db.scalars(
        select(EmailCode).where(EmailCode.user_id == user.id, EmailCode.purpose == purpose, EmailCode.used_at.is_(None))
    ):
        old.used_at = now
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(EmailCode(user_id=user.id, purpose=purpose, code_hash=_hash(code), expires_at=now + CODE_LIFETIME))
    db.commit()
    return code


def use_code(user: User, purpose: str, code: str, db: Session) -> None:
    """Accepts the latest unused code once; raises a readable error otherwise."""
    now = datetime.now(timezone.utc)
    latest = db.scalar(
        select(EmailCode)
        .where(EmailCode.user_id == user.id, EmailCode.purpose == purpose, EmailCode.used_at.is_(None))
        .order_by(EmailCode.created_at.desc())
        .limit(1)
    )
    if latest is None or latest.expires_at < now:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That code has expired. Ask for a new one.")
    if latest.attempts >= MAX_ATTEMPTS:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Too many wrong tries. Ask for a new code.")
    if not hmac.compare_digest(latest.code_hash, _hash(code.strip())):
        latest.attempts += 1
        db.commit()
        left = MAX_ATTEMPTS - latest.attempts
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "That code isn't right." + (f" {left} tries left." if left else " Ask for a new code."),
        )
    latest.used_at = now
    db.commit()


def codes_sent_recently(user: User, purpose: str, db: Session) -> int:
    return db.scalar(
        select(func.count(EmailCode.id)).where(
            EmailCode.user_id == user.id,
            EmailCode.purpose == purpose,
            EmailCode.created_at > datetime.now(timezone.utc) - timedelta(hours=1),
        )
    ) or 0
