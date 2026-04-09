---
description: Agent Observability — mostra estatísticas de uso dos agentes (quais rodam, quais nunca foram invocados, custo, co-invocação)
---

# /agent-stats — Agent Observability

Analisa o log `~/.claude/learning/agent-usage.jsonl` e responde perguntas sobre utilização do ecossistema de agentes.

## Subcomandos

| Comando | Ação |
|---|---|
| `/agent-stats` (default) | Resumo geral: total invocations, top 10, dead agents |
| `/agent-stats top` | Top 10 agentes mais invocados |
| `/agent-stats dead` | Agentes nunca invocados (dead code) |
| `/agent-stats cost` | Top 10 por tokens consumidos |
| `/agent-stats squad <name>` | Uso por squad específico (planning, quality-gate, etc.) |
| `/agent-stats recent N` | Últimas N invocations cronológicas |
| `/agent-stats session <id>` | Todas as invocations de uma sessão |
| `/agent-stats coinvoke <agent>` | Quais agentes costumam rodar junto com `<agent>` |

## Implementation

Use Python para processar o log JSONL:

```python
import json
from pathlib import Path
from collections import Counter, defaultdict

LOG = Path.home() / ".claude" / "learning" / "agent-usage.jsonl"

if not LOG.exists():
    print("No agent usage data yet. Run some agents first.")
    # exit

entries = []
with LOG.open() as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Known agents from this repo
ALL_AGENTS = [
    # Planning & Design
    "architect", "planner",
    # Quality Gate
    "code-reviewer", "security-reviewer", "ux-reviewer", "staff-engineer",
    # Implementation
    "tdd-guide", "e2e-runner", "build-error-resolver", "refactor-cleaner",
    # Operations
    "incident-responder", "devops-specialist", "performance-optimizer", "database-specialist",
    # Intelligence
    "deep-researcher", "doc-updater",
    # Language
    "ortografia-reviewer", "grammar-reviewer",
    # Strategy
    "seo-reviewer", "tech-recruiter",
    # Editorial
    "editor-chefe", "jornalista", "redator", "escritor-tecnico", "fact-checker", "editor-de-texto",
]

SQUADS = {
    "planning": ["architect", "planner"],
    "quality-gate": ["code-reviewer", "security-reviewer", "ux-reviewer", "staff-engineer"],
    "implementation": ["tdd-guide", "e2e-runner", "build-error-resolver", "refactor-cleaner"],
    "operations": ["incident-responder", "devops-specialist", "performance-optimizer", "database-specialist"],
    "intelligence": ["deep-researcher", "doc-updater"],
    "language": ["ortografia-reviewer", "grammar-reviewer"],
    "strategy": ["seo-reviewer", "tech-recruiter"],
    "editorial": ["editor-chefe", "jornalista", "redator", "escritor-tecnico", "fact-checker", "editor-de-texto"],
}
```

## Output formats

### Default (summary)

```
# Agent Usage Summary

Total invocations: N
Unique agents used: M / 26
Total tokens: T
Data range: YYYY-MM-DD to YYYY-MM-DD

## Top 10 Most Used
| Agent | Invocations | Total tokens |
|---|---|---|
| ... | ... | ... |

## Dead Agents (0 invocations)
- agent-x
- agent-y

## Squad Utilization
| Squad | Invocations | % of total |
|---|---|---|
| ... | ... | ... |
```

### `top`

Top 10 agents ordered by invocation count, with average and total tokens.

### `dead`

List of agents in `ALL_AGENTS` that never appeared in the log. These are candidates for removal or need better discoverability.

### `cost`

Top 10 by total tokens consumed. Useful to identify expensive agents that run often.

### `squad <name>`

Stats for all agents in the given squad. Usage pattern, coverage, relative popularity.

### `coinvoke <agent>`

Find which other agents co-occur in the same session as `<agent>`. Useful to detect implicit pipelines (e.g., tdd-guide always followed by code-reviewer).

## Output rules

- Always respond in pt-BR
- Use tables for comparisons
- Truncate long lists to top 10
- Show zero-values explicitly ("Dead agents: 3" not "Dead agents: —")
- For `coinvoke`, show confidence (how often they co-occur vs independently)

## Example flows

**User: `/agent-stats`**
→ Full summary with top 10, dead agents, squad utilization

**User: `/agent-stats dead`**
→ Lista de agentes nunca invocados. Se há muitos dead agents em uma squad inteira, sinal de que o squad não está sendo descoberto/usado.

**User: `/agent-stats cost`**
→ Top 10 por custo em tokens. Se Opus agents dominam o custo, considere se o trabalho poderia rodar em Sonnet.

**User: `/agent-stats coinvoke code-reviewer`**
→ Mostra quais agentes rodam junto com code-reviewer (provavelmente: tdd-guide, security-reviewer). Confirma pipeline.

## Implementation notes

- **Read the log file directly** — não usar cache
- **Handle empty log** — se não há dados ainda, mostrar mensagem clara
- **Handle malformed lines** — skip silently, não crashar
- **Respect kill switch** — se `.disabled` existe, ainda mostrar dados mas avisar "Log capture paused"
