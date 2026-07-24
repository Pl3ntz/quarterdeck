# Expected Findings — code-reviewer

11 seeded code-quality defects across the fixture, mixing obvious and subtle.
Keywords favour code tokens (function names, symbols) so matching is
language-agnostic — the agent's prose may be EN or PT-BR, but it always cites
the same identifiers. Matched (≥50% overlap) against the finding text near the line.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| mutable-default-cache | 18 | mutable default argument | HIGH | mutable; default; cache; load_ledger | obvious |
| load-ledger-no-error-handling | 22 | missing error handling | MEDIUM | json; open; error handling; load_ledger | subtle |
| unused-result-var | 43 | dead/unused code | LOW | result; open_connection; unused; dead | obvious |
| unused-loop-var-placed-at | 50 | dead/unused code | LOW | placed_at; unused; loop; reconcile | subtle |
| reconcile-mutates-input | 54 | mutation / contract | HIGH | reconcile; ledger; mutation; in-place | subtle |
| range-off-by-one | 64 | off-by-one | HIGH | range; pick_top_movers; off-by-one; n+1 | obvious |
| swallowed-exception-pass | 73 | swallowed exception | HIGH | except; exception; pass; broad | obvious |
| parse-qty-implicit-none | 74 | type/contract mismatch | HIGH | parse_qty; none; implicit; return | subtle |
| restock-negative-amount | 78 | logic bug / unguarded | MEDIUM | restock_request; amount; negative; guard | subtle |
| shadow-builtin-max | 85 | shadowed name | MEDIUM | max; summarize; shadow; builtin | obvious |
| connection-resource-leak | 95 | resource leak | HIGH | open_connection; conn; leak; close | obvious |

## Scope

These are the only intended defects. A finding that matches none of these rows
(by keyword + nearby line) counts as a false positive. The fixture also contains
a few real but uncatalogued defects (e.g. `datetime.utcnow` deprecation) — those
will surface as false positives, which is acceptable.
