# Expected Findings — seo-reviewer

8 seeded SEO issues in the fixture (`test-page.html`), mixing obvious and subtle.
Keywords favour the HTML tokens / concepts the agent cites, so matching is
language-agnostic (agent prose may be EN or PT-BR).

**Detection note:** seo-reviewer has a larger output budget (up to 15 findings /
800 tokens), so recall is fairer than the ~150-token agents — but the primary
signal remains **stability** (which issues surface on *every* run). The fixture
also lacks a meta description and JSON-LD; if flagged, those are real issues
outside this checklist and score as false positives here.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| noindex-on-prod | 8 | noindex on production page | CRITICAL | noindex; robots; index; staging | obvious |
| multiple-h1 | 20 | multiple H1 tags | HIGH | H1; multiple; heading | obvious |
| lazy-lcp-hero | 14 | hero/LCP image lazy-loaded | HIGH | lazy; hero; LCP; loading | obvious |
| no-viewport-meta | 5 | missing viewport meta | HIGH | viewport; meta; device-width | obvious |
| relative-canonical | 10 | non-absolute canonical URL | HIGH | canonical; relative; absolute; HTTPS | subtle |
| img-no-alt | 23 | image missing alt | MEDIUM | alt; img; image | obvious |
| img-no-dimensions | 26 | image missing width/height | HIGH | width; height; CLS; dimensions | subtle |
| js-only-nav | 29 | JavaScript-only navigation | HIGH | onclick; href; anchor; navigation | subtle |

## Scope

These are the only intended issues. A finding matching none of these rows (by
keyword overlap near the cited line) counts as a false positive. Accessibility
or code-quality findings outside SEO scope, if reported, are false positives here.
