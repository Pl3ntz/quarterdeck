# Quarterdeck Architecture

A command-and-control system for orchestrating 26 specialized AI agents in parallel.

See [README](../README.md) for overview.

---

## System Model

```
Owner (decision-maker)
    ↓ directs
Principal Engineer (PE)
    ↓ orchestrates
26 Agents (specialists execute)
```

**Absolute rule:** Agents NEVER act independently. The PE coordinates all work and presents results to the Owner, who decides.

### Roles

| Role | Who | Responsibility |
|------|-----|---|
| **Owner** | You — the person using Claude Code | Give requests, approve plans, make decisions |
| **PE** | Claude Code with Quarterdeck rules | Interpret requests, decompose into waves, coordinate parallel agents, synthesize results |
| **Agent** | 26 specialized `.md` files | Execute focused task, report findings, follow PE delegation |

---

## The 26 Agents Organized into 8 Squads

### 🔍 Planning & Design Squad

Design and architecture decisions before building.

| Agent | Model | Role |
|---|---|---|
| **architect** | Opus | HOW to build — patterns, trade-offs, alternatives |
| **planner** | Opus | IN WHAT ORDER to build — phases, risks, dependencies |

### 🛡️ Quality Gate Squad

Validate without modifying. ALWAYS runs in PARALLEL.

| Agent | Model | Role |
|---|---|---|
| **code-reviewer** | Sonnet | Code quality, bugs, patterns, maintainability |
| **security-reviewer** | Opus | Infrastructure security: SSH, firewall, SSL, credentials, hardening |
| **ux-reviewer** | Sonnet | Accessibility, visual consistency, interaction states |
| **staff-engineer** | Opus | Cross-system impact, tech debt, pattern propagation |

### 🔨 Implementation Squad

Write code. Requires zone assignment to prevent conflicts.

| Agent | Model | Role |
|---|---|---|
| **tdd-guide** | Sonnet | TDD: tests first, 80%+ coverage, unit + integration tests |
| **e2e-runner** | Sonnet | End-to-end tests with Playwright, user journeys |
| **build-error-resolver** | Haiku | Fix build errors with minimal diff |
| **refactor-cleaner** | Sonnet | Remove dead code, consolidate duplicates |

### ⚙️ Operations Squad

Keep the system running: deploy, monitor, optimize.

