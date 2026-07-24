# Stability Report — performance-optimizer

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T13:29:10Z

## Summary

- **Stability score** (ESTAVEL / total): **100%** (7/7)
- **Detection score** (mean hit rate): **100%**
- **Fluctuating:** 0 · **Blind:** 0
- **False positives / run:** 0.4 (per-run: [0, 1, 0, 0, 1])
- **Obvious:** 3/3 stable
- **Subtle:** 4/4 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| n-plus-1-owner-query | 26 | N+1 query | obvious | 5/5 | ESTAVEL |
| blocking-sync-http-async | 37 | blocking I/O in event loop | obvious | 5/5 | ESTAVEL |
| time-sleep-async | 52 | blocking sleep on event loop | obvious | 5/5 | ESTAVEL |
| engine-per-request | 14 | no connection pooling | subtle | 5/5 | ESTAVEL |
| no-pagination-select-all | 22 | unbounded result set | subtle | 5/5 | ESTAVEL |
| cpu-bound-event-loop | 45 | CPU-bound work on event loop | subtle | 5/5 | ESTAVEL |
| no-cache-expensive-agg | 49 | expensive query uncached | subtle | 5/5 | ESTAVEL |
