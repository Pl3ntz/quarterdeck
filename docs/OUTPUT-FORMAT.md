# Output Format — Comunicação Estruturada

## Conceito

A maioria dos reports técnicos começa pelo resultado ("encontrei 3 bugs"). O nosso formato começa pelo **impacto** ("o sistema tinha risco de perda de dados"), depois explica **como foi abordado**, e termina com **o que foi encontrado em números concretos**.

Isso permite ao Captain entender a importância antes do detalhe técnico — e decidir sem precisar ler tudo.

## Formato Padrão

Todos os 26 agentes usam esta estrutura:

```markdown
### ACHADOS (max 5, ordenados por severidade)
- **[CRITICAL|HIGH|MEDIUM|LOW]** [título] — `file:line` — [descrição + correção]

### PRÓXIMO PASSO: [1-2 frases — ação recomendada]

### RESUMO: [2-3 frases fluidas: impacto no sistema → como foi analisado → resultado concreto com números]
```

## Exemplos por Tipo de Agente

### code-reviewer

```markdown
### ACHADOS
- **HIGH** SQL injection (injeção de SQL) — `src/api/users.py:42` — Query usa string concatenation; usar parâmetros
- **MEDIUM** Console.log em produção — `src/utils/helper.ts:18` — Remover antes do merge

### PRÓXIMO PASSO: Corrigir SQL injection antes do merge. Console.log pode ir no próximo commit.

### RESUMO: O endpoint de usuários tinha risco de SQL injection que poderia expor dados sensíveis. Analisei todos os endpoints do módulo de autenticação e verifiquei padrões de query. Encontrei 1 vulnerabilidade HIGH e 1 issue MEDIUM — ambos com correção sugerida.
```

### incident-responder

```markdown
### SERVIÇOS AFETADOS
- backend — DOWN — desde 14:30
- scheduler — DEGRADADO — timeouts intermitentes

### CAUSA RAIZ: Connection pool esgotado — PostgreSQL atingiu max_connections (100)

### OPÇÕES DE REMEDIAÇÃO
1. **Rápida:** Aumentar max_connections para 200 + restart (~30s downtime)
2. **Completa:** Implementar connection pooling com PgBouncer (2-3h, zero downtime depois)

### PRÓXIMO PASSO: Opção 1 resolve imediatamente; opção 2 previne recorrência. Recomendo opção 1 agora + planejar opção 2 para esta semana.

### RESUMO: O backend caiu afetando todos os usuários porque o pool de conexões PostgreSQL esgotou. Diagnostiquei via logs do serviço e pg_stat_activity, confirmando 100/100 conexões ativas. 2 serviços afetados, causa raiz identificada, 2 opções de remediação com trade-offs claros.
```

### architect

```markdown
### DECISÃO DE DESIGN
**Abordagem escolhida:** Service Layer Pattern (Route → Service → Repository)
**Por quê:** Separa lógica de negócio das rotas, testável unitariamente

### ALTERNATIVAS
| Opção | Prós | Contras |
|-------|------|---------|
| Service Layer | Testável, separação clara | Mais boilerplate |
| Fat Controllers | Simples, menos arquivos | Difícil de testar, acoplado |
| CQRS | Escala leitura/escrita separado | Over-engineering para o escopo atual |

### TRADE-OFFS: Service Layer adiciona ~20% mais código mas reduz 50% o tempo de debug

### PRÓXIMO PASSO: Implementar Service Layer no módulo de autenticação como piloto

### RESUMO: O módulo de auth mistura lógica de negócio com rotas, tornando impossível testar unitariamente. Avaliei 3 padrões arquiteturais contra os requisitos do projeto e padrões existentes. Service Layer é a melhor opção: mais testável, alinhado com FastAPI patterns, custo de ~20% mais código.
```

## Token Budget por Agente

| Tipo de Agente | Max Tokens | Justificativa |
|---|---|---|
| build-error-resolver, doc-updater | 200 | Resultado binário: corrigiu ou não |
| refactor-cleaner, e2e-runner | 300 | Listagem de itens + resultado |
| code-reviewer, tdd-guide, ux-reviewer, staff-engineer, database-specialist, devops-specialist, performance-optimizer | 400-500 | Achados detalhados com evidência |
| architect, planner | 600 | Decisões de design com alternativas |
| deep-researcher | 800 | Síntese multi-fonte com confiança |

## Regra de Idioma

Todos os agentes seguem:

> **Sempre em pt-BR. Inglês somente para termos técnicos (ex: "SQL injection", "rate limiting"), seguidos de descrição clara em português.**

Isso garante que o Captain entende 100% do output sem precisar traduzir mentalmente jargão técnico.

## Princípio por trás do formato

O RESUMO segue o conceito de comunicação estruturada: **impacto antes de detalhe**. Em vez de listar dados e deixar o leitor interpretar, o agente sintetiza em 2-3 frases que respondem naturalmente:

1. Por que isso importa (impacto no negócio/sistema)
2. Como foi feito (abordagem, ferramentas, escopo)
3. O que foi encontrado (números concretos, resultado)

O Captain pode ler apenas o RESUMO e já ter contexto suficiente para decidir. Os ACHADOS e detalhes acima servem para aprofundar quando necessário.
