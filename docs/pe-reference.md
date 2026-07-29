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

### Step 2: (removed 2026-07-24)

This step required a `### RESUMO` block before ending non-trivial work. It contradicted
`rules/output-discipline.md`, which forbids trailing summaries verbatim -- Claude Code's
native recap covers that ground. The rule that had enforcement code on disk
(`hooks/verify-completion.sh`, never registered) was the one being overruled, so the
requirement is removed here rather than left to be rediscovered.

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



---

## 6. Routing tables (full)

Moved out of the always-on rule on 2026-07-24: these are lookup tables, consulted when a
route is not obvious from the agent descriptions the Agent tool already exposes.

Before analyzing a request from scratch, check these tables for a match. If found, propose the listed route. If no match, use normal judgment.

**Single-Agent Routes:**

| Signal | Agent | Notes |
|---|---|---|
| build failed, type error, won't start | build-error-resolver | |
| production down, 5xx spike, urgent | incident-responder | skip approval for read-only triage |
| slow, latency, timeout | performance-optimizer | |
| security, CVE, vulnerability, secrets | security-reviewer | |
| detection coverage, threat hunt, Sigma/SIEM, ATT&CK/ATLAS mapping, blind-spot, backup/DR readiness, agent-misuse detection | blue-team | proactive defense design; defers point-in-time audit to security-reviewer |
| schema, migration, index, query perf | database-specialist | |
| deploy, CI/CD, pipeline, systemd | devops-specialist | |
| dead code, cleanup, unused | refactor-cleaner | |
| deploy, scp, patch | devops-specialist | follow deploy playbook for target project |
| compare alternatives deeply, landscape analysis, systematic review | deep-researcher | multi-source comparison needed |
| OSINT, investigate entity/domain, due diligence | deep-researcher | infrastructure/entity investigation |
| validate claim from multiple sources, fact-check | deep-researcher | triangulation needed |
| docs, codemap, README | doc-updater | |
| e2e test, Playwright, user journey | e2e-runner | |
| revisar ortografia PT-BR, gramática português | ortografia-reviewer | |
| review EN grammar, spelling, English text | grammar-reviewer | |
| SEO audit, Core Web Vitals, meta tags, structured data | seo-reviewer | |
| criar JD, avaliar candidato, seniority level, salary | tech-recruiter | |
| pauta, ângulo editorial, linha do veículo | editor-chefe | primeiro agent no pipeline editorial |
| apurar reportagem, triangular fontes, entrevistar | jornalista | |
| escrever reportagem, lead, texto jornalístico | redator | |
| verificar fato, etiqueta Lupa, fact-check | fact-checker | |
| editar texto jornalístico, cortar, FENAJ | editor-de-texto | |
| ABNT, IMRAD, ADR, design doc, post-mortem, escrita técnica | escritor-tecnico | |

**Multi-Agent Chains (approval between steps):**

| Trigger | Chain |
|---|---|
| new feature, implement X | planner → tdd-guide → code-reviewer |
| new API endpoint | planner → tdd-guide → code-reviewer → security-reviewer |
| refactor, restructure | architect → refactor-cleaner → code-reviewer |
| fix bug (non-trivial) | tdd-guide → code-reviewer |
| UI change | tdd-guide → ux-reviewer → code-reviewer |
| cross-system change | staff-engineer → architect → (specialists) |
| research + implement | deep-researcher → planner → tdd-guide |
| projeto editorial completo | editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer |
| texto técnico/acadêmico | escritor-tecnico → ortografia-reviewer |

**Parallel Analysis (when Owner asks "review X"):**

| Trigger | Agents (parallel) |
|---|---|
| review code | code-reviewer + security-reviewer |
| evaluate architecture | architect + staff-engineer |
| review PR | code-reviewer + security-reviewer + (ux-reviewer if UI) |
| audit project | security-reviewer + performance-optimizer + code-reviewer + blue-team |
| assess defensive posture, detection coverage, incident readiness | blue-team + security-reviewer |
| revisar texto PT-BR + EN | ortografia-reviewer + grammar-reviewer |


---

## Squad roster (full, with model tier and role)

Moved out of the always-on rule on 2026-07-24: the Agent tool's registry already exposes each
agent's description and tools, so restating them per session was duplication. Model tier per
agent is authoritative in `~/.claude/rules/performance.md`.

**🔍 Planning & Design Squad**

| Agent | Model | Role |
|---|---|---|
| architect | opus | HOW to build — patterns, trade-offs, ADRs |
| planner | opus | IN WHAT ORDER to build — phases, risks, dependencies |

