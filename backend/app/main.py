import asyncio
import os
from pathlib import Path

from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from app.config import settings
from app.database import engine
from app.push import unlock_notifier_loop
from app.routers import auth, devices, friends, hangout, legal, memories, moments, safety, users

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
    devices.router,
):
    api_router.include_router(router)
app.include_router(api_router)
# Public web pages Google Play asks for: privacy policy and account deletion.
app.include_router(legal.router)


DB_DIR = Path(__file__).resolve().parent.parent / "db"
SCHEMA = DB_DIR / "01_schema.sql"
DEMO_DATA = DB_DIR / "02_seed.sql"
# Each file is safe to run again, so they are applied on every start.
MIGRATIONS = [DB_DIR / "03_accounts_and_safety.sql", DB_DIR / "04_push_notifications.sql"]


def _run_sql_file(path: Path) -> None:
    with engine.begin() as connection:
        connection.exec_driver_sql(path.read_text(encoding="utf-8"))


def _tables_exist() -> bool:
    with engine.connect() as connection:
        return connection.execute(text("SELECT to_regclass('public.users') IS NOT NULL")).scalar_one()


DEFAULT_JWT_SECRET = "change-this-in-production"


@app.on_event("startup")
def prepare_database() -> None:
    # On a real host the login-signing key must be secret, or anyone could forge a login.
    on_railway = any(name.startswith("RAILWAY_") for name in os.environ)
    if on_railway and (settings.jwt_secret == DEFAULT_JWT_SECRET or len(settings.jwt_secret) < 32):
        raise RuntimeError("Set JWT_SECRET to a long random value (at least 32 characters) in Railway's Variables.")

    try:
        exists = _tables_exist()
    except OperationalError as exc:
        raise RuntimeError(
            f"Cannot connect to PostgreSQL. Check DATABASE_URL in backend/.env ({str(exc.orig).strip()})"
        ) from exc

    if not exists:
        if not settings.auto_create_schema:
            raise RuntimeError(
                "Connected to PostgreSQL but the Sonder tables are missing. "
                "Run backend/scripts/setup_db (see SETUP.md) or set AUTO_CREATE_SCHEMA=true."
            )
        # A brand-new database, e.g. the first deploy on Railway.
        _run_sql_file(SCHEMA)
        if settings.seed_demo_data:
            _run_sql_file(DEMO_DATA)

    for path in MIGRATIONS:
        _run_sql_file(path)


@app.on_event("startup")
async def start_background_jobs() -> None:
    # Keep a reference so the task isn't garbage collected.
    app.state.unlock_notifier = asyncio.create_task(unlock_notifier_loop())


@app.get("/", tags=["Health"])
def health() -> dict[str, str]:
    return {"status": "ok", "service": "sonder-api"}
