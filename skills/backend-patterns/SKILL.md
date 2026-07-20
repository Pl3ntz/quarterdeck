---
name: backend-patterns
description: Backend architecture patterns for the two stacks actually used here — Python (FastAPI + Pydantic v2 + raw SQL, no ORM) and TypeScript (Hono on Bun + Drizzle). API design, hand-written SQL data access, error handling, rate limiting, and graceful degradation.
---

# Backend Development Patterns

Two backend stacks are used here. Match the pattern to the project's real stack — do not import ORM/Repository/Express idioms that aren't used.

| Stack | Framework | Data layer | Where |
|---|---|---|---|
| **Python** | FastAPI + Pydantic v2 | **Raw SQL** — `asyncpg` (Postgres) or `sqlite3` (stdlib). No ORM, no SQLAlchemy, no Alembic. | FastAPI services |
| **TypeScript** | Hono (on Bun) | **Drizzle** query builder (typed SQL, not a Repository). | Hono services |

Core philosophy across both: **hand-written SQL, thin data layer, predictable behavior**. The database access is explicit and auditable, never hidden behind an ORM abstraction.

---

# Python track — FastAPI + Pydantic v2 + raw SQL

## App structure

Two shapes are used depending on size:

- **Router-based** (larger service): a package with `main.py`, `config.py`, `dependencies.py`, and a `routers/` folder (one module per domain). Wire shared resources with `Depends`.
- **Flat module split** (smaller service): `main.py` plus focused modules (`store.py`, `sync.py`, `ranking.py`, …). Constants and tunables live at the top of the module with a one-line comment each.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(_app: FastAPI):
    store.init_db()          # startup
    stop = sync.start()      # background workers off the request path
    yield
    if stop is not None:
        stop.set()           # shutdown

app = FastAPI(title="Service", lifespan=lifespan)
```

CORS origins come from the environment, never hard-coded (prod domain lives in the server `.env`, gitignored):

```python
from fastapi.middleware.cors import CORSMiddleware
_ALLOWED_ORIGINS = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "http://localhost:8000").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "OPTIONS"],   # explicit, not ["*"]
    allow_headers=["content-type"],
)
```

## Validation — Pydantic v2

Model the request body; let validation reject bad input at the edge (a bad shape returns 422 automatically).

```python
from pydantic import BaseModel, Field

class Profile(BaseModel):
    role: str = Field(min_length=1, max_length=120)
    skills: list[str] = Field(default_factory=list)
    scopes: list[str] = Field(min_length=1, max_length=3)   # empty list -> 422
```

## Data layer — raw SQL, no ORM

SQL lives as module-level string constants. A short-lived connection is opened per operation via a context manager (safe across the sync thread and uvicorn's request threads). WAL + `busy_timeout` so readers never block.

```python
import sqlite3
from contextlib import contextmanager

DB_PATH = os.path.join(os.environ.get("DATA_DIR", "/data"), "app.db")
BUSY_TIMEOUT_MS = 5000

_SCHEMA = """
CREATE TABLE IF NOT EXISTS jobs (
  job_url TEXT PRIMARY KEY,
  title TEXT, company TEXT, first_seen_at TEXT,
  active INTEGER DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_jobs_first_seen ON jobs(first_seen_at);
"""

_UPSERT_SQL = "INSERT OR REPLACE INTO jobs (job_url, title, company, first_seen_at, active) VALUES (?, ?, ?, ?, 1)"

@contextmanager
def _conn():
    con = sqlite3.connect(DB_PATH, timeout=BUSY_TIMEOUT_MS / 1000)
    try:
        con.execute("PRAGMA journal_mode=WAL")
        con.execute(f"PRAGMA busy_timeout={BUSY_TIMEOUT_MS}")
        yield con
        con.commit()
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()

def upsert_job(job) -> None:
    with _conn() as c:
        c.execute(_UPSERT_SQL, (job.url, job.title, job.company, _utc_iso()))
```

Postgres uses the same "raw SQL, explicit connection" philosophy through `asyncpg` (a pool, parameterized queries with `$1, $2`), never string interpolation:

```python
rows = await pool.fetch("SELECT id, title FROM jobs WHERE active = $1 ORDER BY first_seen_at DESC LIMIT $2", True, limit)
```

**Never** build SQL by string concatenation with user input — always parameterize (`?` for sqlite3, `$1` for asyncpg).

## Error handling — HTTPException + graceful degradation

Raise `HTTPException` with a specific status. Map known failure classes before the generic case.

```python
from fastapi import HTTPException

@app.post("/api/cv/upload")
async def upload_cv(file: UploadFile = File(...)):
    raw = await file.read()
    if len(raw) > CV_UPLOAD_MAX_BYTES:
        raise HTTPException(status_code=413, detail="Arquivo grande demais.")
    if not raw.startswith(b"%PDF"):                     # magic-byte before any parse
        raise HTTPException(status_code=400, detail="PDF inválido.")
    try:
        return ats.parse(raw)
    except ats.PdfBudgetError:
        raise HTTPException(status_code=413, detail="PDF muito complexo para processar.")
    except ValueError:
        raise HTTPException(status_code=400, detail="Não foi possível ler o PDF.")