**🛡️ Quality Gate Squad (read-only, ALWAYS run in PARALLEL)**

| Agent | Model | Role |
|---|---|---|
| code-reviewer | sonnet | Code: quality, patterns, bugs, maintainability |
| security-reviewer | opus | Infra: hardening, threats, secrets, compliance |
| ux-reviewer | sonnet | UI: accessibility, consistency, interaction states |
| staff-engineer | opus | Org: cross-system impact, pattern propagation, tech debt |
| blue-team | opus | Defense: detective controls, AI/agent-ecosystem detection, secure-by-design, recovery readiness (read-only, designs — devops implements) |

**🔨 Implementation Squad (write code, need ZONE ASSIGNMENT)**

| Agent | Model | Role |
|---|---|---|
| tdd-guide | sonnet | TDD: tests-first, unit/integration, coverage 80%+ |
| e2e-runner | sonnet | E2E: Playwright, user journeys, flaky management |
| build-error-resolver | haiku | Fixes: build errors with minimal diff |
| refactor-cleaner | sonnet | Cleanup: dead code removal, consolidation |

**⚙️ Operations Squad**

| Agent | Model | Role |
|---|---|---|
| incident-responder | opus | REACTIVE: production down, diagnosis, remediation options |
| devops-specialist | sonnet | PROACTIVE: CI/CD, deploy, systemd, monitoring |
| performance-optimizer | sonnet | Profiling: bottlenecks, tuning, resource optimization |
| database-specialist | sonnet | PostgreSQL: schema, queries, indexes, migrations |

**📚 Intelligence Squad**

| Agent | Model | Role |
|---|---|---|
| deep-researcher | opus | Research: multi-source, OSINT, triangulation, confidence-scored |
| doc-updater | haiku | Documentation: codemaps, READMEs from actual code |

**✍️ Language Squad (read-only, single-language scope)**

| Agent | Model | Role |
|---|---|---|
| ortografia-reviewer | sonnet | PT-BR: ortografia, gramática, concordância, regência (ENEM nota 1000) |
| grammar-reviewer | sonnet | EN-US: spelling, grammar, punctuation, style (GRE 6/6) |

**🎯 Strategy Squad (specialized advisors)**

| Agent | Model | Role |
|---|---|---|
| seo-reviewer | sonnet | Technical SEO: Core Web Vitals, meta tags, structured data, rendering |
| tech-recruiter | sonnet | Tech hiring: JD review/creation, candidate eval, seniority, market validation |

**📰 Editorial Squad (content production pipeline)**

Fluxo editorial completo: pauta → apuração → redação → verificação → edição → revisão ortográfica.
Todos obrigatoriamente sob Sourcing Discipline Protocol (`~/.claude/rules/sourcing-discipline.md`).

| Agent | Model | Role |
|---|---|---|
| editor-chefe | opus | Direção editorial: pauta, ângulo, linha do veículo, aprovação de projetos |
| jornalista | sonnet | Apuração, investigação, entrevistas, triangulação de fontes, material bruto |
| redator | sonnet | Produção editorial: transforma material bruto em texto publicável com voz/ritmo |
| escritor-tecnico | sonnet | Escrita técnica/acadêmica: ABNT, IMRAD, Diátaxis, ADRs, design docs, post-mortems |
| fact-checker | opus | Verificação independente (Rule of Two): etiquetas Lupa, triangulação 3+ fontes |
| editor-de-texto | sonnet | Edição final: cortes, lead/fechamento, código FENAJ, linguagem jurídica |

**Pipeline recomendado para projetos editoriais:**
```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
  (pauta)      (apura)      (escreve)  (verifica)     (lapida)          (revisa)
```

**Nota**: `escritor-tecnico` é caminho paralelo para conteúdo técnico/científico (pula jornalista/fact-checker, vai direto para ortografia-reviewer).


---

## 17. Improvement Maturity Levels (self-assessment)

Adopted from borghei/Claude-Skills (`self-improving-agent`, 2026-04-26). Use this scale to judge the maturity of any continuous-learning behavior the PE or an agent owns. Target: **Level 3+** for anything related to memory or rule promotion.

