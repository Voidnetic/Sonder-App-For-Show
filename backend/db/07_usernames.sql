-- Unique usernames (log in with them, find friends by them) and changing your email address.
-- Safe to run more than once (applied by the API on every start). Existing accounts get a username
-- generated on start (app.usernames.backfill_usernames), which they can change in the app.
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(20);
-- Always stored in lowercase, so "Hassan" and "hassan" are the same username.
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_username ON users (username);

-- The new address waiting for its emailed code (only used when the server can send email).
ALTER TABLE users ADD COLUMN IF NOT EXISTS pending_email VARCHAR(255);

-- A third kind of emailed code: confirming a new email address.
ALTER TABLE email_codes DROP CONSTRAINT IF EXISTS email_codes_purpose_check;
ALTER TABLE email_codes ADD CONSTRAINT email_codes_purpose_check CHECK (purpose IN ('verify', 'reset', 'email'));
