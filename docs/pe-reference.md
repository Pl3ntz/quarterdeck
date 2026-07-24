# PE Reference: Lazy-loaded Protocols

> **This file is NOT auto-loaded.** It's read on-demand by the PE via the Read tool
> when a workflow requires one of these protocols. Keeps the always-on rules leaner.
> See `principal-engineer-always-on.md` (core) for routing to these sections.

---

## 7. Agent Handoff Protocol

In multi-agent chains, synthesize a handoff block after each agent completes:

```
---handoff---
from: [previous agent]
to: [next agent]
decisions:
  - [max 5 decisions made]
files_modified:
  - [max 10 files, 1 line each]
blockers:
  - [max 3 unresolved issues]
next_action: [clear instruction for receiving agent]
---end-handoff---
```

Rules:
- Max ~500 tokens per handoff
- Do NOT pass persona/instructions from previous agent
- Receiving agent gets: its own profile + handoff block only
- In chains of 3+ agents, pass ONLY the latest handoff (do not accumulate)

### Context Summarization (BMAD cherry-pick, 2026-04-06)

In chains of **4+ agents**, the PE MUST maintain a cumulative summary to prevent context loss:

```
---context-summary---
goal: [Owner's original goal in 1 sentence]
agents_completed: [list of agents that already ran]
key_decisions: [max 5 decisions made so far]
open_issues: [max 3 unresolved questions]
total_files_modified: [count]
---end-context-summary---
```

Rules:
- **Create** the context-summary after the 3rd agent completes
- **Update** after each subsequent agent (append decisions, update issues)
- **Max 400 tokens**, forcing conciseness
- **Include** it in the next agent's prompt ALONGSIDE the handoff block
- **Does not replace** the handoff, it's complementary (handoff = last step, summary = overview)

## 8. Standard Workflow Chains

Named chains the PE can reference. Each step uses the handoff protocol (section 7). Owner can skip steps or alter order.

**CHAIN: new-feature** (trigger: "implement X", "new feature")
1. Wave 1: planner → plan with phases and risks
2. [Owner approves plan]
3. Wave 2: tdd-guide → tests first, then implementation
4. [Owner reviews implementation]
5. Wave 3 (PARALLEL): code-reviewer + security-reviewer (if API)

**CHAIN: fix-bug** (trigger: "fix bug", "broken", "regression")
1. Wave 1: tdd-guide → test that reproduces the bug, then fixes it
2. Wave 2: code-reviewer → verifies the fix

**CHAIN: refactor** (trigger: "refactor", "cleanup", "restructure")
1. Wave 1: architect → analyzes current structure, proposes target
2. [Owner approves target]
3. Wave 2: refactor-cleaner → executes
4. Wave 3: code-reviewer → verifies

**CHAIN: incident** (trigger: "production down", "errors", "urgent")
1. incident-responder → diagnoses (skip approval for read-only)
2. [Owner approves fix]
3. devops-specialist → deploys fix (production gate applies if relevant)


## 10. Request-Completion Protocol

The PE MUST verify that the Owner's request was fully addressed before stopping.

### Step 1: Capture the Original Request (Session Start)

On the FIRST substantive interaction of every session:
1. Use TaskCreate to create a task with subject: `Owner-REQUEST: <concise summary of what the Owner asked>`
2. Include the key requirements and success criteria in the task description
3. This task is NEVER marked as completed during the session, it serves as a permanent reference anchor
4. If the Owner's request evolves mid-session, create a new `Owner-REQUEST-UPDATE: <updated requirements>` task

### Step 2: Pre-Completion RECAP (Before Stopping)

Before presenting the final answer to the Owner on non-trivial work, include a RECAP:

```
### RECAP: [2-3 flowing sentences explaining: the impact on the system/business, then how it was addressed, then what was delivered with concrete numbers]
```

### Step 3: Simple Task Exception

For trivial interactions (quick questions, typo fixes, conversation):
- Skip the TaskCreate anchor
- Skip the RECAP
- A brief confirmation is sufficient

**Threshold**: If the Owner's request requires 3+ tool calls or touches multiple files/topics, it's NOT trivial, apply the RECAP.

### Compression Safety

The TaskCreate Owner-REQUEST task survives context compression. If you lose track of what was requested, TaskGet/TaskList will restore it. This rules file also survives compression and will remind you of this protocol.

## 11. Chain Failure Recovery Protocol

When an agent fails or produces inadequate output during a multi-agent chain, the PE MUST follow this protocol instead of restarting from scratch.

### Failure Classification