| Level | Name | Mechanism | Current state |
|-------|------|-----------|---------------|
| 0 | Stateless | No memory between sessions | — |
| 1 | Recording | Captures observations, no action | `local-mind` hooks, `capture_patterns.py` |
| 2 | Curating | Organizes and deduplicates observations | `continuous-learning` skill + `distill-patterns.py` |
| 3 | Promoting | Graduates patterns to enforced rules | `rule_promoter.py` (hardened) → `~/.claude/learning/rule-candidates.md` for manual review |
| 4 | Extracting | Creates reusable skills from proven patterns | manual today; revisit when candidate corpus grows |
| 5 | Meta-Learning | Adapts learning strategy itself | not implemented |

When proposing changes to the learning system, state the current Level and the targeted Level. If the proposal does not move the needle, prefer a smaller change.

## 18. Promotion Criteria Matrix

When the PE (or an agent) proposes promoting a memory entry to a permanent rule (CLAUDE.md or `~/.claude/rules/`), the entry MUST satisfy ALL five criteria below. Formalizes the implicit "promote recurring patterns" guidance with explicit thresholds.

| Criterion | Threshold | How to verify |
|-----------|-----------|---------------|
| Recurrence | seen in 3+ distinct sessions | check memory entry's recurrence counter |
| Consistency | same solution every time | no contradicting entries exist |
| Impact | prevented at least one error or saved meaningful time | one concrete incident referenced |
| Stability | underlying code/system has not changed | the file/tool/dep referenced still exists today |
| Clarity | statable in 1-2 sentences | rule body ≤ 200 chars (enforced by `rule_promoter.sanitize_rule_text`) |

Output of `rule_promoter.py --list-candidates` lists entries that pass these criteria. The Owner promotes manually via PR — auto-promotion is forbidden (memory-poisoning defense).

## 19. Skill Chain Pattern (pure pipeline, no PE judgment)

Adopted from borghei's `orchestration-protocol.md` (Pattern 4). Distinct from Workflow Chains (Section 8) which keep PE in the loop between every step.

**When to use:** Repeatable automation where consistency matters more than judgment. CI/CD-like flows. Batch processing.

**Rules:**

1. No PE between steps — direct skill-to-skill data flow.
2. Each skill in the chain MUST declare input/output format (JSON, Markdown, or text).
3. Fail-fast: if a skill produces invalid output, the chain aborts immediately.
4. Idempotent: running the chain twice on the same input produces the same output.
5. Observable: log each step's input/output for debugging.

**Examples in this stack:**

- `error-index` updating: `detect-errors → categorize → dedupe → write-index` (no PE judgment between steps).
- Memory health pipeline: `memory_health_checker → rule_promoter --list-candidates → human review` (PE only at the final review gate).

**Anti-patterns:**

- Adding the PE to a pure execution chain (adds latency without value)
- Chains longer than 6 steps (debug complexity grows exponentially)
- Skills that mutate their input in place (breaks traceability)
- Missing error handling between steps (silent failures corrupt downstream output)

For chains that DO need PE judgment, use Workflow Chains (Section 8) or the Crawler Protocol (Section 15).


---

## 15. Multi-Agent Orchestration — Workflow-First (Crawler Protocol)

**When the PE needs MORE THAN ONE agent, the `Workflow` tool is the canonical engine.** It replaces manual fan-out of Task agents with deterministic control flow (`pipeline()`/`parallel()`), schema'd output, adversarial-verify patterns, budget control, and up to 16 concurrent / 1000 total agents. A SINGLE agent → use the `Agent` tool directly. The PE MUST maximize parallel execution: default to PARALLEL, go sequential only on a TRUE data dependency. (Hierarquia Owner>PE>Agents já definida na Section 2.)

### Opt-in gate (HARD — harness-enforced)

The `Workflow` tool can only be **called** when the Owner opted in: keyword `ultracode` in the message, OR ultracode on for the session, OR an explicit ask ("usa um workflow", "orquestra com subagents"), OR a skill that triggers it. Without opt-in the harness **forbids** launching a workflow. Therefore:

- **Opted in** → PE authors and launches the Workflow.
- **NOT opted in** → PE describes the proposed workflow (phases, agent count, rough token cost) and asks the Owner for the go (noting they can just say `ultracode`). NEVER fan out silently.
- **Trivial verified edit** (1-few files, mechanical) → PE does it solo even if multi-step. Don't wrap a 4-line change in a workflow.

### Effort dosing (calibrate per task — `opts.effort`)

Every `agent()` call accepts `opts.effort` ∈ `low | medium | high | xhigh | max`. **Default = OMIT (inherit session effort). Do NOT over-specify.** Calibrate by difficulty:

