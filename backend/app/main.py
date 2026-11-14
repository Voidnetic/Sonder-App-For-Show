from pathlib import Path

from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, ProgrammingError

from app.config import settings
from app.database import engine
from app.routers import auth, friends, hangout, legal, memories, moments, safety, users

Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="Sonder API",
    description=(
        "API for Sonder: create time-locked group Moments, capture hidden Memories, "
        "chat in the Hangout, and reveal everything together. Interactive docs below; "
        "every endpoint is prefixed with /api, matching the routes used by the Flutter app."
    ),
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

api_router = APIRouter(prefix="/api")
for router in (
    auth.router,
    users.router,
    friends.router,
    moments.router,
    memories.router,
    hangout.router,
    safety.router,
):
    api_router.include_router(router)
app.include_router(api_router)
# Public web pages Google Play asks for: privacy policy and account deletion.
app.include_router(legal.router)


@app.on_event("startup")
def check_database() -> None:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1 FROM users LIMIT 1"))
    except OperationalError as exc:
        raise RuntimeError(
            f"Cannot connect to PostgreSQL. Check DATABASE_URL in backend/.env ({str(exc.orig).strip()})"
        ) from exc
    except ProgrammingError as exc:
        raise RuntimeError(
            "Connected to PostgreSQL but the Sonder tables are missing. "
            "Run backend/scripts/setup_db (see SETUP.md) to create them."
        ) from exc
    apply_migrations()


MIGRATIONS = [Path(__file__).resolve().parent.parent / "db" / "03_accounts_and_safety.sql"]


def apply_migrations() -> None:
    """Brings older databases up to date. Every migration file is safe to run again."""
    with engine.begin() as connection:
        for path in MIGRATIONS:
            connection.exec_driver_sql(path.read_text(encoding="utf-8"))


@app.get("/", tags=["Health"])
def health() -> dict[str, str]:
    return {"status": "ok", "service": "sonder-api"}
