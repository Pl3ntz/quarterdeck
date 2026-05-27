# PE Reference — Lazy-loaded Protocols

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

Em chains de **4+ agentes**, o PE DEVE manter um resumo acumulativo para evitar perda de contexto:

```
---context-summary---
goal: [objetivo original do Owner em 1 frase]
agents_completed: [lista de agentes que já rodaram]
key_decisions: [max 5 decisões tomadas até agora]
open_issues: [max 3 questões não resolvidas]
total_files_modified: [contagem]
---end-context-summary---
```

Regras:
- **Criar** o context-summary após o 3º agente completar
- **Atualizar** após cada agente subsequente (append decisions, update issues)
- **Max 400 tokens** — forçar concisão
- **Incluir** no prompt do próximo agente JUNTO com o handoff block
- **Não substituir** o handoff — é complementar (handoff = último step, summary = visão geral)

## 8. Standard Workflow Chains

Named chains the PE can reference. Each step uses the handoff protocol (section 7). Owner can skip steps or alter order.

**CHAIN: new-feature** (trigger: "implementar X", "nova feature")
1. Wave 1: planner → plano com fases e riscos
2. [Owner aprova plano]
3. Wave 2: tdd-guide → testes primeiro, depois implementa
4. [Owner revisa implementação]
5. Wave 3 (PARALELO): code-reviewer + security-reviewer (se API)

**CHAIN: fix-bug** (trigger: "fix bug", "quebrado", "regressão")
1. Wave 1: tdd-guide → teste que reproduz bug, depois corrige
2. Wave 2: code-reviewer → verifica correção

**CHAIN: refactor** (trigger: "refatorar", "cleanup", "reestruturar")
1. Wave 1: architect → analisa estrutura atual, propõe alvo
2. [Owner aprova alvo]
3. Wave 2: refactor-cleaner → executa
4. Wave 3: code-reviewer → verifica

**CHAIN: incident** (trigger: "produção down", "erros", "urgente")
1. incident-responder → diagnostica (skip approval para read-only)
2. [Owner aprova fix]
3. devops-specialist → deploya fix (production gate se aplica)


## 10. Request-Completion Protocol

The PE MUST verify that the Owner's request was fully addressed before stopping.

### Step 1: Capture the Original Request (Session Start)

On the FIRST substantive interaction of every session:
1. Use TaskCreate to create a task with subject: `Owner-REQUEST: <concise summary of what the Owner asked>`
2. Include the key requirements and success criteria in the task description
3. This task is NEVER marked as completed during the session — it serves as a permanent reference anchor
4. If the Owner's request evolves mid-session, create a new `Owner-REQUEST-UPDATE: <updated requirements>` task

### Step 2: Pre-Completion RESUMO (Before Stopping)

Antes de apresentar a resposta final ao Owner em trabalho não-trivial, inclua um RESUMO:

```
### RESUMO: [2-3 frases fluidas explicando: qual o impacto no sistema/negócio → como foi abordado → o que foi entregue com números concretos]
```

### Step 3: Simple Task Exception

Para interações triviais (perguntas rápidas, typo fixes, conversas):
- Pule o TaskCreate anchor
- Pule o RESUMO
- Uma confirmação breve é suficiente

**Threshold**: Se o request do Owner requer 3+ tool calls ou múltiplos arquivos/tópicos, NÃO é trivial — aplique o RESUMO.

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

1. **Detect**: If agent output is missing, malformed, or clearly wrong — do NOT pass it downstream
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

If validation fails, trigger retry protocol — do NOT pass bad output downstream.

### Chain Checkpoint

After each successful agent step in a multi-agent chain:
1. Record the step result in a TaskCreate/TaskUpdate (survives compression)
2. If the chain needs to restart later, resume from the last successful checkpoint — not from the beginning

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

Quando o checker (code-reviewer) encontra um finding CRITICAL, o PE DEVE classificar a causa raiz:

| Causa raiz | Ação do PE |
|---|---|
| **bad_code** — erro na implementação, código não segue a spec | Retry normal: feedback → maker (tdd-guide) corrige |
| **bad_spec** — erro no plano/spec, a implementação seguiu a spec mas a spec estava errada | **Loopback automático**: PE volta para planner/architect com o finding, sem esperar Owner. Gera spec corrigida → retoma implementação |
| **intent_gap** — o request original do Owner era ambíguo e gerou spec incompleta | **Escalate para Owner**: PE apresenta o gap e pede clarificação antes de continuar |

**Regra:** Loopback para bad_spec é AUTO (PE decide sem perguntar ao Owner). Loopback para intent_gap SEMPRE requer aprovação do Owner.

### Quality Tracking

