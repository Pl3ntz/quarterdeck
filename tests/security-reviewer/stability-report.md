# Stability Report — security-reviewer

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 3
- **Generated:** 2026-07-01T12:08:20Z

## Summary

- **Stability score** (ESTAVEL / total): **62%** (8/13)
- **Detection score** (mean hit rate): **79%**
- **Fluctuating:** 4 · **Blind:** 1
- **False positives / run:** 0.3 (per-run: [1, 0, 0])
- **Obvious:** 3/5 stable
- **Subtle:** 5/8 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| hardcoded-db-dsn | 18 | hardcoded credentials | subtle | 0/3 | CEGO |
| hardcoded-jwt-secret | 19 | hardcoded secret | obvious | 3/3 | ESTAVEL |
| insecure-randomness-token | 29 | insecure randomness | subtle | 3/3 | ESTAVEL |
| weak-hash-md5-token | 31 | weak crypto | subtle | 3/3 | ESTAVEL |
| sql-injection-search | 42 | SQL injection | obvious | 1/3 | FLUTUANTE |
| command-injection-export | 65 | command injection | obvious | 2/3 | FLUTUANTE |
| unsafe-deserialization-pick… | 72 | unsafe deserialization | obvious | 3/3 | ESTAVEL |
| path-traversal-template | 87 | path traversal | subtle | 3/3 | ESTAVEL |
| ssrf-preview | 94 | SSRF | subtle | 3/3 | ESTAVEL |
| missing-authz-delete | 99 | missing authorization | subtle | 2/3 | FLUTUANTE |
| webhook-keyless-signature | 111 | forgeable webhook signature | subtle | 3/3 | ESTAVEL |
| webhook-timing-signature | 112 | observable crypto comparison | subtle | 2/3 | FLUTUANTE |
| debug-bind-all-interfaces | 118 | debug mode exposed | obvious | 3/3 | ESTAVEL |

## ⚠ Fluctuating (non-deterministic detection)

- `1/3` **SQL injection** (obvious, CRITICAL)
- `2/3` **command injection** (obvious, CRITICAL)
- `2/3` **missing authorization** (subtle, HIGH)
- `2/3` **observable crypto comparison** (subtle, MEDIUM)

## ✗ Blind (never detected)

- **hardcoded credentials** (subtle, MEDIUM)
