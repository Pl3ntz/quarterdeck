# Expected Findings — database-specialist

8 seeded PostgreSQL schema/migration issues in the fixture (`test-schema.sql`),
mixing obvious and subtle. Keywords favour the SQL tokens / concepts the agent
cites, so matching is language-agnostic (agent prose may be EN or PT-BR).

**Detection ceiling:** the agent's output contract caps at ~150 tokens (top
findings only), so exhaustive recall of all 8 is not expected. Read the
**stability** signal (which issues surface on *every* run), not raw recall.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| timestamp-not-tz | 10 | TIMESTAMP not TIMESTAMPTZ | MEDIUM | TIMESTAMP; TIMESTAMPTZ; timezone | obvious |
| float-for-money | 17 | FLOAT for money column | HIGH | FLOAT; NUMERIC; amount; money | obvious |
| fk-no-index | 15 | unindexed foreign key | HIGH | index; foreign key; owner_id; join | obvious |
| email-nullable-varchar | 8 | nullable VARCHAR should be TEXT NOT NULL | LOW | NOT NULL; VARCHAR; TEXT; email | subtle |
| json-not-jsonb | 9 | JSON instead of JSONB | MEDIUM | JSON; JSONB; indexable | subtle |
| fk-no-on-delete | 15 | FK missing ON DELETE action | MEDIUM | ON DELETE; foreign key; cascade; references | subtle |
| add-notnull-no-default | 25 | NOT NULL add without default | HIGH | NOT NULL; DEFAULT; rewrite; migration | subtle |
| index-not-concurrent | 28 | non-concurrent index build locks table | HIGH | CONCURRENTLY; index; lock; CREATE INDEX | subtle |

## Scope

These are the only intended issues. A finding matching none of these rows (by
keyword overlap near the cited line) counts as a false positive. Pure app-code
or security findings are outside database-specialist's scope and, if reported,
are false positives here.
