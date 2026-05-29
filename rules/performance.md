# Performance Optimization

## Model Selection Strategy

**Main Session (PE): Opus 4.8 (CURRENT)**
- Model ID `claude-opus-4-8`; successor to Opus 4.7 (4.7 released 2026-04-16)
- Best overall quality for orchestration, planning, and execution
- Fast mode supported (faster output, no downgrade to a smaller model) — toggle with /fast on Opus 4.8/4.7/4.6
- Adaptive thinking is the only supported thinking mode (display defaults to "omitted")
- NOTE: 4.8 pricing/spec details below are carried over from 4.7 — reconfirm against current Anthropic pricing

**Haiku 4.5** ($1/$5 per MTok — 5x cheaper than Opus):
- build-error-resolver, doc-updater
- Checklist-based tasks, lightweight read-only exploration
- Simple, scoped tasks

**Sonnet 4.6** ($3/$15 per MTok — best cost/quality):
- code-reviewer, ux-reviewer, tdd-guide, e2e-runner
- performance-optimizer, database-specialist, refactor-cleaner, devops-specialist
- jornalista, redator, escritor-tecnico, editor-de-texto
- ortografia-reviewer, grammar-reviewer, tech-recruiter, seo-reviewer
- 79.6% SWE-bench (near-Opus parity for coding)

**Opus 4.8** ($5/$25 per MTok — deepest reasoning; pricing carried from 4.7, reconfirm):
- staff-engineer, architect, planner, security-reviewer, incident-responder
- editor-chefe, deep-researcher, fact-checker

**1M context variant (`opus[1m]`)** — only the main PE session and these big-context agents:
- staff-engineer, architect, security-reviewer, deep-researcher (frontmatter `model: opus[1m]`)
- Bare `opus`/`sonnet` aliases resolve to the standard 200K window — the `[1m]` suffix is required per-agent; subagents do NOT inherit the main session's 1M. Haiku has no 1M variant (capped 200K).
- Ref: code.claude.com/docs/en/model-config.md (Extended context)
- Complex architectural decisions, production diagnosis, editorial direction
- Improved coding, finance/legal benchmarks (GDPval-AA), multi-step reasoning
- Best at catching subtle bugs

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
