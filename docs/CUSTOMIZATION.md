# Customização — Como Adaptar para Seu Projeto

## Passo 1: Copie os agentes

```bash
cp quarterdeck/agents/*.md ~/.claude/agents/
cp quarterdeck/rules/*.md ~/.claude/rules/
```

## Passo 2: Configure o idioma

Os agentes vêm configurados para **pt-BR**. Para mudar para inglês ou outro idioma, edite a regra de idioma no Output Format de cada agente:

```markdown
# De:
- **IDIOMA: Sempre em pt-BR...**

# Para:
- **IDIOMA: Always in English...**
```

## Passo 3: Ajuste os modelos

No frontmatter de cada agente, ajuste o modelo conforme seu plano:

```yaml
---
model: sonnet   # Mais barato, bom para a maioria das tarefas
model: opus     # Mais caro, melhor para raciocínio profundo
model: haiku    # Mais barato, bom para tarefas simples
---
```

**Recomendação de distribuição:**
- Opus: agentes estratégicos (architect, planner, security-reviewer)
- Sonnet: agentes de execução (code-reviewer, tdd-guide, devops-specialist)
- Haiku: agentes simples (build-error-resolver, doc-updater)

## Passo 4: Adicione contexto do seu projeto

Crie um `CLAUDE.md` na raiz do seu projeto com:

```markdown
# Meu Projeto

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16
- Cache: Redis

## Serviços
- backend.service (porta 8000)
- scheduler.service

## Convenções
- Testes: pytest
- Linting: ruff
- Formatação: ruff format
```

Os agentes carregam automaticamente o `CLAUDE.md` do projeto e adaptam seu comportamento.

## Passo 5: Customize agentes individuais

### Adicionar ferramentas

```yaml
---
tools: Read, Grep, Glob, Bash, Skill(local-mind:super-search)
---
```

### Adicionar seções específicas do projeto

No final do arquivo do agente, adicione uma seção:

```markdown
## Diretrizes do Projeto

- Endpoints sempre assíncronos (`async def`)
- Usar Pydantic v2 para validação
- Todas as queries via SQLAlchemy async
```

### Ajustar token budget

No Output Format, altere o limite:

```markdown
Regras:
- Output máximo: 600 tokens   # aumente para agentes que precisam de mais detalhe
```

## Passo 6: Adicione ou remova agentes

### Criar novo agente

Crie `~/.claude/agents/meu-agente.md`:

```yaml
---
name: meu-agente
description: Especialista em [domínio]. Usar quando [trigger].
tools: Read, Grep, Glob
model: sonnet
---

[Descrição do papel em 1-2 frases]

## Ground Truth First

1. **Leia antes de analisar** — [instrução específica]
2. **Busque padrões** — [instrução específica]
3. **Pergunte quando tiver dúvida** — [instrução específica]

## [Seções específicas do domínio]

## Output Format (MANDATORY)

Structure your response EXACTLY as follows:

### ACHADOS (max 5, ordenados por severidade)
- **[CRITICAL|HIGH|MEDIUM|LOW]** [título] — [localização] — [descrição + correção]

### PRÓXIMO PASSO: [1-2 frases]

### RESUMO:
Impacto no sistema/negócio.
Como foi analisado/abordado.
O que foi encontrado, com números concretos.

Regras:
- Output máximo: 400 tokens
- Sem preâmbulo, sem filler
- **IDIOMA: Sempre em pt-BR...**
```

### Remover agente

Simplesmente delete o arquivo `.md` correspondente de `~/.claude/agents/`.

## Passo 7: Configure a PE rule

A rule `principal-engineer.md` é o coração do sistema. Ajuste:

- **Seção 6 (Routing Table)**: adicione/remova rotas para seus agentes
- **Seção 8 (Workflow Chains)**: defina cadeias de trabalho para seus workflows
- **Seção 15 (Crawler Protocol)**: ajuste as routing tables paralelas
- **Seção 16 (PE Synthesis)**: ajuste o formato de síntese

## Dicas

1. **Comece com poucos agentes** — Não precisa usar todos os 26 desde o início
2. **Agentes mais úteis para começar**: code-reviewer, planner, tdd-guide, deep-researcher
3. **Adicione conforme necessidade** — Quando sentir falta de um especialista, adicione
4. **Teste o output** — Rode um agente e valide se o formato do RESUMO está claro
5. **Itere** — Ajuste prompts baseado nos resultados que você observa
