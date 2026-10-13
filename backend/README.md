# Sonder API

Backend for the Sonder Flutter app. Users create time-locked group **Moments**, capture hidden
**Memories** (photos), chat in the **Hangout** tab, and see everything when the countdown ends.

Built with **FastAPI**, **SQLAlchemy 2.0**, and **PostgreSQL**.

**To run it, follow [`../SETUP.md`](../SETUP.md).**

- API base URL: `http://localhost:8000/api`
- Interactive docs: `http://localhost:8000/docs`
- Uploaded photos: `http://localhost:8000/uploads/<filename>`

## Layout

```
backend/
  app/
    main.py          App setup, routers, startup DB check
    config.py        Settings read from .env / environment
    database.py      SQLAlchemy engine and session (sessions pinned to UTC)
    security.py      bcrypt password hashing, JWT tokens
    deps.py          get_current_user dependency
    ws_manager.py    WebSocket rooms for Hangout chat
    models/          SQLAlchemy models (one per table)
    schemas/         Pydantic request and response models
    routers/         Endpoints: auth, users, friends, moments, memories, hangout
  db/
    01_schema.sql    Tables, enums, indexes. This file is the source of truth for the schema.
    02_seed.sql      Demo data
  scripts/
    setup_db.ps1     Creates the role, database, tables, demo data, and .env (Windows)
    setup_db.sh      Same, for macOS / Linux
```

## Database

The schema lives in `db/01_schema.sql`. The app does **not** create tables itself. On startup it
checks that the tables exist and stops with a clear error if they don't.

If you change a model in `app/models/`, make the same change in `db/01_schema.sql`.
Existing databases need the change applied by hand (an `ALTER TABLE ...` statement), or a reset:
drop the `sonder` database and run the setup script again.

## API overview

| Area | Endpoints |
|---|---|
| Auth | `POST /api/auth/register`, `POST /api/auth/login` |
| Users | `GET /api/users/me`, `PATCH /api/users/me`, `GET /api/users/search?q=` |
| Friends | `POST /api/friends/requests`, `GET /api/friends/requests?direction=incoming\|outgoing`, `PATCH /api/friends/requests/{id}/accept`, `PATCH /api/friends/requests/{id}/decline`, `GET /api/friends`, `DELETE /api/friends/{friendId}` |
| Moments | `POST /api/moments`, `GET /api/moments/active`, `GET /api/moments/archive`, `GET /api/moments/{id}`, `POST /api/moments/{id}/participants`, `POST /api/moments/{id}/reveal` |
| Memories | `POST /api/moments/{id}/memories` (multipart photo upload), `GET /api/moments/{id}/memories` (photos hidden until unlock) |
| Hangout chat | `GET /api/moments/{id}/messages`, `POST /api/moments/{id}/messages`, `WS /api/ws/moments/{id}?token=<jwt>` |

Every endpoint except `/api/auth/*` needs the header `Authorization: Bearer <access_token>`.

### Which Flutter screen uses which endpoint

| Screen | Endpoints |
|---|---|
| `home_screen` | `GET /api/moments/active`, `POST /api/moments` |
| `active_moment_screen` | `GET /api/moments/{id}`; Memories tab: `GET/POST .../memories`; Hangout tab: messages endpoints and the WebSocket |
| `camera_screen`, `global_camera_screen` | `POST /api/moments/{id}/memories` |
| `moments_archive_screen` | `GET /api/moments/archive` |
| `profile_screen` | `GET /api/users/me`, `GET /api/friends` |
| `reveal_screen` | `POST /api/moments/{id}/reveal`, once `is_locked` is false |
