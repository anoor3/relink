CREATE TABLE IF NOT EXISTS persons (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL,
    name            TEXT NOT NULL,
    company         TEXT,
    role            TEXT,
    topics          TEXT,
    personal_details TEXT,
    signals         TEXT,
    tags            TEXT,
    sentiment       TEXT,
    follow_up_intent TEXT,
    relationship_strength INTEGER DEFAULT 5,
    email           TEXT,
    last_contact    TEXT,
    created_at      TEXT
);

CREATE TABLE IF NOT EXISTS interactions (
    id          TEXT PRIMARY KEY,
    person_id   TEXT NOT NULL,
    type        TEXT DEFAULT 'voice_memo',
    content     TEXT NOT NULL,
    created_at  TEXT,
    FOREIGN KEY(person_id) REFERENCES persons(id)
);

CREATE TABLE IF NOT EXISTS email_threads (
    id                  TEXT PRIMARY KEY,
    person_id           TEXT NOT NULL,
    agentmail_thread_id TEXT,
    subject             TEXT,
    status              TEXT DEFAULT 'sent',
    sent_at             TEXT,
    replied_at          TEXT,
    FOREIGN KEY(person_id) REFERENCES persons(id)
);

CREATE INDEX IF NOT EXISTS idx_persons_user ON persons(user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_person ON interactions(person_id);
CREATE INDEX IF NOT EXISTS idx_last_contact ON persons(last_contact);

