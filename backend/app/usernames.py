"""Usernames: unique, lowercase handles like @hassan.k that people can log in with and be found by."""

import re
import secrets
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.user import User

MIN_LENGTH, MAX_LENGTH = 3, 20
_ALLOWED = re.compile(r"^[a-z0-9._]+$")

# Names that would look official or confuse people.
RESERVED = {
    "admin", "administrator", "sonder", "sonderapp", "support", "help", "helpdesk", "mod", "moderator",
    "root", "system", "staff", "team", "official", "security", "mhcorps", "null", "undefined", "me", "you",
}


def normalize(username: str) -> str:
    return username.strip().lstrip("@").lower()


def problem_with(username: str) -> str | None:
    """Why this (already normalized) username can't be used, or None if its format is fine."""
    if not MIN_LENGTH <= len(username) <= MAX_LENGTH:
        return f"Usernames are {MIN_LENGTH} to {MAX_LENGTH} characters"
    if not _ALLOWED.match(username):
        return "Use only letters, numbers, dots and underscores"
    if username.startswith(".") or username.endswith(".") or ".." in username:
        return "Dots can't be at the start or end, or next to each other"
    if not re.search(r"[a-z]", username):
        return "Include at least one letter"
    if username in RESERVED:
        return "That username isn't available"
    return None


def is_taken(username: str, db: Session, *, except_user: uuid.UUID | None = None) -> bool:
    query = select(func.count(User.id)).where(User.username == username)
    if except_user is not None:
        query = query.where(User.id != except_user)
    return (db.scalar(query) or 0) > 0


def check_new_username(raw: str, db: Session, *, except_user: uuid.UUID | None = None) -> str:
    """Returns the normalized username, or raises 400 (bad format) / 409 (taken)."""
    username = normalize(raw)
    problem = problem_with(username)
    if problem:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, problem)
    if is_taken(username, db, except_user=except_user):
        raise HTTPException(status.HTTP_409_CONFLICT, "That username is taken")
    return username


def suggest(seed: str, db: Session) -> str:
    """A free username based on a name or email ("Hassan Khan" -> "hassankhan", or "hassankhan42" if taken)."""
    base = re.sub(r"[^a-z0-9._]", "", seed.lower().split("@")[0].replace(" ", ""))
    base = re.sub(r"\.{2,}", ".", base).strip(".")[: MAX_LENGTH - 4]
    if len(base) < MIN_LENGTH or not re.search(r"[a-z]", base) or base in RESERVED:
        base = (base + "sonder")[: MAX_LENGTH - 4] if base else "sonder"
    if problem_with(base) is None and not is_taken(base, db):
        return base
    for digits in (2, 2, 3, 3, 4, 4):
        candidate = f"{base}{secrets.randbelow(10**digits):0{digits}d}"
        if problem_with(candidate) is None and not is_taken(candidate, db):
            return candidate
    return f"sonder{secrets.token_hex(4)}"


def backfill_usernames(db: Session) -> int:
    """Gives every account made before usernames existed one, based on their name. Returns how many."""
    users = db.scalars(select(User).where(User.username.is_(None)).order_by(User.created_at)).all()
    for user in users:
        user.username = suggest(user.name or user.email, db)
        db.flush()
    db.commit()
    return len(users)
