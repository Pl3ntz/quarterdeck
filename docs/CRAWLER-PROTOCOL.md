# Crawler Protocol — Wave-Based Parallelism

## Principle

**Parallel is the default. Sequential is the exception.**

Only go sequential when there's a real data dependency (agent A's output is agent B's input).

## Wave Execution Model

Instead of sequential chains, the PE groups work into **waves**. Within each wave, all agents run in parallel. Between waves, sequential.

```
Wave 1 (PARALLEL — reconnaissance):
  ├── Explore: codebase structure + existing patterns
  ├── Explore: test coverage + dependencies
  └── deep-researcher: external research (if needed)

Wave 2 (SEQUENTIAL — planning):
  └── planner or architect: plan based on Wave 1 results

Wave 3 (PARALLEL — implementation):
  ├── tdd-guide: tests + implementation (zone A)
  └── devops-specialist: CI/CD changes (zone B)

Wave 4 (PARALLEL — validation):
  ├── code-reviewer: code quality
  ├── security-reviewer: security audit
  └── ux-reviewer: UI review (if applicable)
```

## Zone Assignment — Conflict Prevention

**Before spawning parallel agents that WRITE code, the PE must:**

1. **Map file zones** — list which files each agent will touch
2. **Verify no overlap** — two agents cannot modify the same file in the same wave
3. **Assign zones in the prompt** — explicitly tell each agent which files it owns

```
Example zone assignment in agent prompt:
"Your zone: src/api/**, tests/api/**. Do NOT modify files outside your zone."
```

**Read-only agents (code-reviewer, security-reviewer, etc.) don't need zones** — they can read the same files in parallel without conflict.

### When to use `isolation: worktree`

If file overlap is **unavoidable**, use `isolation: worktree` in the agent frontmatter. Each agent gets an isolated copy of the repository via git worktree.

## Routing Tables

### Always Parallel (no dependencies)

| Trigger | Agents (PARALLEL) |
|---|---|
| Code/PR review | code-reviewer + security-reviewer + (ux-reviewer if UI) |
| Evaluate architecture | architect + staff-engineer |
| Project audit | security-reviewer + performance-optimizer + code-reviewer |
| Investigate issue | Explore (codebase) + deep-researcher (web) |
| Validate implementation | code-reviewer + security-reviewer + tdd-guide (run tests) |
| Multi-project analysis | 1 agent per project, all parallel |

### Wave-Based (parallel within waves, sequential between)

| Trigger | Wave 1 (parallel) | Wave 2 (sequential) | Wave 3 (parallel) |
|---|---|---|---|
| New feature | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| New API endpoint | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| Refactor | Explore (structure) + Explore (tests) | architect | refactor-cleaner + code-reviewer |
| Complex bug fix | Explore (code) + Explore (tests) | tdd-guide | code-reviewer |
| UI change | Explore + deep-researcher | planner | tdd-guide + ux-reviewer + code-reviewer |

## Execution Rules

1. **3-5 agents max per wave** — more creates coordination overhead
2. **Read-only agents always parallelize** — no conflict risk
3. **Write agents need zone assignment** — PE verifies overlap first
4. **Failed agent doesn't block others** — PE handles via Chain Failure Recovery
5. **PE is the only synthesizer** — agents never see each other's output
6. **Background agents for non-blocking work** — use `run_in_background: true`

## Fan-Out / Fan-In Pattern

```
1. PE decomposes the Captain's request into N independent sub-tasks
2. PE spawns N agents in parallel (fan-out)
   - Each agent gets: task description + zone assignment + output contract
3. PE collects all results
4. PE synthesizes into unified response (fan-in)
5. PE presents coherent analysis to the Captain
```
