"""
Where photos live.

The database stores a reference for each photo:
  /uploads/<file>    a file on this server's disk (local development, and the bundled demo photos)
  r2:<key>           an object in a private Cloudflare R2 bucket

The R2 bucket is never public. The API hands the app a short-lived signed link only when a photo may be
seen (after its moment unlocks), so "hidden until the reveal" holds even for someone who guesses a name.
"""

import uuid
from functools import lru_cache
from pathlib import Path

from app.config import settings

R2_PREFIX = "r2:"


@lru_cache(maxsize=1)
def _r2_client():
    import boto3
    from botocore.config import Config

    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.r2_access_key_id,
        aws_secret_access_key=settings.r2_secret_access_key,
        region_name="auto",
        config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
    )


def save_photo(data: bytes, extension: str, content_type: str) -> str:
    """Stores the photo and returns the reference to keep in the database."""
    name = f"{uuid.uuid4().hex}{extension}"
    if settings.r2_enabled:
        key = f"memories/{name}"
        _r2_client().put_object(Bucket=settings.r2_bucket, Key=key, Body=data, ContentType=content_type)
        return f"{R2_PREFIX}{key}"

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    (upload_dir / name).write_bytes(data)
    return f"/uploads/{name}"


def photo_url(ref: str) -> str:
    """The address the app downloads the photo from."""
    if ref.startswith(R2_PREFIX):
        return _r2_client().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.r2_bucket, "Key": ref[len(R2_PREFIX) :]},
            ExpiresIn=settings.photo_url_expires_seconds,
        )
    return ref


def delete_photo(ref: str) -> None:
    """Best effort: a missing file must never stop an account or report from being deleted."""
    try:
        if ref.startswith(R2_PREFIX):
            _r2_client().delete_object(Bucket=settings.r2_bucket, Key=ref[len(R2_PREFIX) :])
            return
        name = Path(ref).name
        # Demo photos ship with the repo and are shared by the seed data, so they stay.
        if ref.startswith("/uploads/") and not name.startswith("demo-"):
            (Path(settings.upload_dir) / name).unlink(missing_ok=True)
    except Exception:  # noqa: BLE001
        pass
