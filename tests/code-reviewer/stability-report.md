# Stability Report — code-reviewer

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-06-22T20:06:05Z

## Summary

- **Stability score** (ESTAVEL / total): **73%** (8/11)
- **Detection score** (mean hit rate): **80%**
- **Fluctuating:** 1 · **Blind:** 2
- **False positives / run:** 2.2 (per-run: [2, 2, 1, 4, 2])
- **Obvious:** 6/6 stable
- **Subtle:** 2/5 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| mutable-default-cache | 18 | mutable default argument | obvious | 5/5 | ESTAVEL |
| load-ledger-no-error-handli… | 22 | missing error handling | subtle | 4/5 | FLUTUANTE |
| unused-result-var | 43 | dead/unused code | obvious | 5/5 | ESTAVEL |
| unused-loop-var-placed-at | 50 | dead/unused code | subtle | 0/5 | CEGO |
| reconcile-mutates-input | 54 | mutation / contract | subtle | 5/5 | ESTAVEL |
| range-off-by-one | 64 | off-by-one | obvious | 5/5 | ESTAVEL |
| swallowed-exception-pass | 73 | swallowed exception | obvious | 5/5 | ESTAVEL |
| parse-qty-implicit-none | 74 | type/contract mismatch | subtle | 5/5 | ESTAVEL |
| restock-negative-amount | 78 | logic bug / unguarded | subtle | 0/5 | CEGO |
| shadow-builtin-max | 85 | shadowed name | obvious | 5/5 | ESTAVEL |
| connection-resource-leak | 95 | resource leak | obvious | 5/5 | ESTAVEL |

## ⚠ Fluctuating (non-deterministic detection)

- `4/5` **missing error handling** (subtle, MEDIUM)

## ✗ Blind (never detected)

- **dead/unused code** (subtle, LOW)
- **logic bug / unguarded** (subtle, MEDIUM)
