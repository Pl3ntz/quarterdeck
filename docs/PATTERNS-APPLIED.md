# Patterns & Conceptual Frameworks

**Last Updated:** 2026-06-17 | [← Back to README](../README.md)

This document explains the three core orchestration patterns and quality frameworks that power Quarterdeck's multi-agent coordination and continuous-learning capabilities.

---

## Table of Contents

1. [Improvement Maturity Levels](#improvement-maturity-levels) — Self-assessment scale for learning systems
2. [Promotion Criteria Matrix](#promotion-criteria-matrix) — Thresholds before patterns graduate to rules
3. [Skill Chain Pattern](#skill-chain-pattern) — Pure pipelines vs PE-in-the-loop chains
4. [Agent Orchestration Patterns](#agent-orchestration-patterns) — Parallel vs single-agent decision trees

---

## Improvement Maturity Levels

A **five-level scale** (0–5) to assess the maturity of any continuous-learning behavior within the PE or agent system. Use this when proposing changes to memory, error handling, or pattern promotion.

| Level | Name | Mechanism | Characteristics |
|-------|------|-----------|---|
| **0** | Stateless | No memory between sessions | Each session starts from zero; no learning accumulates |
| **1** | Recording | Captures observations into memory hooks | Data captured but not organized or acted upon |
| **2** | Curating | Organizes and deduplicates observations | Memory health checks run; duplicates removed; patterns extracted |
| **3** | Promoting | Graduates validated patterns to enforced rules | `rule_promoter.py` converts candidates to permanent code (CLAUDE.md, rules) |
| **4** | Extracting | Creates reusable skills from proven patterns | Best practices become standalone skills in `~/.claude/skills/` |
| **5** | Meta-Learning | Adapts the learning strategy itself | System evaluates and improves its own detection/promotion logic |

### When to Use This Scale

- **Proposing a memory feature?** State current level and target level.
- **Current system at Level 2?** Moving to Level 3 requires formal promotion criteria (see below).
- **Targeting efficiency gains?** Focus on Level 3+ — moving the needle is more valuable than recording (Level 1).

### Example Trajectory

A pattern starts at **Level 1** (recorded in session memory):
- Observed: "Query with no LIMIT always times out"
- Captured: `memory_entry = {pattern: "query-no-limit", incident: "2026-06-05"}`

After **3 sessions** with the same incident (Level 2):
- Memory curator deduplicates: "This happens every time someone forgets LIMIT"
- Extracted rule candidate: "Always validate LIMIT in SQL queries"

When it passes **Promotion Criteria** (Level 3):
- `rule_promoter.py` creates permanent rule in `~/.claude/rules/sql-baseline.md`
- All future PE sessions load this rule automatically

If later extracted as **reusable skill** (Level 4):
- New skill: `skill-sql-validator` runs pre-commit checks

---

## Promotion Criteria Matrix

Before any memory entry graduates from `MEMORY.md` to a permanent rule (in `CLAUDE.md` or `~/.claude/rules/`), it **MUST satisfy ALL FIVE criteria below**. This prevents memory pollution and ensures rules are durable.

| Criterion | Threshold | How to verify | Example |
|-----------|-----------|---------------|---------|
| **Recurrence** | Seen in 3+ distinct sessions | Check memory entry's recurrence counter | Pattern repeats in sessions #5, #12, #18 |
| **Consistency** | Same solution every time | No contradicting entries exist | Fix is identical across all 3 incidents |
| **Impact** | Prevented ≥1 error or saved meaningful time | Reference concrete incident in memory | "Saved 45min in session #18" |
| **Stability** | Underlying code/system hasn't changed | Tool/file/dependency still exists today | File `src/db/query.py` still exists; schema unchanged |
| **Clarity** | Statable in 1–2 sentences | Rule body ≤ 200 chars (enforced by sanitizer) | "Always add LIMIT 1000 to read queries" |

### Promotion Workflow

1. **Record** (Session N): Pattern observed, captured in memory
2. **Curate** (Session N+M): `memory_health_checker.py` detects recurrence
3. **Review** (Manual): Owner reviews candidate via `rule_promoter.py --list-candidates`
4. **Promote** (Manual): Owner creates PR with new rule in `~/.claude/rules/`
5. **Enforce** (All future sessions): Rule loads automatically in PE

### Anti-Pattern: Auto-Promotion

**Forbidden.** Even if all 5 criteria are met, auto-promotion is a memory-poisoning defense. The **Owner explicitly approves all rule changes** via git commit.

### Sanitizer Rules (in `rule_promoter.py`)

Rejected patterns:
- Contain shell metacharacters (`;`, `|`, `>`, backticks)
- Contain prompt-injection markers (`<system-reminder>`, `<command-name>`)
- Reference localhost/private IPs or internal aliases
- Non-HTTPS URLs (except GitHub, Anthropic, AWS official docs)
- Paths containing personal home directories

---

## Skill Chain Pattern

**Pure pipelines without PE judgment between steps.** Distinct from Workflow Chains (which keep the PE in the loop).

### When to Use

Repeatable automation where **consistency matters more than discretion**:
- CI/CD-like flows (deploy → test → verify → rollback)
- Batch processing (detect errors → categorize → dedupe → report)
- Chained analysis (memory check → extract patterns → rank candidates)

**When NOT to use:**
- Anything requiring human decision-making between steps
- Exploratory tasks needing PE adjustment mid-stream
- Chains longer than 6 steps (exponential debug complexity)

### Core Rules

1. **No PE between steps** — Direct skill-to-skill data flow via files or stdout
2. **Declare I/O format** — Each skill declares input type (JSON / Markdown / text) and output type
3. **Fail-fast** — If a skill produces invalid output, the chain aborts immediately
4. **Idempotent** — Running the chain twice on identical input produces identical output
5. **Observable** — Log each step's input/output for debugging

### Example: Memory Health Pipeline

```
Step 1: memory_health_checker.py
  Input:  MEMORY.md (Markdown)
  Output: candidates.json (JSON list of stale/duplicate/promotable entries)

Step 2: rule_promoter.py --list-candidates
  Input:  candidates.json
  Output: review-ready.md (formatted candidates for Owner review)

Step 3: [Owner reviews manually]
  Input:  review-ready.md
  Output: PR comment / git commit

[No PE between any of these steps — pure execution]
```

### Example: Error Index Update

```
detect-errors → categorize → dedupe → write-index

No PE decision-making. If detect-errors finds a pattern in 10 files,
categorize applies the same taxonomy to all 10. No judgment needed.
```

### Anti-Patterns to Avoid

| Anti-Pattern | Why it fails | Solution |
|---|---|---|
| Adding PE between steps | Kills the "pure automation" benefit | Use Workflow Chains instead |
| Chains >6 steps | Debugging gets exponential | Break into 2 separate chains |
| Skills mutate input in place | Breaks traceability and idempotency | Always produce new output |
| Missing error handling between steps | Silent failures corrupt downstream | Each step validates output schema |

### Comparison: Skill Chain vs Workflow Chain

| Aspect | Skill Chain | Workflow Chain |
|--------|------------|---|
| PE between steps | None | Yes, at every step |
| Decision-making | None | At every PE gate |
| Speed | Fast (parallel within skill) | Slower (PE overhead) |
| Use case | Batch, repeatable, deterministic | Exploratory, complex, needs judgment |
| Example | `detect → categorize → dedupe` | `planner → tdd-guide → code-reviewer` |

For chains that DO need PE judgment, use Workflow Chains (Section 8) or the Crawler Protocol (Section 15).

---

## Agent Orchestration Patterns

When should the PE spawn **multiple agents in parallel** vs. **a single agent with extended thinking**? This section documents the empirical decision tree (based on Anthropic research, 2026).

### The SOTA Decision Matrix

Empirical evidence shows clear winners and anti-patterns:

| Task Type | Use Parallel Multi-Agent | Use Single Opus + Extended Thinking |
|---|---|---|
| **Judging / Review** (code-review, security-audit, fact-check) | ✅ **Wins** — heterogeneous critics catch different failure modes | ❌ Underused |
| **Breadth-first research** (multi-source comparison, OSINT, landscape mapping) | ✅ **Wins at 15× cost** — only when value justifies | ❌ Misses sources |
| **Solution-finding** (design API, plan refactor, architect choice) | ❌ **ANTI-PATTERN** — agents read same files, produce overlapping output | ✅ **Wins at equal budget** |
| **Red team vs blue team debate** (same artifact, adversarial framing) | ❌ **ANTI-PATTERN** unless heterogeneous models (Opus vs Sonnet) | ✅ Opus alone with adversarial prompt |

### Default Rule

**If all agents in a wave would:**
- Read the **same files**
- Produce the **same type of findings** (e.g., "is this good code?")

→ **You have an anti-pattern.** Either:
1. Specialize their angles (different zones, different depths), OR
2. Collapse to a single agent

### Parallel Execution Patterns

#### Pattern 1: Quality Gate (Always Parallel)

**All read-only reviewers analyze the same code:**

```
Wave 4: Validate Implementation (PARALLEL)
├── code-reviewer:      "Is this well-written?"
├── security-reviewer:  "Are we exposing secrets?"
└── ux-reviewer:        "Is the UI accessible?"
```

**Why it works:** Each agent brings a different lens. One might miss a SQL injection that another catches.

**Cost:** 3 agents × token budget. But the marginal value is high — each catches failures the others miss.

#### Pattern 2: Fan-Out with Zone Assignment (Parallelizable)

**Multiple write agents modify disjoint file zones:**

```
Wave 3: Implementation (PARALLEL with zone assignment)
├── tdd-guide:            Zone: src/auth/** + tests/auth/**
└── devops-specialist:    Zone: infra/**, .github/workflows/**
```

**Rule:** No file overlap between zones. PE verifies before spawning.

**Why it works:** Independent work. No conflicts. Can run simultaneously.

#### Pattern 3: Wave-Based Orchestration

Sequential waves, parallel within each:

```
Wave 1 (PARALLEL): Reconnaissance
  ├── Explore: codebase structure
  ├── Explore: test coverage
  └── deep-researcher: external context

Wave 2 (SEQUENTIAL): Planning
  └── planner: synthesizes Wave 1 results

  → PE shows plan → Owner approves ✓

Wave 3 (PARALLEL): Implementation
  ├── tdd-guide: core feature (zone A)
  └── devops-specialist: CI setup (zone B)

Wave 4 (PARALLEL): Validation
  ├── code-reviewer: code quality
  └── security-reviewer: security audit
```

**Why:** Waves are sequential because Wave 2 depends on Wave 1 output. But within each wave, all agents run simultaneously.

### Hard Cap: 5 Agents Max Per Wave

Anthropic's published guidance:
- **≤5 agents:** Cost-effective, diminishing returns start to appear
- **>5 agents:** 15× cost vs single-agent with vastly diminishing marginal value
- **>8 agents:** Coordination overhead exceeds throughput gains

### Routing Table: When to Use Which Pattern

| Request | Pattern | Agents | Notes |
|---------|---------|--------|-------|
| Review code PR | Quality Gate (parallel) | code-reviewer + security-reviewer + ux-reviewer (if UI) | Heterogeneous critics |
| Implement feature | Wave-based | Explore (W1) → planner (W2) → tdd-guide (W3) → reviewers (W4) | Each wave depends on previous |
| Refactor module | Fan-out with zones | architect (plan) + refactor-cleaner (zone A) + code-reviewer (read-only) | Minimize overlap |
| Investigate issue | Always parallel | Explore (codebase) + deep-researcher (web) | Completely independent |
| Deploy hotfix | Sequential | incident-responder → devops-specialist | Must diagnose before deploying |

---

## Practical Guidance

### Start Here

New to Quarterdeck? Focus on these three patterns first:

1. **Quality Gate pattern** — Run code-reviewer + security-reviewer in parallel on every PR. This catches the most bugs.
2. **Wave-based orchestration** — Use for feature implementation. Reconnaissance → Planning → Implementation → Validation.
3. **Skill Chain pattern** — For routine tasks (memory cleanup, documentation generation), use pure chains to save time.

### Anti-Patterns to Avoid

| Anti-Pattern | Example | Fix |
|---|---|---|
| Multiple agents for solution-finding | "architect + staff-engineer both design the API" | Use single architect with adversarial framing |
| Chains >6 steps | memory_health → extract → validate → promote → notif → persist → cleanup | Break into 2 chains |
| Zone overlap in parallel writes | Both tdd-guide and refactor-cleaner modifying src/api/auth.py | Assign disjoint zones; use worktree if unavoidable |
| Verbose preambles | 4000-token context bloat for each agent | Keep ≤800 tokens; reference CLAUDE.md instead |
| agent-recall on every spawn | Calling memory on all 26 agents | Only use for Quality Gate squad; optional for Planning squad |

### Decision Checklist

Before spawning agents, ask:

- [ ] **Is this pattern documented** in the matrix above? If yes, follow it.
- [ ] **Are all agents writing code?** If yes, assign zones and verify no overlap.
- [ ] **Are all agents reading the same files** and doing the same analysis? If yes, collapse to single agent.
- [ ] **Is there a data dependency** between agents? If yes, use sequential waves.
- [ ] **Are agents independent?** If yes, spawn in parallel.

---

## References

- [Principal Engineer Rule (Sections 17–19)](../rules/principal-engineer-always-on.md) — Full specifications
- [Continuous Learning System](CONTINUOUS-LEARNING.md) — Detailed memory and promotion workflows
- [Crawler Protocol](CRAWLER-PROTOCOL.md) — Wave-based execution model
- Anthropic research: Multi-agent efficiency, arXiv 2604.02460, 2502.08788; ICLR 2025 MAD paper
