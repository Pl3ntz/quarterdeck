# Stability Report — database-specialist

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T13:46:25Z

## Summary

- **Stability score** (ESTAVEL / total): **100%** (8/8)
- **Detection score** (mean hit rate): **100%**
- **Fluctuating:** 0 · **Blind:** 0
- **False positives / run:** 0.6 (per-run: [0, 0, 2, 0, 1])
- **Obvious:** 3/3 stable
- **Subtle:** 5/5 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| timestamp-not-tz | 10 | TIMESTAMP not TIMESTAMPTZ | obvious | 5/5 | ESTAVEL |
| float-for-money | 17 | FLOAT for money column | obvious | 5/5 | ESTAVEL |
| fk-no-index | 15 | unindexed foreign key | obvious | 5/5 | ESTAVEL |
| email-nullable-varchar | 8 | nullable VARCHAR should be TEXT N… | subtle | 5/5 | ESTAVEL |
| json-not-jsonb | 9 | JSON instead of JSONB | subtle | 5/5 | ESTAVEL |
| fk-no-on-delete | 15 | FK missing ON DELETE action | subtle | 5/5 | ESTAVEL |
| add-notnull-no-default | 25 | NOT NULL add without default | subtle | 5/5 | ESTAVEL |
| index-not-concurrent | 28 | non-concurrent index build locks … | subtle | 5/5 | ESTAVEL |
