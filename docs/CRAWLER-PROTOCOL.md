# Crawler Protocol — Parallel-First Wave Orchestration

**Back to:** [README](../README.md)

The **Crawler Protocol** is how the PE maximizes parallel execution. Instead of running agents sequentially, the PE groups work into **waves** — all independent tasks within a wave run simultaneously, then the next wave starts. This reduces multi-step projects from hours to minutes.

---

## Core Idea

```
Sequential (without Crawler):
  Agent A → Agent B → Agent C → Agent D
  (slow, but simple)

Parallel Waves (Crawler Protocol):
  Wave 1: Agent A + Agent B + Agent C (parallel)
  Wave 2: Agent D (after Wave 1 finishes)
  (faster, needs conflict prevention)
```

When you request "implement feature X", the PE automatically decomposes the work into independent waves. Agents in the same wave run at the same time. Agents in different waves run sequentially (because later waves depend on earlier results).

---

## Wave Execution Model

A typical project flow:

```
Wave 1 (PARALLEL — reconnaissance):
  ├── Explore agent: analyzes codebase structure + existing patterns
  ├── Explore agent: checks test coverage + dependencies
  └── deep-researcher: researches external libraries or best practices

Wave 2 (SEQUENTIAL — planning):
  └── planner or architect: creates implementation plan based on Wave 1 results
    
     → PE presents plan → You approve ✓

Wave 3 (PARALLEL — implementation):
  ├── tdd-guide: writes tests + code (owns src/api/**, tests/api/**)
  └── devops-specialist: updates CI/CD config (owns .github/workflows/**)

     → PE shows code → You review ✓

Wave 4 (PARALLEL — validation):
  ├── code-reviewer: checks code quality
  ├── security-reviewer: audits for vulnerabilities
  └── ux-reviewer: evaluates UI/UX (if applicable)

     → PE synthesizes findings
```

**Why this matters:** Waves 1 and 4 run 3 agents at the same time instead of one-after-another. That's **3× parallelism gain** with zero additional latency you perceive.

---

## Zone Assignment — Preventing Write Conflicts

When multiple agents **write code** in the same wave, they must not touch the same files. The PE prevents this with **zone assignment**.

### How it works

Before spawning parallel write-agents, the PE:

1. **Maps file zones** — lists which files each agent will modify
   ```
   tdd-guide zone:    src/api/**, tests/api/**
   devops-specialist: .github/workflows/**, Dockerfile
   ```

2. **Verifies no overlap** — ensures no two agents claim the same file
   - If overlap is unavoidable, use `isolation: worktree` (Git worktree for safe isolation)
   - If overlap cannot be solved, delay one agent to the next wave

3. **Declares zones in the prompt** — each agent knows its boundaries
   ```
   Your zone: src/api/**, tests/api/**
   Do NOT modify files outside your zone.
   ```

### Read-only agents don't need zones

Agents like **code-reviewer**, **security-reviewer**, and **ux-reviewer** only *read* code — they can all analyze the same files in parallel with zero conflict:

```
Wave 4 (all read-only, full parallelism):
  ├── code-reviewer: reads src/**, tests/**
  ├── security-reviewer: reads src/**, infra/**
  └── ux-reviewer: reads src/components/**, tests/e2e/**
```

All three operate simultaneously with no zone assignment needed.

---

## Fan-Out / Fan-In Pattern

The PE decomposes a single request into parallel work, then synthesizes results:

```
Owner request: "Implement feature X"
    ↓
PE decomposes:
    ├─ Task A: Explore code structure
    ├─ Task B: Explore test patterns
    └─ Task C: Research JWT best practices
    
PE fan-out (spawn 3 agents in parallel)
    ├─ Agent returns: findings + decisions
    ├─ Agent returns: findings + decisions
    └─ Agent returns: findings + decisions
    
PE fan-in (synthesizes):
    → single coherent plan
    
Owner gets one result instead of three.
```

This is critical: **agents never read each other's output.** The PE reads all three, synthesizes, and presents a single unified answer to you. This avoids duplication and conflict.

---

## Parallel Routing Table

### Always Parallel (no dependencies)

These agent combinations always run together — they read different things or are all read-only:

| Trigger | Agents (all at once) |
|---|---|
| Review code/PR | code-reviewer + security-reviewer + ux-reviewer |
| Evaluate architecture | architect + staff-engineer |
| Audit the entire project | security-reviewer + performance-optimizer + code-reviewer |
| Investigate an issue | Explore (codebase) + deep-researcher (web research) |

### Wave-Based Chains (parallel within waves, sequential between)

Complex projects decompose into multiple waves:

