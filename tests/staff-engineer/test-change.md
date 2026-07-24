# Proposed change: add a `reviewed_by` review workflow to reports

Change proposal for staff-engineer L4 review. Cross-system context is stated
inline (the harness gives no server/grep access), so review the org-level impact
of the changes below.

## Server context (shared box)

Three services run on the same host and share infrastructure:
- `reports-api` (this PR), `billing-api`, `analytics-worker`
- All three connect to the SAME PostgreSQL instance (port 5432), `public` schema.
- Redis (6379) is shared for cache + sessions across all three.

## Changes in this PR

1. Migration on the `reports` table — note `reports` is read by BOTH `reports-api`
   and `analytics-worker`:
   ```sql
   ALTER TABLE reports ADD COLUMN reviewed_by BIGINT NOT NULL;
   ```

2. New cache write in `reports-api/cache.py`:
   ```python
   redis.set(f"user:{uid}:profile", payload)   # billing-api already writes this same key
   ```

3. New helper added to `reports-api/util.py`:
   ```python
   def money(v):            # billing-api already has NUMERIC money handling elsewhere
       return round(v, 2)
   ```

4. `reports-api` does its DB access with sync `psycopg2` here, while `billing-api`
   and `analytics-worker` both use async SQLAlchemy against the same database.

5. The new `reports-api.service` systemd unit has no `ProtectSystem`,
   `NoNewPrivileges`, or `PrivateTmp`, whereas `billing-api.service` is hardened.

6. The new column is named `data_criacao`, while every other table on this schema
   uses `created_at`.
