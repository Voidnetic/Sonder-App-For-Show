-- Sonder database schema (PostgreSQL 13+).
-- Applied by backend/scripts/setup_db.ps1 (Windows) or setup_db.sh (macOS/Linux).

CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'declined');
CREATE TYPE message_type AS ENUM ('system', 'user');

CREATE TABLE users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(80)  NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    avatar_color  VARCHAR(7)   NOT NULL DEFAULT '#E6E6FA',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE friendships (
    id           UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID              NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipient_id UUID              NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status       friendship_status NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMPTZ       NOT NULL DEFAULT now(),
    CONSTRAINT uq_friendship_pair UNIQUE (requester_id, recipient_id),
    CONSTRAINT ck_friendship_not_self CHECK (requester_id <> recipient_id)
);
CREATE INDEX idx_friendships_recipient_status ON friendships (recipient_id, status);

CREATE TABLE moments (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    title        VARCHAR(120) NOT NULL,
    creator_id   UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    accent_color VARCHAR(7)   NOT NULL DEFAULT '#E6E6FA',
    unlock_at    TIMESTAMPTZ  NOT NULL,
    revealed_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_moments_unlock_at ON moments (unlock_at);

CREATE TABLE moment_participants (
    moment_id UUID NOT NULL REFERENCES moments (id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    PRIMARY KEY (moment_id, user_id)
);
CREATE INDEX idx_moment_participants_user ON moment_participants (user_id);

CREATE TABLE memories (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    moment_id   UUID         NOT NULL REFERENCES moments (id) ON DELETE CASCADE,
    author_id   UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    image_url   VARCHAR(255) NOT NULL,
    caption     VARCHAR(280),
    captured_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_memories_moment ON memories (moment_id, captured_at);
CREATE INDEX idx_memories_author ON memories (author_id);

CREATE TABLE messages (
    id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    moment_id  UUID          NOT NULL REFERENCES moments (id) ON DELETE CASCADE,
    author_id  UUID          REFERENCES users (id) ON DELETE SET NULL,
    type       message_type  NOT NULL DEFAULT 'user',
    text       VARCHAR(2000) NOT NULL,
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_moment ON messages (moment_id, created_at);
