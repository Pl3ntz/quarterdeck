# Performance Optimization

## Model Selection Strategy

> **Updated 2026-07-24** — Claude 5 generation. Prices and context windows verified against the
> official comparison table (`platform.claude.com/docs/en/about-claude/models/overview`). This policy
> is **enforced by the harness**, not merely documented — see "Enforcement" below.

### Enforcement (allowlist, not convention)

`settings.json` carries:

```json
{ "model": "opus", "availableModels": ["opus", "sonnet", "haiku"] }
```

`availableModels` applies the allowlist to **every** path a model can enter through: the main session
(`/model`, `--model`, `ANTHROPIC_MODEL`, the `model` setting, session resume), alias resolution,
`/fast`, **subagent frontmatter**, the Agent tool's `model` parameter, `CLAUDE_CODE_SUBAGENT_MODEL`,
skill and command models, and the advisor. A blocked selection in a subagent falls back to the
inherited model instead of failing the request.

The documentation describes `availableModels` in the context of managed or policy settings. Verified
on 2026-07-24 that it **also works in user settings**: `claude -p --model fable` resolved to the
permitted Opus, and `CLAUDE_CODE_SUBAGENT_MODEL=fable` did the same inside a subagent.

The lesson behind the change: a written rule ("do not use tier X") does not prevent use. While it was
only documentation, the banned tier kept accruing spend through session inheritance. An allowlist
fixes that; prose does not.

### Current tiers

| Model | $/MTok | Context | Adaptive thinking | Use |
|---|---|---|---|---|
| **Opus 5** (`claude-opus-5`) | $5 / $25 | 1M | yes | Main session (PE) plus the hardest-reasoning agents |
| **Sonnet 5** (`claude-sonnet-5`) | **$2/$10 through 2026-08-31**, then $3/$15 | 1M | yes | Implementation, review, editorial — best cost/quality |
| **Haiku 4.5** (`claude-haiku-4-5`) | $1 / $5 | **200k** | **no** | Mechanical, low-error-cost tasks only |
| ~~Fable 5~~ | $10 / $50 | 1M | always on | **Blocked by the allowlist** |

**Fable 5 — banned.** Reverted on 2026-06-21 after regressions: lower code-review precision,
overthinking and timeouts on short harnesses, unrequested actions, and availability outages killing
workflows. **Do not re-enable without an explicit Owner decision.**

**Watch out for Haiku 4.5:** knowledge cutoff **Feb 2025** (training data Jul 2025) and no adaptive
thinking. An agent writing code on it is behind on toolchain versions. Do not use it for write-agents.

Allocation by tier:
- **Opus** — architect, planner, deep-researcher, staff-engineer, security-reviewer,
  incident-responder, editor-chefe, fact-checker
- **Sonnet** — code-reviewer, ux-reviewer, tdd-guide, e2e-runner, performance-optimizer,
  database-specialist, refactor-cleaner, devops-specialist, jornalista, redator, escritor-tecnico,
  editor-de-texto, ortografia-reviewer, grammar-reviewer, tech-recruiter, seo-reviewer
- **Haiku** — doc-updater only (mechanical, low error cost, output is reviewed)

### Model propagation (where the leak came from)

- Subagent frontmatter **defaults to `inherit`** — omitting the field means inheriting the main
  session. (The previous version of this rule claimed the opposite; that was the blind spot.)
- Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` → the Agent tool's `model` parameter → frontmatter →
  the main conversation's model.
- **Workflow agents inherit the session model** unless the script passes `opts.model` on the stage. A
  workflow of N agents in an expensive session multiplies that cost by N — in practice this is the
  single largest spend line in the system. **Pin mechanical stages explicitly** rather than letting
  them inherit.
- `CLAUDE_CODE_SUBAGENT_MODEL` overrides both frontmatter AND the Agent tool parameter, flattening the
  whole squad onto one tier. Do not reach for it as a cost control.

### 1M context

- On the Anthropic API, **Opus 5, Sonnet 5 and Fable 5 are 1M by default** — no beta header, no
  suffix, billed at standard pricing. Sonnet 5 now has a native 1M window, so "we need Opus for the
  context window" is no longer a valid argument.
- Haiku 4.5 is 200k and **has no 1M variant**.
- The `[1m]` suffix is **not among the documented accepted values for subagent frontmatter** (only for
  the main-session model setting), and it is redundant on models that are already 1M.

### How to verify

`python3 scripts/agent-usage-report.py --report --days 30` — cost and volume per (agent, model),
derived from `attributionAgent` + `usage` in the session transcripts. It is the only source that
distinguishes individual agents: native OpenTelemetry collapses every user-defined agent into
`agent.name="custom"` (verified empirically), so it measures model and effort but never which agent.

## Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity tasks:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

## Ultrathink + Plan Mode

For complex tasks requiring deep reasoning:
1. Use `ultrathink` for enhanced thinking
2. Enable **Plan Mode** for structured approach
3. "Rev the engine" with multiple critique rounds
4. Use split role sub-agents for diverse analysis

## Build Troubleshooting

If build fails:
1. Suggest **build-error-resolver** agent to Owner
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
