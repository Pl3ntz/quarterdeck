# Output Format — Structured Communication

## Concept

Most technical reports start with the result (e.g., "found 3 bugs"). Our format starts with the **impact** ("the system had a data loss risk"), then explains **how it was approached**, and ends with **what was found in concrete numbers**.

This allows the Captain to understand the importance before the technical detail — and decide without reading everything.

## Standard Format

All 26 agents use this structure:

```markdown
### FINDINGS (max 5, ordered by severity)
- **[CRITICAL|HIGH|MEDIUM|LOW]** [title] — `file:line` — [description + fix]

### NEXT STEP: [1-2 sentences — recommended action]

### SUMMARY: [2-3 fluid sentences: system impact → how it was analyzed → concrete result with numbers]
```

## Examples by Agent Type

### code-reviewer

```markdown
### FINDINGS
- **HIGH** SQL injection — `src/api/users.py:42` — Query uses string concatenation; use parameters
- **MEDIUM** Console.log in production — `src/utils/helper.ts:18` — Remove before merge

### NEXT STEP: Fix SQL injection before merge. Console.log can go in the next commit.

### SUMMARY: The users endpoint had a SQL injection risk that could expose sensitive data. Analyzed all endpoints in the auth module and verified query patterns. Found 1 HIGH vulnerability and 1 MEDIUM issue — both with suggested fixes.
```

### incident-responder

```markdown
### AFFECTED SERVICES
- backend — DOWN — since 14:30
- scheduler — DEGRADED — intermittent timeouts

### ROOT CAUSE: Connection pool exhausted — PostgreSQL reached max_connections (100)

### REMEDIATION OPTIONS
1. **Quick:** Increase max_connections to 200 + restart (~30s downtime)
2. **Complete:** Implement connection pooling with PgBouncer (2-3h, zero downtime after)

### NEXT STEP: Option 1 resolves immediately; option 2 prevents recurrence. Recommend option 1 now + plan option 2 for this week.

### SUMMARY: The backend went down affecting all users because the PostgreSQL connection pool was exhausted. Diagnosed via service logs and pg_stat_activity, confirming 100/100 active connections. 2 services affected, root cause identified, 2 remediation options with clear trade-offs.
```

### architect

```markdown
### DESIGN DECISION
**Chosen approach:** Service Layer Pattern (Route → Service → Repository)
**Why:** Separates business logic from routes, unit-testable

### ALTERNATIVES
| Option | Pros | Cons |
|--------|------|------|
| Service Layer | Testable, clear separation | More boilerplate |
| Fat Controllers | Simple, fewer files | Hard to test, coupled |
| CQRS | Scales read/write separately | Over-engineering for current scope |

### TRADE-OFFS: Service Layer adds ~20% more code but reduces debug time by 50%

### NEXT STEP: Implement Service Layer in the auth module as a pilot

### SUMMARY: The auth module mixes business logic with routes, making unit testing impossible. Evaluated 3 architectural patterns against project requirements and existing patterns. Service Layer is the best option: more testable, aligned with FastAPI patterns, cost of ~20% more code.
```

## Token Budget by Agent

| Agent Type | Max Tokens | Justification |
|---|---|---|
| build-error-resolver, doc-updater | 200 | Binary result: fixed or not |
| refactor-cleaner, e2e-runner | 300 | Item listing + result |
| code-reviewer, tdd-guide, ux-reviewer, staff-engineer, database-specialist, devops-specialist, performance-optimizer | 400-500 | Detailed findings with evidence |
| architect, planner | 600 | Design decisions with alternatives |
| deep-researcher | 800 | Multi-source synthesis with confidence |

## Principle Behind the Format

The SUMMARY follows the concept of structured communication: **impact before detail**. Instead of listing data and letting the reader interpret, the agent synthesizes in 2-3 sentences that naturally answer:

1. Why this matters (business/system impact)
2. How it was done (approach, tools, scope)
3. What was found (concrete numbers, result)

The Captain can read only the SUMMARY and already have enough context to decide. The FINDINGS section and the details above it serve for deeper investigation when needed.
