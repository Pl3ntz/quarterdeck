# Expected Findings — performance-optimizer

7 seeded application-level performance issues in the fixture (`test-code.py`),
mixing obvious and subtle. Keywords favour the code tokens / concepts the agent
cites, so matching is language-agnostic (agent prose may be EN or PT-BR).

**Detection ceiling:** the agent's output contract caps at ~150 tokens (top
findings only), so exhaustive recall of all 7 is not expected. Read the
**stability** signal (which issues surface on *every* run), not raw recall.
Infra findings (PG config, Redis, Nginx) are out of scope here — the harness
feeds a single file with no system access.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| n-plus-1-owner-query | 26 | N+1 query | HIGH | N+1; loop; query; join | obvious |
| blocking-sync-http-async | 37 | blocking I/O in event loop | HIGH | requests; blocking; async; event loop | obvious |
| time-sleep-async | 52 | blocking sleep on event loop | HIGH | time.sleep; blocking; async; event loop | obvious |
| engine-per-request | 14 | no connection pooling | HIGH | create_engine; pool; connection; per-request | subtle |
| no-pagination-select-all | 22 | unbounded result set | MEDIUM | SELECT *; LIMIT; pagination; payload | subtle |
| cpu-bound-event-loop | 45 | CPU-bound work on event loop | MEDIUM | run_in_executor; CPU; blocking; loop | subtle |
| no-cache-expensive-agg | 49 | expensive query uncached | MEDIUM | cache; recomputed; expensive; redis | subtle |

## Scope

These are the only intended issues. A finding matching none of these rows (by
keyword overlap near the cited line) counts as a false positive. Pure code-quality
or security findings are outside performance-optimizer's scope and, if reported,
are false positives here.
