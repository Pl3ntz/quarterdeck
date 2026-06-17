# Standardized Output Format

[← Back to README](../README.md)

Every Quarterdeck agent returns output in the same structured format: **FINDINGS** (ordered by severity) → **NEXT STEP** → **SUMMARY**. This standardization makes results predictable and composable.

## The Format Contract

Every agent output follows this template:

```markdown
### ACHADOS (or FINDINGS in English)
- **[CRITICAL|HIGH|MEDIUM|LOW]** [title] — `file:line` — [fix in 1 sentence]
- **[severity]** [title] — `file:line` — [fix in 1 sentence]

### PRÓXIMO PASSO (or NEXT STEP)
[1 sentence describing what the Owner should do next]

### SUMMARY
[System impact] → [How analyzed] → [Concrete result with numbers]
```

**Keys:**
- **ACHADOS** — All findings, ordered by severity (CRITICAL first)
- **PRÓXIMO PASSO** — Single actionable next step (what the Owner should do)
- **SUMMARY** — Always follows the pattern: impact → analysis method → concrete result with numbers
- **Tamanho** — ACHADOS ≤150 tokens; PRÓXIMO PASSO is 1 line; SUMMARY is 2-3 sentences
- Empty ACHADOS = no issues found; still include the section header

---

## The SUMMARY Logic

The SUMMARY always answers three questions:

| Question | Part | Example |
|---|---|---|
| **What matters?** | System impact | "The login endpoint has a SQL injection that could expose user passwords" |
| **How did you know?** | Analysis method | "Analyzed all 12 endpoints in the auth module for string concatenation patterns" |
| **What did you find?** | Concrete result with numbers | "Found 1 CRITICAL vulnerability and 2 MEDIUM issues with suggested fixes" |

**Result:** Reading just the SUMMARY, the Owner knows what was analyzed, what was found, and how serious it is.

---

## Examples by Agent Type

### Review Agents (Code, Security, UX)

**code-reviewer** analyzing a utility function:

```markdown
### ACHADOS
- **MEDIUM** Unused parameter `ctx` in `parse_csv()` — `lib/parsers.py:24` — Remove unused param
- **LOW** Missing type hint on return value — `lib/parsers.py:25` — Add `→ List[Dict]`

### PRÓXIMO PASSO: Update type hints and remove the unused parameter before merging.

### SUMMARY: The CSV parser has dead code (unused parameter) and incomplete type coverage. Reviewed all functions in the parsers module for type completeness and dead code. Found 1 MEDIUM issue and 1 LOW issue; both are low-risk fixes.
```

**security-reviewer** auditing an API endpoint:

```markdown
### ACHADOS
- **CRITICAL** SQL injection in users endpoint — `src/api/users.py:42` — Use parameterized queries instead of string concat
- **HIGH** Missing rate limiting on login endpoint — `src/api/auth.py:17` — Add Limiter decorator from fastapi-limiter

### PRÓXIMO PASSO: Fix the SQL injection immediately before any user data hits this endpoint.

### SUMMARY: The API has 2 injection risks in the authentication module that could expose user credentials. Analyzed all 8 endpoints in auth, user, and payment modules for injection patterns and rate limiting. Found 1 CRITICAL SQL injection and 1 HIGH missing rate limit; both have straightforward fixes.
```

**ux-reviewer** checking a form component:

```markdown
### ACHADOS
- **MEDIUM** Form submit button hidden on mobile (<600px) — `src/components/LoginForm.tsx:88` — Add `display: block` to mobile breakpoint
- **LOW** Missing error message color contrast on dark mode — `src/styles/form.css:142` — Increase text opacity from 60% to 75%

### PRÓXIMO PASSO: Verify the form is usable on iPhone 12 (375px viewport) before shipping.

### SUMMARY: The login form has a mobile usability issue (submit button hidden) and minor accessibility issue (color contrast in dark mode). Tested at 375px, 768px, and 1440px viewports against WCAG 2.1 AA. Found 1 MEDIUM mobile issue and 1 LOW accessibility issue; both are CSS-only fixes.
```