| Task class | effort | examples |
|---|---|---|
| Mechanical / deterministic | `low` | rename, frontmatter edit, file move, lint/build-error fix, doc stub, format |
| Routine read / search / summarize | omit (inherit) | Explore sweeps, single-file edits, codemap, routine review |
| Substantive implementation / planning | inherit → `high` | multi-file feature, integration, planner/architect plan |
| Hardest reasoning | `high` / `xhigh` | adversarial verify, security analysis, architecture trade-off, judge panel, gnarly debugging |
| Maximum-stakes arbiter | `max` | rare — final judge when a wrong call is very costly |

Effort is the PRIMARY dial (scales tokens within a model); **model is SECONDARY** (scales $/token) — dose effort first. For `model`: the default is to inherit the session model, which is exactly how a workflow of N agents multiplies the session's cost by N — so **pin mechanical stages explicitly** (`opts.model: 'sonnet'`/`'haiku'`) instead of letting them inherit. Use `opts.agentType` to get a role agent (its frontmatter `model:` applies); keep opus for security/incident/deep reasoning. Tier prices and the allowlist live in `~/.claude/rules/performance.md`.

### Crawler concepts → Workflow primitives

| Crawler concept (manual, old) | Workflow primitive (now) |
|---|---|
| Wave (parallel within, sequential between) | `parallel()` barrier between phases — or `pipeline()` for no-barrier streaming (DEFAULT) |
| Fan-out / fan-in | `parallel(thunks)`, then collect/synthesize in the script |
| Zone assignment (write conflict) | `isolation: 'worktree'` per `agent()` |
| Sequential dependency | pipeline stages / await order |
| PE-only synthesizer | final synthesis stage or the script return value |

Default to `pipeline()` (no barrier between stages). Use a `parallel()` barrier ONLY when a stage genuinely needs ALL prior results (dedup, early-exit on zero, cross-item compare). The conceptual reference below (waves, zones, routing) still holds — it now describes how to COMPOSE a workflow, not how to hand-spawn Task agents.

### Wave Execution Model

Instead of sequential chains, the PE groups work into **waves**. Within a wave, all tasks run in parallel. Between waves, sequential.

```
Wave 1 (PARALLEL — reconnaissance):
  ├── Explore agent: codebase structure + existing patterns
  ├── Explore agent: test coverage + dependencies
  └── deep-researcher: external research (if needed)

Wave 2 (SEQUENTIAL — planning):
  └── planner or architect: plan based on Wave 1 results

Wave 3 (PARALLEL — implementation):
  ├── tdd-guide: tests + implementation (worktree)
  └── devops-specialist: CI/CD changes (worktree)

Wave 4 (PARALLEL — validation):
  ├── code-reviewer: code quality
  ├── security-reviewer: security audit
  └── ux-reviewer: UI review (if applicable)
```

### Fan-Out / Fan-In Pattern

```
1. PE decomposes Owner request into N independent sub-tasks
2. PE spawns N agents in parallel (fan-out)
   - Each agent gets: task description + output contract (+ `isolation: 'worktree'` if it writes)
3. PE collects all results
4. PE synthesizes into unified answer (fan-in)
5. PE presents single coherent analysis to Owner
```

### Updated Parallel Routing Table

**Always Parallel (no dependencies between these):**

| Trigger | Agents (PARALLEL) |
|---|---|
| review code/PR | code-reviewer + security-reviewer + (ux-reviewer if UI) |
| evaluate architecture | architect + staff-engineer |
| audit project | security-reviewer + performance-optimizer + code-reviewer + blue-team |
| assess defensive posture, detection coverage, incident readiness | blue-team + security-reviewer |
| investigate issue | Explore (codebase) + deep-researcher (web) |
| validate implementation | code-reviewer + security-reviewer + tdd-guide (test run) |
| multi-project analysis | 1 agent per project, all parallel |

**Wave-Based Chains (parallel within waves, sequential between):**

| Trigger | Wave 1 (parallel) | Wave 2 (sequential) | Wave 3 (parallel) |
|---|---|---|---|
| new feature | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| new API endpoint | Explore + deep-researcher | planner | tdd-guide + code-reviewer + security-reviewer |
| refactor | Explore (structure) + Explore (tests) | architect | refactor-cleaner + code-reviewer |
| fix bug (complex) | Explore (code) + Explore (tests) | tdd-guide | code-reviewer |
| UI change | Explore + deep-researcher | planner | tdd-guide + ux-reviewer + code-reviewer |

### Parallel Execution Rules

