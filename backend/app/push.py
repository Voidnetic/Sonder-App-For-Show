"""
Push notifications through Firebase Cloud Messaging (FCM HTTP v1 API).

Turned on by FIREBASE_SERVICE_ACCOUNT (the service account key from Firebase console > Project settings >
Service accounts). Without it every function here quietly does nothing, so the app works the same, just
without notifications.
"""

import asyncio
import base64
import json
import logging
import uuid
from collections.abc import Iterable
from functools import lru_cache

from sqlalchemy import delete, select, text

from app.config import settings
from app.database import SessionLocal
from app.models.device import DeviceToken
from app.models.moment import JOINED, moment_participants

log = logging.getLogger("sonder.push")

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


@lru_cache(maxsize=1)
def _service_account() -> dict | None:
    raw = settings.firebase_service_account.strip()
    if not raw:
        return None
    try:
        if not raw.startswith("{"):
            raw = base64.b64decode(raw).decode("utf-8")
        info = json.loads(raw)
        return info if info.get("project_id") and info.get("private_key") else None
    except ValueError:
        log.error("FIREBASE_SERVICE_ACCOUNT is not valid JSON (or base64 of it); push notifications are off")
        return None


def enabled() -> bool:
    return _service_account() is not None


@lru_cache(maxsize=1)
def _session():
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    credentials = service_account.Credentials.from_service_account_info(_service_account(), scopes=[FCM_SCOPE])
    return AuthorizedSession(credentials)


def _send_one(token: str, title: str, body: str, data: dict[str, str]) -> bool:
    """Sends to one phone. Returns False when the token is dead and should be forgotten."""
    project_id = _service_account()["project_id"]
    message = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": data,
            "android": {"priority": "high"},
        }
    }
    try:
        response = _session().post(
            f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send", json=message, timeout=10
        )
    except Exception as exc:  # noqa: BLE001 - a network blip must never break the request that triggered it
        log.warning("FCM request failed: %s", exc)
        return True
    if response.status_code == 200:
        return True
    # NOT_FOUND / UNREGISTERED: the app was uninstalled or the token expired.
    if response.status_code == 404 or "UNREGISTERED" in response.text or "registration token" in response.text:
        return False
    log.warning("FCM rejected a message (%s): %s", response.status_code, response.text[:300])
    return True


def notify_users(user_ids: Iterable[uuid.UUID], title: str, body: str, data: dict[str, str] | None = None) -> None:
    """Blocking; call it from a background task or thread, never directly in a request."""
    ids = {uid for uid in user_ids if uid is not None}
    if not ids or not enabled():
        return
    with SessionLocal() as db:
        tokens = db.scalars(select(DeviceToken.token).where(DeviceToken.user_id.in_(ids))).all()
        dead = [t for t in tokens if not _send_one(t, title, body, {k: str(v) for k, v in (data or {}).items()})]
        if dead:
            db.execute(delete(DeviceToken).where(DeviceToken.token.in_(dead)))
            db.commit()


def notify_in_background(user_ids: Iterable[uuid.UUID], title: str, body: str, data: dict | None = None) -> None:
    """For code running on the event loop (the WebSocket handler)."""
    if enabled():
        asyncio.get_running_loop().run_in_executor(None, notify_users, list(user_ids), title, body, data)


# ---------------------------------------------------------------- "your moment is unlocked"


def send_unlock_notifications() -> int:
    """
    Notifies everyone in moments that unlocked in the last 6 hours and haven't been announced yet.
    Claiming the rows with UPDATE ... RETURNING means two server instances never send the same one twice.
    """
    with SessionLocal() as db:
        moments = db.execute(
            text(
                "UPDATE moments SET unlock_notified_at = now() "
                "WHERE unlock_notified_at IS NULL AND unlock_at <= now() AND unlock_at > now() - interval '6 hours' "
                "RETURNING id, title"
            )
        ).all()
        db.commit()
        for moment_id, title in moments:
            members = db.scalars(
                select(moment_participants.c.user_id).where(
                    moment_participants.c.moment_id == moment_id, moment_participants.c.status == JOINED
                )
            ).all()
            notify_users(
                members,
                f"{title} is unlocked ✨",
                "Your photos are ready. Open Sonder to reveal them together.",
                {"type": "moment_unlocked", "moment_id": str(moment_id)},
            )
        return len(moments)


async def unlock_notifier_loop(interval_seconds: int = 60) -> None:
    while True:
        await asyncio.sleep(interval_seconds)
        if not enabled():
            continue
        try:
            await asyncio.to_thread(send_unlock_notifications)
        except Exception:  # noqa: BLE001
            log.exception("Sending unlock notifications failed")
