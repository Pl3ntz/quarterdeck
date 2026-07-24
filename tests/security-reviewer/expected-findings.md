# Expected Findings — security-reviewer

13 seeded vulnerabilities across the fixture, mixing obvious and subtle.
Keywords favour code tokens (identifiers, symbols, literals) so matching is
language-agnostic — the agent's prose may be EN or PT-BR, but it always cites the
same identifiers. Matched (≥50% overlap) against the finding text near the line.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| hardcoded-db-dsn | 18 | hardcoded credentials | MEDIUM | DB_DSN; dsn; hardcoded; credentials | subtle |
| hardcoded-jwt-secret | 19 | hardcoded secret | CRITICAL | JWT_SECRET; secret; hardcoded; signing | obvious |
| insecure-randomness-token | 29 | insecure randomness | HIGH | random; randint; token; predictable | subtle |
| weak-hash-md5-token | 31 | weak crypto | HIGH | md5; hashlib; hash; weak | subtle |
| sql-injection-search | 42 | SQL injection | CRITICAL | sql; injection; search_reports; ilike | obvious |
| command-injection-export | 65 | command injection | CRITICAL | subprocess; shell; command; export_report | obvious |
| unsafe-deserialization-pickle | 72 | unsafe deserialization | CRITICAL | pickle; loads; deserialization; import_report | obvious |
| path-traversal-template | 87 | path traversal | HIGH | send_file; join; path; traversal | subtle |
| ssrf-preview | 94 | SSRF | HIGH | ssrf; requests; preview; src | subtle |
| missing-authz-delete | 99 | missing authorization | HIGH | delete_report; tenant; authorization; ownership | subtle |
| webhook-keyless-signature | 111 | forgeable webhook signature | HIGH | webhook; sha256; render_complete; hmac | subtle |
| webhook-timing-signature | 112 | observable crypto comparison | MEDIUM | compare_digest; timing; constant; signature | subtle |
| debug-bind-all-interfaces | 118 | debug mode exposed | HIGH | debug; 0.0.0.0; app.run; production | obvious |

## Scope

These are the only intended vulnerabilities. A finding that matches none of these
rows (by keyword + nearby line) counts as a false positive.