1. **No fixed cap inside a workflow** — `Workflow` caps at 16 concurrent / 1000 total; scale agent count to the task and `log()` any coverage you bound (top-N, sampling). The old "5 per wave" was a manual-spawn budget guard — it no longer applies when orchestrating via the `Workflow` tool. For manual `Agent`-tool fan-out WITHOUT a workflow, still keep it modest (≤5).
2. **Read-only agents always parallelize** — no conflict risk
3. **Write agents run in their own worktree** — `isolation: 'worktree'`, so conflict is impossible rather than forbidden
4. **Failed agent does NOT block others** — PE handles via Section 11 (Chain Failure Recovery)
5. **PE is the ONLY synthesizer** — agents never see each other's output directly
6. **Background agents for non-blocking work** — use `run_in_background: true` when PE doesn't need results immediately

### SOTA 2026 — Parallel vs Single-Agent Decision (added 2026-04-28)

Empirical evidence (arXiv 2604.02460, 2502.08788, ICLR 2025 MAD, Anthropic multi-agent research blog):

| Task type | Use parallel multi-agent | Use single Opus + extended thinking |
|---|---|---|
| **Judging / review** (code-review, security-audit, fact-check) | ✅ wins — heterogeneous critics catch different failure modes | ❌ underused |
| **Breadth-first research** (multi-source comparison, OSINT, landscape mapping) | ✅ wins at 15× cost — only when value justifies | ❌ misses sources |
| **Solution-finding** (design API, plan refactor, architect choice) | ❌ ANTI-PATTERN — agents read same files, produce overlapping output | ✅ wins at equal token budget |
| **Red team vs blue team debate on same artifact** | ❌ ANTI-PATTERN unless models are heterogeneous (e.g., Opus vs Sonnet) | ✅ Opus + adversarial framing |

**Default rule:** if all agents in a wave would read the **same files** and produce **same-type findings**, you have an anti-pattern. Either specialize their angles (different zones, different depths) or collapse to a single agent with extended thinking.

### Anti-Patterns to Avoid (audit 2026-04-28)

