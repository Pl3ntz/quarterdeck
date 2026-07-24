# Stability Report — ux-reviewer

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T13:14:33Z

## Summary

- **Stability score** (ESTAVEL / total): **88%** (7/8)
- **Detection score** (mean hit rate): **98%**
- **Fluctuating:** 1 · **Blind:** 0
- **False positives / run:** 1.0 (per-run: [1, 1, 0, 3, 0])
- **Obvious:** 4/4 stable
- **Subtle:** 3/4 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| img-missing-alt | 24 | missing alt text | obvious | 5/5 | ESTAVEL |
| div-onclick-not-button | 30 | non-native interactive | obvious | 5/5 | ESTAVEL |
| input-no-label | 35 | input without label | obvious | 5/5 | ESTAVEL |
| password-block-paste | 51 | paste blocked on password | subtle | 5/5 | ESTAVEL |
| error-color-only | 55 | color-only error indicator | subtle | 4/5 | FLUTUANTE |
| icon-button-no-name | 58 | icon button no accessible name | obvious | 5/5 | ESTAVEL |
| touch-target-too-small | 66 | touch target under 24px | subtle | 5/5 | ESTAVEL |
| dialog-no-focus-mgmt | 71 | modal missing focus management | subtle | 5/5 | ESTAVEL |

## ⚠ Fluctuating (non-deterministic detection)

- `4/5` **color-only error indicator** (subtle, MEDIUM)