### Planning Agents (Architect, Planner)

**architect** evaluating design options:

```markdown
### PLANO: Event-Driven vs Request-Response for notifications

### ANÁLISE:
- **Event-Driven (Chosen):** Decouples notification service from payment flow. Scales well at 10k+ events/min. Harder to debug. Requires message queue (Redis/RabbitMQ).
- **Request-Response:** Simpler to reason about. Tight coupling means payment timeout blocks user. Dies at 5k req/sec.

### TRADE-OFF: Latency vs simplicity. Event-driven adds 50-200ms notification delay but unblocks payment UX and supports future payment methods.

### PRÓXIMO PASSO: Approve event-driven architecture; planner will create implementation phases.

### SUMMARY: Payment notifications need to scale to 10k events/min without blocking user checkout. Evaluated 2 patterns (request-response vs event-driven) against latency, scalability, and operational complexity. Recommends event-driven (unblocks UX, scales to 50k+/min, but adds 200ms delay and requires message queue).
```

**planner** creating an implementation roadmap:

```markdown
### PLANO: JWT Authentication
- **Objetivo:** Add JWT auth to replace session-based auth
- **Fases:**
  - Phase 1 (Week 1): Add JWT generation/validation (tdd-guide + database-specialist for refresh token schema)
  - Phase 2 (Week 2): Migrate 6 endpoints to JWT (tdd-guide)
  - Phase 3 (Week 3): Remove session endpoints + cleanup (refactor-cleaner + code-reviewer)
- **Riscos:** Concurrent session/JWT during rollout; mitigate with feature flag
- **Checkpoints:** After Phase 1 (approve schema); after Phase 2 (approve endpoint migration)

### PRÓXIMO PASSO: Approve Phase 1 plan; tdd-guide will start writing tests.

### SUMMARY: Adding JWT auth requires schema changes (refresh tokens) and 6 endpoint rewrites. Broke into 3 phases (schema → endpoint migration → cleanup) spanning 3 weeks. Identified 1 major risk (concurrent auth methods) with feature flag mitigation.
```

### Implementation Agents (tdd-guide, e2e-runner)

**tdd-guide** after implementing a feature:

```markdown
### ACHADOS
- ✓ 14 tests written (RED → GREEN → REFACTOR)
- ✓ 82% coverage (target 80%+)
- ✓ All edge cases covered (null input, empty array, boundary values)

### PRÓXIMO PASSO: Run code-reviewer to validate code quality and patterns.

### SUMMARY: Implemented JWT token generation with TDD. Wrote 14 tests covering generation, expiration, refresh, and revocation. Achieved 82% coverage. All tests passing (GREEN phase complete); ready for code review.
```

**e2e-runner** after testing a user flow:

```markdown
### ACHADOS
- ✓ Login → Dashboard → Create Item → Share flow passes (3 test runs, no flake)
- ⚠ Share modal takes 800ms to render (within 1s budget but close)
- ✗ SKIP: "Copy link" button in share modal (needs manual test — clipboard access in Playwright is limited)

### PRÓXIMO PASSO: Monitor share modal performance in staging; no code change needed yet.

### SUMMARY: End-to-end login and item sharing flow is stable. Ran user journey 3 times with no flakiness. One minor perf concern (800ms modal render) is within budget but should be monitored post-deploy.
```

### Research & Documentation Agents

**deep-researcher** comparing frameworks:

```markdown
### ACHADOS
- **Option A (FastAPI):** 45 GitHub stars/year, 300+ Reddit discussions, 7 production case studies found. Best for rapid API dev. Some projects report ORM pain at 100k+ req/sec.
- **Option B (Django):** 80+ case studies, mature ecosystem, but 2x startup overhead.

### PRÓXIMO PASSO: Choose based on team experience; both scale to your requirements (10k req/sec).

### SUMMARY: Compared 2 Python web frameworks against production usage, community size, and scalability. Analyzed 15 independent sources (GitHub stars, StackOverflow, production case studies, benchmarks from Databricks and others). FastAPI has faster iteration; Django has larger ecosystem. Both handle 10k req/sec.
```

