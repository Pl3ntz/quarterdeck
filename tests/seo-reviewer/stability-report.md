# Stability Report — seo-reviewer

- **Model:** `sonnet` (via `claude -p`)
- **Runs (K):** 5
- **Generated:** 2026-07-01T13:52:28Z

## Summary

- **Stability score** (ESTAVEL / total): **100%** (8/8)
- **Detection score** (mean hit rate): **100%**
- **Fluctuating:** 0 · **Blind:** 0
- **False positives / run:** 3.0 (per-run: [4, 4, 3, 3, 1])
- **Obvious:** 5/5 stable
- **Subtle:** 3/3 stable

> Stable findings are the judge's trustworthy floor. Fluctuating findings
> are where the judge is non-deterministic — the signal worth acting on.

## Per-finding

| # | Line | Finding | Diff | Hit rate | Class |
|---|---|---|---|---|---|
| noindex-on-prod | 8 | noindex on production page | obvious | 5/5 | ESTAVEL |
| multiple-h1 | 20 | multiple H1 tags | obvious | 5/5 | ESTAVEL |
| lazy-lcp-hero | 14 | hero/LCP image lazy-loaded | obvious | 5/5 | ESTAVEL |
| no-viewport-meta | 5 | missing viewport meta | obvious | 5/5 | ESTAVEL |
| relative-canonical | 10 | non-absolute canonical URL | subtle | 5/5 | ESTAVEL |
| img-no-alt | 23 | image missing alt | obvious | 5/5 | ESTAVEL |
| img-no-dimensions | 26 | image missing width/height | subtle | 5/5 | ESTAVEL |
| js-only-nav | 29 | JavaScript-only navigation | subtle | 5/5 | ESTAVEL |
