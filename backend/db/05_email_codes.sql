-- One-time codes sent by email: verifying an address, and resetting a password.
-- Safe to run more than once (applied by the API on every start).
CREATE TABLE IF NOT EXISTS email_codes (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    purpose    VARCHAR(20)  NOT NULL CHECK (purpose IN ('verify', 'reset')),
    code_hash  VARCHAR(64)  NOT NULL,  -- HMAC of the code; the code itself is never stored
    attempts   INTEGER      NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ  NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_email_codes_user ON email_codes (user_id, purpose, created_at);