**doc-updater** generating README from code:

```markdown
### ACHADOS
- ✓ Extracted 6 API endpoints from `src/routes/api.py`
- ✓ Updated setup instructions (Python 3.11+, added `uv` option)
- ✓ Generated codemaps for `/auth`, `/users`, `/admin`

### PRÓXIMO PASSO: Review the updated README and codemaps; merge if accurate.

### SUMMARY: Generated up-to-date README and codemaps from actual code. Found 3 areas requiring docs (auth, users, admin); all extracted and documented. Verified setup instructions work on Python 3.11 and 3.12.
```

---

## PE Synthesis Format (Multi-Agent Results)

When the PE presents results from multiple agents (e.g., code-reviewer + security-reviewer running in parallel), it uses the **fan-in format**:

```markdown
## Agent Results

| Agent | Finding | Key Point |
|---|---|---|
| code-reviewer | Unused parameter in `parse_csv()` | Dead code that should be removed |
| security-reviewer | SQL injection in users endpoint | Credential exposure risk |
| ux-reviewer | Submit button hidden on mobile | Mobile usability broken |

## Action Items (merged by severity)

1. **CRITICAL** SQL injection — security-reviewer — `src/api/users.py:42` — Use parameterized queries
2. **MEDIUM** Unused parameter — code-reviewer — `lib/parsers.py:24` — Remove unused param
3. **MEDIUM** Hidden button on mobile — ux-reviewer — `src/components/LoginForm.tsx:88` — Add mobile CSS

## Contradictions (if any)

None detected in this review.
```

**Keys:**
- Merge findings across agents **by severity, not by agent** — Owner sees CRITICAL items first
- Always surface contradictions explicitly (if agent A says X and agent B says Y, show both + evaluation)
- Max 300 tokens for synthesis
- Owner should be able to decide by reading just the action items table

---

## Output Rules

**What goes in ACHADOS:**
- Bugs, security issues, code smell, style violations
- Missing features, broken links, incomplete documentation
- Performance problems, accessibility failures
- Risks, architectural concerns, tech debt

**What does NOT go in ACHADOS:**
- Praise ("great code!", "looks good!") — owner doesn't need it
- Long explanations of _why_ something is wrong — that goes in PR comments, not the agent output
- Subjective opinions without evidence

**PRÓXIMO PASSO must be:**
- Single, concrete action the Owner should take
- Actionable in 1 step (not a list of substeps)
- Written as a command or question, not a summary

**SUMMARY must contain:**
- 1 number (count of issues, coverage %, etc.)
- 1 method (what was analyzed, how)
- 1 conclusion (what matters next)

---

## Token Budget by Agent Type

| Agent Type | Output Budget | Example |
|---|---|---|
| Review (code, security, UX) | ≤150 tokens | ACHADOS + PRÓXIMO + SUMMARY |
| Planning (architect, planner) | 500-800 tokens | Full plan with phases + SUMMARY |
| Implementation (tdd-guide, e2e-runner) | ≤200 tokens | Results + coverage/flake data + SUMMARY |
| Research (deep-researcher) | 800-1500 tokens | Comparison table + sources + SUMMARY |
| Documentation (doc-updater) | ≤150 tokens | What was generated + SUMMARY |

---

## Localization

All agents default to **pt-BR** for ACHADOS/PRÓXIMO PASSO/SUMMARY. The Owner's language (detected from their prompt) determines the language of the PE's synthesis and final presentation.

- Agent output: pt-BR
- PE synthesis: Owner's language (pt-BR or English)
- Code, file paths, technical terms: unchanged (stay in original language)

---

## See Also

- [AGENTS.md](AGENTS.md) — Full catalog of all 26 agents with detailed output examples
- [CRAWLER-PROTOCOL.md](CRAWLER-PROTOCOL.md) — How parallel agent execution works
- [rules/principal-engineer-always-on.md](../rules/principal-engineer-always-on.md) — Section 16 (PE Synthesis Protocol) for multi-agent fan-in logic