```

**Graceful degradation over 500:** when an optional external dependency (an LLM API, a third-party board) fails, degrade to a deterministic fallback instead of returning 500. The critical path must not depend on a flaky upstream.

```python
try:
    ranked = await refine_with_llm(top)          # optional enhancement
except (GroqError, asyncio.TimeoutError):
    logger.warning("refine failed, serving heuristic order")
    ranked = top                                  # deterministic fallback, still 200
```

## Rate limiting — per-IP sliding window

In-process sliding window keyed by client IP, with a cap on the dict so rotating IPs can't grow it unbounded. Only trust forwarded-IP headers when the TCP peer is an internal proxy.

```python
def _client_ip(request: Request) -> str:
    peer = request.client.host if request.client else "unknown"
    if _is_trusted_proxy(peer):                      # private/loopback peer only
        cf = request.headers.get("cf-connecting-ip")
        if cf:
            return cf.strip()
        xff = request.headers.get("x-forwarded-for")
        if xff:
            return xff.split(",")[0].strip()
    return peer                                      # public peer -> headers are forgeable
```

## Config — env + top-of-module constants

Tunables are module constants with a one-line comment; secrets and environment-specific values come from `os.environ`, never committed.

```python
REFINE_DEADLINE = 75.0      # deadline for the LLM refine call
MATCH_RL_PER_MIN = 30       # /api/match requests per IP — anti-flood
CV_UPLOAD_MAX_BYTES = 5 * 1024 * 1024   # 5 MB PDF cap
```

---

# TypeScript track — Hono on Bun + Drizzle

## App structure — route composition + middleware chain

Compose one route module per domain with `app.route()`. Cross-cutting concerns are middleware applied by path prefix. Serve the built SPA last, with a fallback to `index.html`.

```typescript
import { Hono } from 'hono'
import { serveStatic } from 'hono/bun'
import { rateLimitMiddleware, authMiddleware, adminMiddleware } from './middleware.js'
import cvRoutes from './api/cv.js'
import authRoutes from './api/auth.js'
import adminRoutes from './api/admin.js'

const app = new Hono()

// Security headers on every response
app.use('*', async (c, next) => {
  await next()
  c.header('X-Content-Type-Options', 'nosniff')
  c.header('X-Frame-Options', 'DENY')
  c.header('Referrer-Policy', 'strict-origin-when-cross-origin')
})

app.use('/api/*', rateLimitMiddleware)
app.use('/api/cv/*', authMiddleware)          // protect by prefix
app.use('/api/admin/*', adminMiddleware)

app.route('/api/auth', authRoutes)
app.route('/api/cv', cvRoutes)
app.route('/api/admin', adminRoutes)

app.use('/*', serveStatic({ root: './dist/client' }))        // static assets
app.get('*', serveStatic({ path: './dist/client/index.html' })) // SPA fallback

export default {
  port: parseInt(process.env.PORT ?? '4321', 10),
  hostname: process.env.HOST ?? '0.0.0.0',
  fetch: app.fetch,
}
```

## Route handlers — typed context, explicit status

```typescript
import { Hono } from 'hono'
const cvRoutes = new Hono()

cvRoutes.get('/:id', async (c) => {
  const id = c.req.param('id')
  const cv = await getCvById(id)
  if (!cv) return c.json({ error: 'not found' }, 404)
  return c.json(cv)
})

export default cvRoutes
```

## Data layer — Drizzle query builder

Drizzle is a typed query builder over SQL, not an ORM with a Repository layer. Compose queries directly; keep the SQL intent visible.

```typescript
import { eq, desc } from 'drizzle-orm'
import { db } from '../db/index.js'
import { cvs } from '../db/schema.js'

export async function listActiveCvs(userId: string, limit = 20) {
  return db.select({ id: cvs.id, title: cvs.title })
    .from(cvs)
    .where(eq(cvs.userId, userId))
    .orderBy(desc(cvs.updatedAt))
    .limit(limit)          // select only needed columns, always bound the limit
}
```

---

# Cross-cutting (both stacks)

## Retry with exponential backoff (for flaky upstreams)

```python
async def with_retry(fn, max_retries=3):
    for i in range(max_retries):
        try:
            return await fn()
        except TransientError:
            if i == max_retries - 1:
                raise
            await asyncio.sleep(2 ** i)   # 1s, 2s, 4s
```

## Structured logging

Log JSON lines with context; log the failure and degrade, don't swallow it silently.

```python
import logging
logger = logging.getLogger("service")
logging.basicConfig(level=logging.INFO)
logger.info("ranked jobs", extra={"count": len(ranked), "refined": used_llm})
```

---

**Remember:** the two stacks here share one principle — **explicit, hand-written data access and graceful degradation**. When adding backend code, read the target project's real stack first (`requirements.txt`/`pyproject.toml` for Python, `package.json` for TS) and follow the matching track. Do not introduce ORMs, Repository/Service scaffolding, Express, or Next.js API routes — none are used here.
