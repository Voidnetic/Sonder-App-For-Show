-- Push notifications. Safe to run more than once (applied by the API on every start).

-- One row per phone. A person signed in on two phones gets notifications on both.
CREATE TABLE IF NOT EXISTS device_tokens (
    token      VARCHAR(4096) PRIMARY KEY,
    user_id    UUID          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    platform   VARCHAR(20)   NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens (user_id);

-- Set once the "your moment is unlocked" notification has gone out, so it is sent only once.
ALTER TABLE moments ADD COLUMN IF NOT EXISTS unlock_notified_at TIMESTAMPTZ;