| Agent | Model | Role |
|---|---|---|
| **incident-responder** | Opus | Production diagnosis (read-only; recommends, doesn't execute) |
| **devops-specialist** | Sonnet | CI/CD, deploys, systemd, monitoring setup |
| **performance-optimizer** | Sonnet | CPU/memory/query bottlenecks, caching, tuning |
| **database-specialist** | Sonnet | PostgreSQL: schema, migrations, slow queries, indexes |

### 📚 Intelligence Squad

Research, documentation, knowledge capture.

| Agent | Model | Role |
|---|---|---|
| **deep-researcher** | Opus | Multi-source web research, triangulation, confidence scoring |
| **doc-updater** | Haiku | Generate documentation from actual code |

### ✍️ Language Squad

Text review (read-only). Single-language scope each.

| Agent | Model | Role |
|---|---|---|
| **ortografia-reviewer** | Sonnet | PT-BR: spelling, grammar, agreement, register |
| **grammar-reviewer** | Sonnet | EN-US: spelling, grammar, punctuation, style |

### 🎯 Strategy Squad

Specialized consulting.

| Agent | Model | Role |
|---|---|---|
| **seo-reviewer** | Sonnet | Technical SEO: Core Web Vitals, structured data, crawlability |
| **tech-recruiter** | Sonnet | Job descriptions, candidate evaluation, market validation |

### 📰 Editorial Squad

Professional content production with verified sources. Full pipeline: **pauta → apuração → redação → verificação → edição → revisão ortográfica**.

| Agent | Model | Role |
|---|---|---|
| **editor-chefe** | Opus | Direction: story angle, editorial line, approval |
| **jornalista** | Sonnet | Investigation, interviews, source triangulation |
| **redator** | Sonnet | Writing: lead, narrative, voice, rhythm |
| **escritor-tecnico** | Sonnet | Technical: IMRAD, Diataxis, ADRs, design docs |
| **fact-checker** | Opus | Verification (Rule of Two): 3+ source triangulation |
| **editor-de-texto** | Sonnet | Final editing: cuts, lead polish, legal language |

**Recommended pipeline:**
```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
```

---

## Request Lifecycle

```
You submit request
    ↓
PE triages complexity (Trivial / Médio / Complexo)
    ↓
[For Médio+] PE specifies scope, boundaries, success criteria
    ↓
Owner approves spec
    ↓
PE decomposes into WAVES (parallel task groups)
    ↓
Wave 1: Reconnaissance (parallel agents explore, research)
    ↓
Wave 2: Planning (sequential — one planner/architect, learns from Wave 1)
    ↓
Owner approves plan
    ↓
Wave 3: Implementation (parallel agents write code, zone-assigned)
    ↓
Wave 4: Validation (parallel agents review: code-reviewer, security, UX)
    ↓
PE synthesizes results, presents to Owner
    ↓
Owner sees structured findings, decides next action
```

### Wave-Based Execution

Instead of sequential chains, the PE groups work into **waves**:
- **Within a wave:** agents run in PARALLEL (no dependencies between them)
- **Between waves:** sequential (next wave depends on previous results)

Example for "Implement JWT authentication":

```
Wave 1 — Reconnaissance (3 agents PARALLEL):
  ├── Explore: current auth code
  ├── Explore: test coverage
  └── deep-researcher: JWT best practices

Wave 2 — Planning (1 agent SEQUENTIAL):
  └── planner: creates phased plan

     → PE presents plan to Owner for approval ✓

Wave 3 — Implementation (1 agent SEQUENTIAL):
  └── tdd-guide: tests-first implementation

     → PE shows code to Owner ✓

Wave 4 — Validation (2 agents PARALLEL):
  ├── code-reviewer: quality check
  └── security-reviewer: auth security
```

**Result:** What could be 4 sequential steps runs in 4 waves with internal parallelism.

---

## Built-In Workflows

The PE automatically selects workflow patterns based on your request:

| When you say | PE route | Agents involved |
|---|---|---|
| "Implement feature X" | new-feature | planner → tdd-guide → code-reviewer + security |
| "Fix the login bug" | bug-fix | tdd-guide → code-reviewer |
| "Refactor auth module" | refactor | architect → refactor-cleaner → code-reviewer |
| "System is down!" | incident | incident-responder (read-only triage) → devops |
| "Review PR #42" | review-pr | code-reviewer + security + ux (all parallel) |
| "Audit the project" | audit | security + performance + code-reviewer (all parallel) |

---

## Parallel Execution Rules

### Hard Constraints

1. **Max 5 agents per wave** — diminishing returns beyond this; cost explodes 15× per additional agent
2. **Read-only agents always parallelize** — no conflict risk (code-reviewer, security-reviewer, etc.)
3. **Write agents need zone assignment** — PE verifies no two agents modify same file in same wave
4. **PE is the only synthesizer** — agents don't see each other's output; PE collects and merges
5. **Failed agent doesn't block others** — PE handles via graceful degradation

### Zone Assignment (Conflict Prevention)

When parallel write-agents exist:

```
PE maps file zones:
  tdd-guide zone: src/auth/**, tests/auth/**
  devops zone:    .github/workflows/**, Dockerfile

PE verifies: no file overlap ✓

PE spawns both with explicit assignment:
  "Your zone: src/auth/**. Do NOT modify outside this zone."
```

### Fan-Out / Fan-In Pattern

For independent sub-tasks:

```
1. PE decomposes request into N independent tasks
2. PE spawns N agents in parallel (fan-out)
   - Each gets: description, zone, output contract
3. PE collects all results
4. PE synthesizes into unified answer (fan-in)
5. PE presents single coherent result to Owner
```

---

## Agent Context Protocol

Every agent receives a **context preamble** before acting:

```
---context---
project: [project name]
stack: [languages, frameworks, DB]
path: [local path or remote: ssh your-server]
services: [systemd services, if applicable]
state: [git status, service status]
scope: [files/areas involved]
constraints: [production gate, SSH-only, custom tooling, etc.]
---end-context---

## Objective
[1 sentence — what must be accomplished]

## Output format
[Expected structure: Markdown sections, key sections]

## Boundaries
[What is OUT of scope: files NOT to touch, decisions NOT to make]
```

This ensures agents understand project context and constraints before proposing changes.

---

## Output Format

All agents return in the same structured format:

```markdown
### FINDINGS (ordered by severity)
- **[CRITICAL]** SQL injection vulnerability in users endpoint
- **[HIGH]** Missing rate limiting on auth routes

### NEXT STEP
Fix the SQL injection before merging.

### SUMMARY
The users endpoint had a SQL injection risk from string concatenation.
Analyzed all endpoints in the auth module; verified query patterns.
Found 1 CRITICAL + 2 MEDIUM issues with suggested fixes.
```

Format: **FINDINGS + SEVERITY + NEXT STEP + SUMMARY**. Owner reads it once and knows what matters.

---

## Orchestration Principles

### 1. Triage First

PE classifies every request:

| Level | Scope | Gates | Example |
|---|---|---|---|
| **Trivial** | 1-2 tools, 1 file | None | typo fix, file read |
| **Médio** | 3-10 tools, 2-5 files | SPECIFY | bug fix, endpoint |
| **Complexo** | 10+ tools, 5+ files, multi-agent | SPECIFY + PLAN | new feature, refactor |

### 2. Specification Discipline

For Médio and Complexo requests, PE writes a spec:

```
### SPEC: [title]
- **O que**: precise description
- **Por que**: problem solved / value added
- **Escopo**: affected files/areas
- **Fora de escopo**: what won't be done
- **Critério de sucesso**: how to verify
- **Complexidade**: level classification
```

Owner confirms spec before proceeding.

### 3. Debate Before Consensus

The PE (and agents) are **advisors**, not executors:
- Challenge suspicious requests
- Propose alternatives with trade-offs
- Reference historical context and decisions
- Never auto-resolve ambiguities
- Owner owns all final decisions

### 4. Zero Assumption Protocol

All agents (and PE) follow strict verification:

**Phase 1:** Extract business rule FIRST
- What does the system do? Why does it do it?
- What are the invariants/policies?

**Phase 2:** Validate against actual code
- Read full files, not snippets
- Map conventions and patterns
- Verify schema, not guess
- Check live state (DB, services, configs)

**Phase 3:** Cross-reference
- Rule (Phase 1) must match code (Phase 2)
- If divergence → report it, never fix silently
- Divergence means bug, debt, or outdated rule

---

## Sketch: Typical New-Feature Flow

```
Owner: "Add two-factor authentication"

PE: (Triage) → Complexo
    → Interview Owner (dependencies? existing code? deadline?)
    → Write spec, present to Owner

Owner: "Approved"

PE: (Plan Wave)
    → Spawn planner + deep-researcher (parallel)
    → planner reads existing auth code, creates 3-phase plan
    → deep-researcher gathers 2FA best practices
    → PE presents merged plan to Owner

Owner: "Looks good"

PE: (Implementation Wave)
    → Spawn tdd-guide (zone: auth/, models/)
    → tdd-guide writes failing tests, implements features
    → Minimal incremental commits

PE: (Validation Wave)
    → Spawn code-reviewer + security-reviewer (parallel)
    → Both review implementation
    → security-reviewer checks for TOTP timing attacks, backup codes, etc.

PE: (Synthesis)
    → Merges findings by severity
    → "CRITICAL: no rate-limit on 2FA endpoint"
    → "HIGH: backup codes not rotatable"
    → Presents to Owner with NEXT STEP

Owner: (Decides)
    → Approve merging after fixes
    OR ask for changes
    OR escalate to incident-responder
```

---

## Model Selection Strategy

Quarterdeck distributes models by task complexity (cost optimization):

| Agent | Model | Why |
|---|---|---|
| architect, planner, deep-researcher, security-reviewer, incident-responder, editor-chefe, fact-checker | **Opus** | Deep reasoning, complex decisions, high-stakes review |
| code-reviewer, tdd-guide, e2e-runner, refactor-cleaner, ux-reviewer, devops, database, + others | **Sonnet** | Best cost/quality balance; 79.6% SWE-bench (near-Opus) |
| build-error-resolver, doc-updater | **Haiku** | Simple, scoped tasks; 5× cheaper |

Total: ~15% Opus, ~75% Sonnet, ~10% Haiku. Optimizes cost while preserving quality where it matters.

---

## Customization

Agents are generic but customizable. Edit frontmatter in any `.md` file:

```yaml
model: opus          # Change reasoning depth
tools: Read, Grep    # Limit available tools
```

See [CUSTOMIZATION.md](CUSTOMIZATION.md) for full guide.

---

## See Also

- [AGENTS.md](AGENTS.md) — Full catalog with tools and examples
- [CRAWLER-PROTOCOL.md](CRAWLER-PROTOCOL.md) — Wave execution in depth
- [OUTPUT-FORMAT.md](OUTPUT-FORMAT.md) — Agent output examples
- [../rules/principal-engineer-always-on.md](../rules/principal-engineer-always-on.md) — Complete PE orchestration rules