| Type | Example | Action |
|---|---|---|
| **Transient** | Agent hit context limit, timeout, unclear output | Retry ONCE with simplified scope |
| **Output quality** | Agent delivered incomplete or incorrect work | Retry with more specific instructions |
| **Fundamental** | Agent cannot solve this (wrong specialist, missing info) | Escalate: swap agent or ask Owner |

### Recovery Steps

1. **Detect**: If agent output is missing, malformed, or clearly wrong, do NOT pass it downstream
2. **Classify**: Determine failure type (transient / quality / fundamental)
3. **Retry** (max 2 retries per step):
   - Re-spawn the SAME agent with refined instructions and specific feedback about what was wrong
   - If 2nd retry fails, try a **fallback agent** (see table below)
4. **Escalate**: If fallback also fails, report to Owner with:
   - What was attempted
   - What failed and why
   - What options remain

### Fallback Agent Table

| Primary Agent | Fallback | When to Swap |
|---|---|---|
| code-reviewer (sonnet) | architect (opus) | Complex architectural issues beyond code-level review |
| tdd-guide (sonnet) | planner (opus) | Test strategy unclear, needs higher-level planning |
| build-error-resolver (haiku) | code-reviewer (sonnet) | Error is not a simple build issue but a logic problem |
| database-specialist (sonnet) | architect (opus) | Schema issue is actually an architecture problem |
| deep-researcher (opus) | PE WebSearch | Query was simpler than expected, direct search suffices |

### Output Validation Before Handoff

Before passing agent output to the next agent in a chain, the PE MUST verify:
- [ ] Output is not empty or error-only
- [ ] Output addresses the task described in the handoff
- [ ] Output format is usable by the receiving agent
- [ ] No obvious errors or contradictions in the output

If validation fails, trigger retry protocol, do NOT pass bad output downstream.

### Chain Checkpoint

After each successful agent step in a multi-agent chain:
1. Record the step result in a TaskCreate/TaskUpdate (survives compression)
2. If the chain needs to restart later, resume from the last successful checkpoint, not from the beginning

## 12. Evaluator-Optimizer Protocol (Maker-Checker)

For chains where quality matters (code changes, security, architecture), the PE applies a formal maker-checker loop.

### How It Works

```
Maker Agent → Output → PE validates → {PASS: proceed to next step, FAIL: feedback → Maker (retry)}
```

### Acceptance Criteria by Chain Type

| Chain | Maker | Checker | Acceptance Criteria |
|---|---|---|---|
| new-feature | tdd-guide | code-reviewer | Tests pass, no CRITICAL/HIGH issues, follows existing patterns |
| new API endpoint | tdd-guide | code-reviewer + security-reviewer | Above + no auth bypass, input validated, rate-limited |
| refactor | refactor-cleaner | code-reviewer | No behavior change, no dead code introduced, tests still pass |
| fix-bug | tdd-guide | code-reviewer | Regression test exists, fix addresses root cause |

### Retry Rules

1. **Max 2 retries** per maker-checker step
2. Feedback MUST be specific and actionable: "Missing error handling in function X at line Y" not "Code quality issues"
3. If maker fails after 2 retries, PE escalates to Owner with:
   - What was attempted
   - What feedback was given
   - Why it wasn't resolved
4. Owner decides: accept as-is, try different approach, or abandon

### Review Loopback (BMAD cherry-pick, 2026-04-06)

When the checker (code-reviewer) finds a CRITICAL finding, the PE MUST classify the root cause:

| Root cause | PE action |
|---|---|
| **bad_code**, implementation error, code does not follow the spec | Normal retry: feedback → maker (tdd-guide) fixes it |
| **bad_spec**, error in the plan/spec, the implementation followed the spec but the spec was wrong | **Automatic loopback**: PE goes back to planner/architect with the finding, without waiting for the Owner. Produces a corrected spec, then resumes implementation |
| **intent_gap**, the Owner's original request was ambiguous and produced an incomplete spec | **Escalate to Owner**: PE presents the gap and asks for clarification before continuing |

**Rule:** Loopback for bad_spec is AUTOMATIC (PE decides without asking the Owner). Loopback for intent_gap ALWAYS requires Owner approval.

### Quality Tracking

After each maker-checker cycle, the PE records the outcome:
- **PASS on 1st attempt**: Agent is performing well
- **PASS on retry**: Note what needed correction, a potential improvement area
- **FAIL after retries**: Flag for Owner, may need prompt refinement or a different agent

## 13. Self-Improvement Protocol (Tip Extraction)

The PE SHOULD extract reusable tips from sessions and store them in memory for future use.

### When to Extract Tips

At the end of substantial sessions (not simple Q&A), identify:

1. **Strategy tips**, patterns from successful executions:
   - "Searching for existing utilities before writing new ones saved 40% implementation time"
   - "Running code-reviewer + security-reviewer in parallel instead of sequential reduced review time"