| Trigger | Wave 1 | Wave 2 | Wave 3 |
|---|---|---|---|
| **New feature** | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| **New API endpoint** | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| **Refactor** | Explore (structure) + Explore (tests) | architect | refactor-cleaner + code-reviewer |
| **Complex bug** | Explore (code) + Explore (tests) | tdd-guide | code-reviewer |

Each wave waits for the previous one to finish (because later work depends on earlier decisions).

---

## Parallel Execution Rules

1. **Hard cap: 5 agents max per wave**
   - Anthropic's published number; >5 agents show diminishing returns
   - At 10 agents, cost grows 15× while output quality drops
   - Prefer splitting into multiple waves instead of overloading one

2. **Read-only agents always parallelize**
   - No conflict risk — they don't modify files
   - Cost is negligible; benefit is immediate

3. **Write agents need zone assignment**
   - PE verifies no file overlap before spawning
   - If unavoidable overlap: use `isolation: worktree` or delay to next wave

4. **Failed agent does NOT block others**
   - If agent A fails in Wave 3, agents B and C continue
   - PE handles recovery separately (doesn't stop the whole wave)

5. **PE is the only synthesizer**
   - Agents do NOT see each other's output
   - PE collects results, deduplicates, synthesizes, and presents to you

6. **Background agents for non-blocking work**
   - Some tasks don't need immediate results
   - Use `run_in_background: true` to let PE continue while agents work

---

## Practical Example

**Your request:** "Implement JWT authentication with tests"

**PE decomposes:**

```
Wave 1 (reconnaissance):
  ├─ Explore: reads auth/ to see current structure
  │   Returns: "Found basic session auth, 60% test coverage"
  │
  ├─ Explore: reads tests/auth/ for patterns
  │   Returns: "Uses unittest, mocks DB, 8 test files"
  │
  └─ deep-researcher: researches JWT + Python best practices
      Returns: "PyJWT recommended, should use RS256, avoid HS256"
      
Wave 2 (planning):
  └─ planner: reads Wave 1 findings, creates plan
      Returns: "Phase 1: add PyJWT + RS256. Phase 2: tests. 
                Phase 3: migrate existing sessions. Risks: cache invalidation"

[PE shows plan → You approve]

Wave 3 (implementation):
  ├─ tdd-guide: (zone: auth/**, tests/auth/**)
  │   Returns: "Wrote 12 tests (RED), then implementation (GREEN), 92% coverage"
  │
  └─ devops-specialist: (zone: .github/workflows/*, docker/*)
      Returns: "Updated CI to test PyJWT, added JWT key rotation job"

Wave 4 (validation):
  ├─ code-reviewer: reads auth/** + tests/auth/**
  │   Returns: "Clean patterns, good test isolation, 2 minor style fixes"
  │
  └─ security-reviewer: audits JWT implementation
      Returns: "CRITICAL: RS256 key not rotated. MEDIUM: add rate limiting. 
                Otherwise secure."

[PE synthesizes: 1 CRITICAL, 1 MEDIUM, 2 MINOR → You fix → Done]
```

**Timeline:**
- Wave 1: 3 agents run at once → ~30s total (not 90s)
- Wave 2: 1 agent → 20s
- Wave 3: 2 agents run at once → ~40s total (not 80s)
- Wave 4: 2 agents run at once → ~30s total (not 60s)

**Total: ~2 min. Without Crawler (sequential): ~5.5 min.** 2.75× speedup.

---

## When NOT to Parallelize

The Crawler Protocol is aggressive about parallelism, but some tasks must be sequential:

| Situation | Why | Solution |
|---|---|---|
| Agent A's output determines Agent B's task | B depends on A | Sequential (next wave) |
| Both agents write to `src/core/utils.ts` | File conflict | One writes, other reviews, or use worktree |
| Agent A needs to test what Agent B wrote | A reads B's code | B finishes first, then A |
| Decision needed from you mid-execution | Can't proceed without approval | Pause for decision, then resume |

In these cases, the PE automatically places agents in sequential waves rather than the same wave.

---

## Output Format

Each agent in a parallel wave returns its findings in the **standard format:**

```markdown
### FINDINGS (ordered by severity)
- **[CRITICAL]** [issue] — `file:line` — [short fix]
- **[HIGH]** [issue] — [location] — [mitigation]

### NEXT STEP: [What PE should do with this finding]

### SUMMARY: [2-3 sentences: what was analyzed, result in numbers]
```

All agents use the same structure, making it easy for the PE to merge and synthesize.

---

## See Also

- [README](../README.md) — Overview of Quarterdeck
- [ARCHITECTURE.md](ARCHITECTURE.md) — How the PE orchestrates
- [OUTPUT-FORMAT.md](OUTPUT-FORMAT.md) — Standardized agent output
- [pe-reference.md](pe-reference.md) — Full PE orchestration rules