1. **Dual-format output requirement** (JSON + Markdown) — sub-agents cannot declare structured output contracts (GitHub issue #20625); pick Markdown only. Format-insensitive on Opus/Sonnet (0% perf delta).
2. **agent-recall on every spawn** — only Quality Gate agents need it. Implementation/Research agents waste preamble tokens on irrelevant history.
3. **Scratch files for short tasks** — folklore, not Anthropic-validated. Skip for tasks <5 tool calls.
4. **Re-spawning when SendMessage suffices** — for stateful continuation of the same logical agent, prefer SendMessage. Fresh spawn for fresh tasks.
5. **Verbose preamble bloat** — keep ≤800 tokens; >2k = compaction risk for low-signal data.
6. **Multi-agent debate for solution-finding** — empirically loses to single-Opus + extended thinking at equal budget.
7. **Launching a workflow without opt-in** — harness-forbidden; propose the workflow + rough cost and ask instead.
8. **Over-specifying `effort`/`model` on every `agent()`** — default is inherit; deviate only with a reason (mechanical→`low`, hardest→`high`+).
9. **`parallel()` barrier where `pipeline()` suffices** — a barrier wastes wall-clock when no stage needs all prior results.
10. **Wrapping a trivial verified edit in a workflow** — solo is correct there; reserve workflows for real fan-out.

---

## 3. Search Depth Triage (PE WebSearch vs deep-researcher)

> Movido do always-on em 2026-07-29 (/doctor). A regra de recência das buscas ficou inline em
> `principal-engineer-always-on.md §3`; só o triage vive aqui.

Before searching for external information, triage the query:

**PE handles directly with WebSearch** (0 marginal tokens):
- Single-fact lookups: "What's the latest version of X?", "Does Y support Z?"
- Documentation/syntax questions: "How to do X in FastAPI?"
- Quick link finding: "Official docs for library Y"
- Simple status checks: "Is service X still maintained?"
- Any query answerable with 1-2 searches

**Spawn deep-researcher** (Opus, ~20-40k tokens) — only when:
- Multi-source comparison: "Compare X vs Y vs Z for our use case"
- Triangulation needed: "Validate whether claim X is true across independent sources"
- OSINT / entity investigation: "Who owns domain X? What stack does company Y use?"
- Landscape mapping: "What are ALL the options for solving problem X?"
- Systematic review: "What's the current state of technology X in production?"

**Gray zone — try-then-escalate:**
If unsure whether a query is simple or deep:
1. PE tries 1-2 WebSearch queries first
2. If results are sufficient, synthesize and respond (done)
3. If results are contradictory, thin, or require decomposition into 3+ sub-questions, propose deep-researcher to the Owner with what was already found and what gaps remain

**Cost awareness:** deep-researcher costs ~18x more tokens than PE WebSearch. Only spawn when validated, triangulated research with structured output adds real value to the decision at hand.

---

## 9 (Part 3). Scratch Files como memória estruturada

> Movido do always-on em 2026-07-29 (/doctor). Ler ao spawnar agent de task longa.

Para agentes que executam tasks longas (>5 tool calls) OU cujo resultado precisa sobreviver entre waves/handoffs, o PE DEVE orientar o agente a usar um **scratch file** como memória externa:

```
~/.claude/tmp/agent-{agent-name}-{short-task-id}.md
```

Conteúdo típico do scratch:
- **Goal**: objetivo da task (1 frase)
- **Progress**: status atual (in_progress / blocked / done)
- **Findings**: achados acumulados até o momento
- **Open questions**: dúvidas que precisam de input
- **Next step**: próxima ação concreta

Benefícios:
- Sobrevive a compactação de contexto
- Permite handoff entre agentes (agente A grava, agente B lê)
- PE pode inspecionar estado de agentes em background sem re-spawn
- Memória estrutural git-trackeable (opcional)

Quando NÃO usar:
- Tasks triviais (1-3 tool calls)
- Agentes read-only com output efêmero (revisores)

Referência: padrão "initializer + progress file" validado pela Anthropic em long-running harnesses.

---

## 15 (racional). Por que worktree substituiu o mapeamento de zonas

> Movido do always-on em 2026-07-29 (/doctor). As REGRAS duras (opt-in obrigatório para
> `Workflow`, `isolation: 'worktree'` para agent que escreve, read-only não isola) continuam
> inline em `principal-engineer-always-on.md §15` — proibição não vai para arquivo lazy.

Cada worktree é um checkout próprio em disco, então dois agents editando o mesmo arquivo é
fisicamente impossível em vez de proibido. Custo ~200-500ms mais disco por agent, e um
worktree inalterado é removido automaticamente.

Isso substituiu o protocolo anterior, que pedia ao PE mapear a zona de arquivos de cada
agent, verificar não-sobreposição, e repetir a zona em todo prompt — três passos de
disciplina cognitiva sustentados por nada, protegendo contra um conflito que o filesystem
previne de saída. Texto de zona num prompt é um pedido; um checkout separado é uma garantia.

Quando um write-agent tem que operar na árvore viva — deploy, rodar migration, qualquer coisa
cujo efeito está fora do git — não paralelize de jeito nenhum. Serialize.

---

## 16. PE Synthesis Protocol (Fan-In Output)

> Movido do always-on em 2026-07-29 (/doctor). Ler ao sintetizar resultado de multi-agent.

When presenting multi-agent results to the Owner, the PE MUST use this format:

```markdown
## Resultados dos Agentes
| Agente | Resultado | Achado-chave |
|--------|-----------|--------------|
| [agente] | [resultado] | [1 frase] |

## Itens de Ação (merged por severidade)
1. [CRITICAL] [item] — [agente fonte] — [arquivo/localização]
2. [HIGH] [item] — [agente fonte] — [arquivo/localização]

## Contradições (se houver)
- [Agente A] diz [X] vs [Agente B] diz [Y]
- **Avaliação:** [qual está correto e por quê]
```

Rules:
- Sempre merge findings por severidade, não por agente
- Sempre exponha contradições explicitamente
- Síntese em no máximo 300 tokens
- O Owner deve conseguir tomar decisão lendo apenas a tabela + itens de ação
- **NÃO escreva trailing summaries (RESUMO/SUMMARY)** — o recap nativo do Claude Code 2.0 cobre o final (regra já ativa sempre via `output-discipline.md`)
- **Markdown only** (added 2026-04-28) — não pedir output dual JSON+Markdown. Sub-agents não suportam structured output contracts (GitHub #20625). Pick Markdown for human readability; agents return condensed 1-2k token summaries per Anthropic context engineering guidance.
- **LANGUAGE: Synthesis mirrors the Owner's prompt language — pt-BR if the Owner wrote in pt-BR, English if English. The 6 editorial PT-BR agents (ortografia-reviewer, editor-chefe, jornalista, redator, fact-checker, editor-de-texto) always synthesize in Portuguese (they handle PT-BR text).**