2. **Recovery tips**, lessons from failures that were corrected:
   - "When tdd-guide fails because test framework isn't configured, check package.json first"
   - "Deep-researcher OSINT queries on .gov.br domains need PT-BR search queries"

3. **Optimization tips**, efficiency improvements discovered:
   - "For FastAPI projects, architect is overkill for simple endpoint additions, planner suffices"
   - "Using haiku model for doc-updater produces equivalent quality at 5x lower cost"

### How to Store Tips

Use the auto memory system. Write tips to topic-specific files in `~/.claude/projects/*/memory/`:

```
File: tips-agents.md    - Tips about agent selection and orchestration
File: tips-debugging.md - Tips about debugging patterns
File: tips-[topic].md   - Tips about specific domains
```

Each tip should include:
- **What**: The tip itself (1-2 sentences)
- **Why**: What happened that led to this learning
- **When**: In what context this tip applies

### Tip Quality Rules

- Only extract tips that are **generalizable** (not one-time situational fixes)
- **Deduplicate**: Check existing tips before adding, don't repeat what's already stored
- **Prune**: If a tip is contradicted by newer experience, update or remove it
- **Max 10 tips per topic file**, forcing prioritization of the most valuable learnings

## 14. Auto-Learning Protocol (Error Memory)

The PE has a persistent error memory system. A PostToolUse hook on Bash automatically detects command errors and logs them to `~/.claude/logs/error-events.jsonl`. The PE is responsible for the intelligent layers: fix capture, index maintenance, and consultation.

### Error Detection (Automatic, Hook)

The `detect-errors.sh` hook runs on every Bash tool call and detects strong error patterns (Traceback, ModuleNotFoundError, command not found, Permission denied, etc.). It silently logs to `error-events.jsonl` with: timestamp, command, matched pattern, category, error snippet.

Categories: `config`, `syntax`, `dependency`, `permission`, `connection`, `file`, `type`, `memory`, `logic`, `tooling`.

The PE does NOT need to trigger detection, it happens mechanically.

### Fix Capture (PE Responsibility)

When the PE fixes an error (any tool, Bash, Edit, Write), it MUST log the resolution:

1. Append to `~/.claude/logs/error-resolutions.jsonl`:
```json
{
  "timestamp": "2026-03-15T14:35:00Z",
  "original_error_timestamp": "2026-03-15T14:30:00Z",
  "category": "dependency",
  "summary": "neo4j driver not installed in container",
  "fix": "Added neo4j to requirements.txt and rebuilt container",
  "reusable": true,
  "tags": ["python", "neo4j", "docker"]
}
```

2. If `reusable: true`, update `~/.claude/logs/error-index.md` under the appropriate category:
```markdown
## dependency

1. **neo4j driver not installed**: When `ModuleNotFoundError: neo4j`, add `neo4j` to requirements.txt and rebuild container. [2026-03-15]
```

**When to capture**: After successfully resolving any error, a command that previously failed now works, an Edit that was corrected, a Write that needed adjustment.

**When NOT to capture**: One-time typos, trivial path mistakes, external service timeouts (not our problem).

### Edit/Write Error Capture (Manual, No Hook)

The PostToolUse hook only covers Bash. For Edit and Write tool failures (file not found, old_string not unique, permission denied), the PE MUST manually log them using the same resolution format above.

These failures are visible to the PE in the tool response. When the PE sees an Edit/Write error and fixes it, log it if the pattern is reusable.

### Index Consultation (Before Retry)

**MANDATORY**: Before retrying a failed operation or attempting something that previously failed:

1. Read `~/.claude/logs/error-index.md`
2. Check the relevant category for similar past errors
3. If a match exists, apply the documented fix instead of a blind retry
4. If no match, proceed normally, but if the retry succeeds, consider logging the fix

**When to consult**: Only on error paths. Do NOT read the index on every tool call, only when a tool fails or when attempting an operation known to be error-prone.

### Index Maintenance

The `error-index.md` is organized by category with max **10 entries per category**.

**Adding entries**: After resolving a reusable error, add it under the correct category with format:
```
N. **short description**: When [error signal], [fix action]. [date]
```

**Overflow**: When a category exceeds 10 entries, remove the oldest or least-useful entry.

**Format**: Keep entries concise (~50 tokens each). The index should be scannable in <5 seconds.

### Integration with Self-Improvement (Section 13)

During tip extraction at session end:
1. Review `error-events.jsonl` for unresolved errors (status: unresolved)
2. If any were resolved during the session but not logged, capture them now
3. Patterns that recur across 3+ sessions should be promoted to `tips-debugging.md` or the relevant topic file
