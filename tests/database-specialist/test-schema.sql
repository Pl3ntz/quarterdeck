-- Reporting schema + a follow-up migration.
-- Seeded with 8 PostgreSQL schema/migration issues (obvious + subtle) for the
-- database-specialist stability fixture. Static review — no live DB needed.

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255),                         -- ISSUE 4 (subtle): nullable + VARCHAR(n); should be TEXT NOT NULL
    metadata JSON,                              -- ISSUE 5 (subtle): JSON instead of JSONB (not indexable)
    created_at TIMESTAMP DEFAULT now()          -- ISSUE 1 (obvious): TIMESTAMP, not TIMESTAMPTZ
);

CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY,
    owner_id BIGINT REFERENCES users(id),       -- ISSUE 6 (subtle): FK has no ON DELETE action
    amount FLOAT NOT NULL,                       -- ISSUE 2 (obvious): FLOAT for money; use NUMERIC(p,s)
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);
-- ISSUE 3 (obvious): owner_id is a foreign key with no supporting index (slow joins / cascades)

-- ---- follow-up migration, runs against an already-populated `reports` table ----

-- ISSUE 7 (subtle): NOT NULL with no DEFAULT rewrites the table AND fails on existing rows
ALTER TABLE reports ADD COLUMN reviewed_by BIGINT NOT NULL;

-- ISSUE 8 (subtle): non-concurrent index build takes an exclusive lock during business hours
CREATE INDEX idx_reports_status ON reports(status);
