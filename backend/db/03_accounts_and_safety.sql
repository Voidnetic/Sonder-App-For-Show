-- Google sign-in, blocking, reporting and account deletion requests.
-- Safe to run more than once: the API applies it automatically every time it starts,
-- so databases created before this file existed are upgraded without any manual step.

-- Accounts made with Google have no password.
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_google_sub ON users (google_sub);

-- A block hides both people from each other: search, friend requests, photos and chat.
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT ck_block_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks (blocked_id);

-- Reports of users, photos or chat messages, reviewed by the admins (ADMIN_EMAILS).
CREATE TABLE IF NOT EXISTS reports (
    id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id      UUID          REFERENCES users (id) ON DELETE SET NULL,
    target_type      VARCHAR(20)   NOT NULL CHECK (target_type IN ('user', 'memory', 'message')),
    target_id        UUID          NOT NULL,
    reported_user_id UUID          REFERENCES users (id) ON DELETE SET NULL,
    reason           VARCHAR(40)   NOT NULL,
    details          VARCHAR(1000),
    status           VARCHAR(20)   NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    resolved_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status, created_at);

-- Deletion requests sent from the website by people who can't sign in to the app any more.
CREATE TABLE IF NOT EXISTS deletion_requests (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email      VARCHAR(255) NOT NULL,
    note       VARCHAR(1000),
    status     VARCHAR(20)  NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done')),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
