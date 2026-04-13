# Arquitetura — Quarterdeck

## Visão Geral

O nome **Quarterdeck** vem da ponte de comando de um navio — o lugar onde o Captain toma decisões e coordena a tripulação. Neste sistema:

- **Captain** = você, a pessoa operando o Claude Code
- **PE** = o Claude Code atuando como seu Principal Engineer
- **Agentes** = 26 especialistas que executam tarefas sob coordenação do PE

```
Camada 1: Captain (Você)
  └── Decide, aprova, direciona

Camada 2: PE (Principal Engineer — sempre ativo)
  └── Orquestra agentes, sintetiza resultados, debate com você

Camada 3: 26 Agentes Especializados (8 Squads)
  └── Executam tarefas focadas, reportam ao PE
```

## Princípios de Design

### 1. Especialização > Generalização

Cada agente é especialista em UMA coisa. Um agente genérico que faz tudo produz resultados medianos. 26 especialistas produzem resultados profundos.

### 2. Paralelismo por Padrão

O Crawler Protocol define: **paralelo é o default, sequencial é a exceção**. Só vá sequencial quando há dependência real de dados.

### 3. Conflito é Prevenido, Não Resolvido

Agentes que escrevem código recebem **zonas exclusivas de arquivos** antes de serem spawned. Dois agentes nunca editam o mesmo arquivo na mesma wave.

### 4. Output Padronizado

Todos os agentes usam o formato de comunicação estruturada (impacto → abordagem → resultado). O PE consegue sintetizar outputs de múltiplos agentes rapidamente porque o formato é previsível.

### 5. Read Before Write

O Ground Truth Protocol garante que todo agente lê o código existente antes de analisar ou modificar. Isso elimina suposições e alucinações.

## Fluxo de uma Demanda Típica

```
Captain: "Implementa autenticação JWT no projeto X"
  │
  ▼
PE decompõe em waves:
  │
  ├── Wave 1 (PARALELO — reconhecimento):
  │   ├── Explore: estrutura atual do auth
  │   ├── Explore: testes existentes
  │   └── deep-researcher: best practices JWT 2026
  │
  ├── [PE sintetiza e apresenta ao Captain]
  │
  ├── Wave 2 (SEQUENCIAL — planejamento):
  │   └── planner: plano com fases e riscos
  │
  ├── [usuário aprova plano]
  │
  ├── Wave 3 (SEQUENCIAL — implementação):
  │   └── tdd-guide: testes primeiro, depois implementa
  │
  ├── [usuário revisa implementação]
  │
  └── Wave 4 (PARALELO — validação):
      ├── code-reviewer: qualidade e patterns
      └── security-reviewer: auth bypass, JWT security
```

## Distribuição de Responsabilidades

### Quem faz o quê (sem overlap)

| Responsabilidade | Agente | Quem NÃO faz |
|---|---|---|
| SQL injection, XSS, input validation | code-reviewer | security-reviewer |
| Infra hardening, firewall, systemd | security-reviewer | code-reviewer |
| Qualidade de código, naming, patterns | code-reviewer | ux-reviewer |
| Acessibilidade, spacing, focus states | ux-reviewer | code-reviewer |
| HOW to build (patterns, trade-offs) | architect | planner |
| IN WHAT ORDER to build (fases, riscos) | planner | architect |
| Unit + integration tests | tdd-guide | e2e-runner |
| E2E tests (Playwright) | e2e-runner | tdd-guide |
| Incidentes (REATIVO) | incident-responder | devops-specialist |
| CI/CD e deploy (PROATIVO) | devops-specialist | incident-responder |

## Modelo de Custos

A distribuição de modelos é otimizada por custo/qualidade:

- **Opus** (7) para raciocínio profundo: architect, planner, security-reviewer, incident-responder, staff-engineer, editor-chefe, deep-researcher
- **Sonnet** (16) para execução focada: code-reviewer, ux-reviewer, tdd-guide, e2e-runner, devops-specialist, performance-optimizer, database-specialist, refactor-cleaner, ortografia-reviewer, grammar-reviewer, tech-recruiter, jornalista, redator, escritor-tecnico, editor-de-texto, fact-checker
- **Haiku** (3) para tarefas simples: build-error-resolver, doc-updater, seo-reviewer

Essa distribuição economiza ~60% vs usar Opus em todos os agentes, com perda mínima de qualidade.
