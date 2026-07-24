# Stability Report — staff-engineer

- **Model:** `opus` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T18:19:30Z

## Summary

- **Stability score** (ESTAVEL / total): **100%** (7/7)
- **Detection score** (mean hit rate): **100%**
- **Fluctuating:** 0 · **Blind:** 0
- **False positives / run:** 0.0 (per-run: [0, 0, 0, 0, 0])
- **Obvious:** 1/1 stable
- **Subtle:** 6/6 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| shared-table-blast-radius | 20 | migration on shared table | obvious | 5/5 | ESTAVEL |
| notnull-migration-lock | 22 | NOT NULL add locks/breaks shared … | subtle | 5/5 | ESTAVEL |
| redis-key-namespace-collisi… | 28 | unnamespaced Redis key collision | subtle | 5/5 | ESTAVEL |
| copy-paste-util-propagation | 35 | duplicated helper pattern propaga… | subtle | 5/5 | ESTAVEL |
| sync-async-drift | 40 | sync vs async DB pattern drift | subtle | 5/5 | ESTAVEL |
| systemd-hardening-drift | 43 | missing systemd hardening vs peers | subtle | 5/5 | ESTAVEL |
| schema-naming-divergence | 46 | column naming divergence | subtle | 5/5 | ESTAVEL |
