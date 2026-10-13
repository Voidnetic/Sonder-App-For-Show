-- Run as a PostgreSQL superuser with: -v dbname=... -v dbuser=... -v dbpass=...
-- Safe to re-run: skips the role/database if they already exist.

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'dbuser', :'dbpass')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'dbuser') \gexec

SELECT format('CREATE DATABASE %I OWNER %I ENCODING ''UTF8''', :'dbname', :'dbuser')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'dbname') \gexec
