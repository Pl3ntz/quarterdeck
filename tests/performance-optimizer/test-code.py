# FastAPI reports service — seeded with 7 application-level performance issues
# (obvious + subtle) for the performance-optimizer stability fixture.
# Infra-level tuning (PG/Redis/Nginx) is out of scope: the harness feeds one file.
import time
import requests
from fastapi import FastAPI
from sqlalchemy import create_engine, text

app = FastAPI()


# ISSUE 4 (subtle): a fresh engine per call — no pooling, connection churn on every request
def get_conn():
    engine = create_engine("postgresql://app@localhost/reports")
    return engine.connect()


@app.get("/reports")
async def list_reports():
    conn = get_conn()
    # ISSUE 3 (subtle): fetches every row, no LIMIT / pagination — unbounded payload
    rows = conn.execute(text("SELECT * FROM reports")).fetchall()
    result = []
    for r in rows:
        # ISSUE 1 (obvious): N+1 — one query per row instead of a join / batched IN
        owner = conn.execute(
            text("SELECT name FROM users WHERE id = :id"), {"id": r.owner_id}
        ).fetchone()
        result.append({"id": r.id, "owner": owner.name})
    return result


@app.get("/summary")
async def summary():
    # ISSUE 2 (obvious): blocking sync HTTP call inside an async endpoint — stalls the event loop
    data = requests.get("https://api.example.com/metrics", timeout=30).json()
    # ISSUE 6 (subtle): CPU-bound loop on the event loop, no run_in_executor / offload
    total = 0
    for i in range(5_000_000):
        total += i * i
    return {"data": data, "total": total}


@app.get("/stats")
async def stats():
    conn = get_conn()
    # ISSUE 5 (subtle): expensive aggregate recomputed on every call — no caching layer
    rows = conn.execute(
        text("SELECT count(*), avg(amount) FROM reports GROUP BY status")
    ).fetchall()
    # ISSUE 7 (obvious): time.sleep on the async path blocks the whole event loop
    time.sleep(2)
    return [dict(r._mapping) for r in rows]
