from datetime import datetime, timezone


def to_utc(value: datetime) -> datetime:
    """Normalizes a datetime to timezone-aware UTC, treating naive values as already UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