After each maker-checker cycle, the PE records the outcome:
- **PASS on 1st attempt**: Agent is performing well
- **PASS on retry**: Note what needed correction — potential improvement area
- **FAIL after retries**: Flag for Owner — may need prompt refinement or different agent

## 13. Self-Improvement Protocol (Tip Extraction)

The PE SHOULD extract reusable tips from sessions and store them in memory for future use.

### When to Extract Tips

At the end of substantial sessions (not simple Q&A), identify:

1. **Strategy tips** — Patterns from successful executions:
   - "Searching for existing utilities before writing new ones saved 40% implementation time"
   - "Running code-reviewer + security-reviewer in parallel instead of sequential reduced review time"

2. **Recovery tips** — Lessons from failures that were corrected:
   - "When tdd-guide fails because test framework isn't configured, check package.json first"
   - "Deep-researcher OSINT queries on .gov.br domains need PT-BR search queries"

3. **Optimization tips** — Efficiency improvements discovered:
   - "For FastAPI projects, architect is overkill for simple endpoint additions — planner suffices"
   - "Using haiku model for doc-updater produces equivalent quality at 5x lower cost"

### How to Store Tips

Use the auto memory system. Write tips to topic-specific files in `~/.claude/projects/*/memory/`:

```
File: tips-agents.md    — Tips about agent selection and orchestration
File: tips-debugging.md — Tips about debugging patterns
File: tips-[topic].md   — Tips about specific domains
```

Each tip should include:
- **What**: The tip itself (1-2 sentences)
- **Why**: What happened that led to this learning
- **When**: In what context this tip applies

### Tip Quality Rules

- Only extract tips that are **generalizable** (not one-time situational fixes)
- **Deduplicate**: Check existing tips before adding — don't repeat what's already stored
- **Prune**: If a tip is contradicted by newer experience, update or remove it
- **Max 10 tips per topic file** — force prioritization of the most valuable learnings

## 14. Auto-Learning Protocol (Error Memory)

The PE has a persistent error memory system. A PostToolUse hook on Bash automatically detects command errors and logs them to `~/.claude/logs/error-events.jsonl`. The PE is responsible for the intelligent layers: fix capture, index maintenance, and consultation.

### Error Detection (Automatic — Hook)

The `detect-errors.sh` hook runs on every Bash tool call and detects strong error patterns (Traceback, ModuleNotFoundError, command not found, Permission denied, etc.). It silently logs to `error-events.jsonl` with: timestamp, command, matched pattern, category, error snippet.

Categories: `config`, `syntax`, `dependency`, `permission`, `connection`, `file`, `type`, `memory`, `logic`, `tooling`.

The PE does NOT need to trigger detection — it happens mechanically.

### Fix Capture (PE Responsibility)

When the PE fixes an error (any tool — Bash, Edit, Write), it MUST log the resolution:

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

1. **neo4j driver not installed** — When `ModuleNotFoundError: neo4j`, add `neo4j` to requirements.txt and rebuild container. [2026-03-15]
```

**When to capture**: After successfully resolving any error — command that previously failed now works, Edit that was corrected, Write that needed adjustment.

**When NOT to capture**: One-time typos, trivial path mistakes, external service timeouts (not our problem).

### Edit/Write Error Capture (Manual — No Hook)

The PostToolUse hook only covers Bash. For Edit and Write tool failures (file not found, old_string not unique, permission denied), the PE MUST manually log them using the same resolution format above.

These failures are visible to the PE in the tool response. When the PE sees an Edit/Write error and fixes it, log it if the pattern is reusable.

### Index Consultation (Before Retry)

**MANDATORY**: Before retrying a failed operation or attempting something that previously failed:

1. Read `~/.claude/logs/error-index.md`
2. Check the relevant category for similar past errors
3. If a match exists, apply the documented fix instead of blind retry
4. If no match, proceed normally — but if the retry succeeds, consider logging the fix

**When to consult**: Only on error paths. Do NOT read the index on every tool call — only when a tool fails or when attempting an operation known to be error-prone.

### Index Maintenance

The `error-index.md` is organized by category with max **10 entries per category**.

**Adding entries**: After resolving a reusable error, add it under the correct category with format:
```
N. **short description** — When [error signal], [fix action]. [date]
```

**Overflow**: When a category exceeds 10 entries, remove the oldest or least-useful entry.

**Format**: Keep entries concise (~50 tokens each). The index should be scannable in <5 seconds.

### Integration with Self-Improvement (Section 13)

During tip extraction at session end:
1. Review `error-events.jsonl` for unresolved errors (status: unresolved)
2. If any were resolved during the session but not logged, capture them now
3. Patterns that recur across 3+ sessions should be promoted to `tips-debugging.md` or relevant topic file

