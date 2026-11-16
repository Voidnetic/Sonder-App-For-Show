-- Group invites, "Ready to Open", hiding photos and photo replies in the chat.
-- Safe to run more than once (applied by the API on every start).

-- When each person first opened the unlocked capsule. Until then it stays on their Home as "Ready to Open";
-- after that it lives in their Past Vault.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'moment_participants' AND column_name = 'opened_at'
    ) THEN
        ALTER TABLE moment_participants ADD COLUMN opened_at TIMESTAMPTZ;
        -- Capsules that had already unlocked were in everyone's Past Vault, so they stay there.
        UPDATE moment_participants mp SET opened_at = now()
        FROM moments m WHERE m.id = mp.moment_id AND m.unlock_at <= now();
    END IF;
END $$;

-- 'invited' until the person accepts (declining removes the row). Everyone before this was already in.
ALTER TABLE moment_participants ADD COLUMN IF NOT EXISTS status VARCHAR(10) NOT NULL DEFAULT 'joined';
ALTER TABLE moment_participants ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE moment_participants ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_moment_participants_status ON moment_participants (user_id, status);

-- Photos someone hid from their own view of an unlocked capsule (everyone else still sees them).
CREATE TABLE IF NOT EXISTS memory_hides (
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    memory_id  UUID        NOT NULL REFERENCES memories (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, memory_id)
);

-- A chat message can be a reply to one photo (a reaction or a comment from the slideshow).
ALTER TABLE messages ADD COLUMN IF NOT EXISTS memory_id UUID REFERENCES memories (id) ON DELETE SET NULL;
