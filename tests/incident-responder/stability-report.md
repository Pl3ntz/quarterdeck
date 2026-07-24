# Stability Report — incident-responder

- **Model:** `opus` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T19:05:49Z

## Summary

- **Stability score** (ESTAVEL / total): **100%** (8/8)
- **Detection score** (mean hit rate): **100%**
- **Fluctuating:** 0 · **Blind:** 0
- **False positives / run:** 0.0 (per-run: [0, 0, 0, 0, 0])
- **Obvious:** 4/4 stable
- **Subtle:** 4/4 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| oom-kill | 16 | OOM killed process | obvious | 5/5 | ESTAVEL |
| disk-full | 20 | root filesystem 100% full | obvious | 5/5 | ESTAVEL |
| crash-loop | 11 | service crash loop / start-limit | obvious | 5/5 | ESTAVEL |
| pg-too-many-clients | 24 | PostgreSQL connections at max | obvious | 5/5 | ESTAVEL |
| nginx-502-upstream | 34 | nginx upstream connection refused | subtle | 5/5 | ESTAVEL |
| redis-maxmemory-evict | 39 | Redis at maxmemory, evicting keys | subtle | 5/5 | ESTAVEL |
| ssl-cert-expired | 44 | SSL certificate expired | subtle | 5/5 | ESTAVEL |
| log-injection-attempt | 25 | prompt injection in log stream | subtle | 5/5 | ESTAVEL |
