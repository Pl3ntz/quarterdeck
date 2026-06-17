# Performance Optimization

## Model Selection Strategy

**Main Session (PE): Fable 5 (CURRENT — settings.json `claude-fable-5[1m]`, desde 2026-06-09)**
- Model ID `claude-fable-5`; tier acima do Opus ($10/$50 per MTok). Lançado 2026-06-09.
- Caso de uso canônico (Anthropic): orchestrator — despacha e sustenta subagents; long-horizon
- Adaptive thinking only e SEMPRE ligado (não pode desativar em Fable 5); `thinking: {type: "disabled"}` retorna 400 na API
- Safety classifiers (cybersec/bio) fazem fallback automático para Opus 4.8 — esperado, não é flag de conta
- Regressões conhecidas vs Opus 4.8: precisão de code review (CodeRabbit 32.8% vs 35.5%), overthinking/timeouts em harness curto, ações não solicitadas
- ATENÇÃO `claude -c`: sessões retomadas mantêm o modelo da sessão original, ignorando settings.json (comportamento documentado). Corrigir com `/model fable` na sessão retomada.

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

**Opus 4.8** ($5/$25 per MTok — deepest reasoning):
- architect, planner, deep-researcher, staff-engineer (revertidos de Fable 5 para Opus em 2026-06-17; promoção Fable temporariamente removida)
- security-reviewer (também é o destino do fallback de safety do Fable), incident-responder
- editor-chefe, fact-checker
- Best at catching subtle bugs

**Contexto 1M (atualizado 2026-06-10, ref: code.claude.com/docs/en/model-config.md, Extended context):**
- Na Anthropic API, **Fable 5, Opus 4.8 e Opus 4.7 SEMPRE rodam com janela 1M** — sem sufixo necessário. Não existe alias `fable[1m]`; `model: fable` já é 1M.
- O sufixo `[1m]` segue existindo para aliases (`opus[1m]`, `sonnet[1m]`) e nomes completos; em Opus 4.8 na API é redundante (security-reviewer mantém `opus[1m]`, inofensivo).
- Sonnet 1M NÃO é automático (exige usage credits em planos por assinatura). Haiku não tem variante 1M (200K).
- Subagents NÃO herdam o modelo da main session — frontmatter `model:` de cada agent decide.

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
