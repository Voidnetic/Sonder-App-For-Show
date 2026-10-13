#!/usr/bin/env bash
# Sets up the Sonder database on a locally installed PostgreSQL (macOS / Linux).
# Usage (from the project root):   bash backend/scripts/setup_db.sh
# Override defaults with env vars, e.g.  PG_SUPERUSER=me bash backend/scripts/setup_db.sh
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
DB_NAME="${DB_NAME:-sonder}"
DB_USER="${DB_USER:-sonder}"
DB_PASSWORD="${DB_PASSWORD:-sonder}"
NO_SEED="${NO_SEED:-0}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_DIR="$BACKEND_DIR/db"

command -v psql >/dev/null || { echo "psql not found. Install PostgreSQL first."; exit 1; }

if [ -n "${PG_SUPERUSER_PASSWORD+x}" ]; then
  SUPER_PASSWORD="$PG_SUPERUSER_PASSWORD"
else
  read -r -s -p "Password for PostgreSQL superuser '$PG_SUPERUSER' (leave empty if none): " SUPER_PASSWORD
  echo
fi

echo "1/3 Creating role '$DB_USER' and database '$DB_NAME'..."
PGPASSWORD="$SUPER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d postgres -v ON_ERROR_STOP=1 -q \
  -v "dbname=$DB_NAME" -v "dbuser=$DB_USER" -v "dbpass=$DB_PASSWORD" \
  -f "$SCRIPT_DIR/create_role_and_database.sql"

export PGPASSWORD="$DB_PASSWORD"
EXISTS="$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT to_regclass('public.users') IS NOT NULL")"

if [ "$EXISTS" = "t" ]; then
  echo "2/3 Tables already exist - skipping schema and demo data."
else
  echo "2/3 Creating tables..."
  psql -h "$PG_HOST" -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$DB_DIR/01_schema.sql"
  if [ "$NO_SEED" != "1" ]; then
    echo "    Loading demo data..."
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$DB_DIR/02_seed.sql"
  fi
fi
unset PGPASSWORD

ENV_FILE="$BACKEND_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  echo "3/3 backend/.env already exists - leaving it unchanged."
else
  echo "3/3 Writing backend/.env..."
  JWT_SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  cat > "$ENV_FILE" <<EOF
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${PG_HOST}:${PG_PORT}/${DB_NAME}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_MINUTES=10080
CORS_ORIGINS=*
PORT=8000
EOF
fi

echo
echo "Database ready: postgresql://${DB_USER}@${PG_HOST}:${PG_PORT}/${DB_NAME}"
