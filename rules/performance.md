# Performance Optimization

## Model Selection Strategy

**Main Session (PE): Opus 4.7 (CURRENT)**
- Released 2026-04-16, successor to Opus 4.6
- Best overall quality for orchestration, planning, and execution
- New `xhigh` effort level (between high and max) for additional reasoning control
- Adaptive thinking is the only supported thinking mode (display defaults to "omitted")
- Vision: 3x resolution capacity (up to 2,576px on long edge)

**Haiku 4.5** ($1/$5 per MTok — 5x cheaper than Opus):
- build-error-resolver, doc-updater
- Checklist-based tasks, lightweight read-only exploration
- Simple, scoped tasks

**Sonnet 4.6** ($3/$15 per MTok — best cost/quality):
- code-reviewer, ux-reviewer, tdd-guide, e2e-runner, fact-checker
- performance-optimizer, database-specialist, refactor-cleaner, devops-specialist
- jornalista, redator, escritor-tecnico, editor-de-texto
- ortografia-reviewer, grammar-reviewer, tech-recruiter, seo-reviewer
- 79.6% SWE-bench (near-Opus parity for coding)

**Opus 4.7** ($5/$25 per MTok — deepest reasoning):
- staff-engineer, architect, planner, security-reviewer, incident-responder
- editor-chefe, deep-researcher
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
1. Suggest **build-error-resolver** agent to CTO
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
