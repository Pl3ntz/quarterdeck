<p align="center">
  <img src="assets/logo-full.png" alt="Quarterdeck — Agent Orchestration" width="600">
</p>

<p align="center">
  <strong>A ponte de comando para Claude Code</strong><br>
  Transforme o Claude em uma equipe completa de engenharia com 18 agentes especializados trabalhando em paralelo.
</p>

<p align="center">
  <a href="#instala%C3%A7%C3%A3o">Instalação</a> &bull;
  <a href="#os-18-agentes">Agentes</a> &bull;
  <a href="docs/ARCHITECTURE.md">Arquitetura</a> &bull;
  <a href="docs/CUSTOMIZATION.md">Customização</a> &bull;
  <a href="docs/PATTERNS-APPLIED.md">Padrões</a>
</p>

---

## O que é

**Quarterdeck** é a área de comando de um navio — onde o Captain coordena toda a tripulação. Neste projeto, **você é o Captain**.

O [Claude Code](https://claude.ai/code) (ferramenta CLI da Anthropic para desenvolvimento com IA) por padrão opera como um único agente genérico. O Quarterdeck transforma ele em uma **equipe de 18 especialistas** — cada um focado em uma área (code review, segurança, testes, deploy, pesquisa, etc.) — que trabalham **em paralelo**, como uma squad real de desenvolvedores.

### Antes vs Depois

| Sem Quarterdeck | Com Quarterdeck |
|---|---|
| 1 agente genérico faz tudo | 18 especialistas, cada um no que é bom |
| Execução sequencial (1 coisa por vez) | Execução paralela (3-5 agentes simultaneamente) |
| Output livre e imprevisível | Output padronizado (ACHADOS + RESUMO) |
| Sem memória de erros passados | Agentes lembram e avisam sobre erros recorrentes |
| Você gerencia tudo manualmente | PE (Principal Engineer) orquestra automaticamente |

---

## Como funciona

### Quem é quem

```
Captain (você) ──→ PE (Principal Engineer) ──→ 18 Agentes
   decide              coordena                  executam
```

| Papel | Quem é | O que faz |
|-------|--------|-----------|
| **Captain** | **Você** — a pessoa usando o Claude Code | Dá demandas, aprova planos, toma decisões |
| **PE** | O Claude Code com as rules do Quarterdeck | Interpreta sua demanda, escolhe quais agentes usar, coordena trabalho em paralelo, sintetiza resultados |
| **Agentes** | 18 especialistas (arquivos `.md`) | Cada um executa uma tarefa focada e reporta ao PE |

**Regra absoluta:** Agentes nunca agem sozinhos. O PE coordena tudo e apresenta a você. Você decide.

### Exemplo prático

Você diz: _"Implementa autenticação JWT no projeto"_

O PE automaticamente decompõe em ondas paralelas:

```
Wave 1 — Reconhecimento (3 agentes em paralelo):
  ├── Explore: analisa o código atual de autenticação
  ├── Explore: verifica testes existentes
  └── deep-researcher: pesquisa best practices JWT 2026

Wave 2 — Planejamento (1 agente):
  └── planner: cria plano com fases e riscos

     → PE apresenta o plano a você → Você aprova ✓

Wave 3 — Implementação (1 agente):
  └── tdd-guide: escreve testes primeiro, depois implementa

     → PE mostra o código a você → Você revisa ✓

Wave 4 — Validação (2 agentes em paralelo):
  ├── code-reviewer: verifica qualidade do código
  └── security-reviewer: verifica segurança da autenticação

     → PE sintetiza os resultados e apresenta a você
```

**Resultado:** O que levaria 4 etapas sequenciais acontece em 4 ondas, com as ondas 1 e 4 rodando 3 e 2 agentes **simultaneamente**.

---

## Os 18 Agentes

Organizados em 6 squads (equipes funcionais):

### Planning & Design — pensam antes de fazer

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **architect** | Projeta arquitetura, avalia trade-offs, propõe alternativas | Opus |
| **planner** | Cria planos de implementação com fases, riscos e dependências | Opus |

### Quality Gate — validam sem modificar (sempre rodam em paralelo)

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **code-reviewer** | Revisa código por qualidade, bugs e padrões | Sonnet |
| **security-reviewer** | Audita segurança de infraestrutura (SSH, firewall, SSL, banco) | Opus |
| **ux-reviewer** | Verifica acessibilidade, consistência visual, estados de interação | Sonnet |
| **staff-engineer** | Avalia impacto em outros projetos e dívida técnica | Opus |

### Implementation — escrevem código

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **tdd-guide** | Implementa com TDD (testes primeiro, cobertura 80%+) | Sonnet |
| **e2e-runner** | Cria e roda testes end-to-end com Playwright | Sonnet |
| **build-error-resolver** | Corrige erros de build com mudanças mínimas | Haiku |
| **refactor-cleaner** | Remove código morto e consolida duplicatas | Sonnet |

### Operations — mantêm o sistema rodando

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **incident-responder** | Diagnostica quando o sistema cai (não executa — só recomenda) | Opus |
| **devops-specialist** | CI/CD, deploy automatizado, systemd, monitoramento | Sonnet |
| **performance-optimizer** | Encontra gargalos em CPU, memória, queries, cache | Sonnet |
| **database-specialist** | Schema PostgreSQL, queries lentas, índices, migrations | Sonnet |

### Intelligence — pesquisam e documentam

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **deep-researcher** | Pesquisa profunda na web com triangulação de fontes | Opus |
| **doc-updater** | Gera documentação a partir do código real | Haiku |

### Language — revisam ortografia e gramática

| Agente | O que faz | Modelo |
|--------|-----------|--------|
| **ortografia-reviewer** | Revisor PT-BR nível ENEM nota 1000 (ortografia, gramática, concordância, regência, crase) | Sonnet |
| **grammar-reviewer** | Revisor EN-US nível GRE score 6/6 (spelling, grammar, punctuation, style) | Sonnet |

> Veja [docs/AGENTS.md](docs/AGENTS.md) para o catálogo completo com ferramentas e exemplos de output.

---

## Instalação

### Pré-requisitos

- [Claude Code](https://claude.ai/code) instalado (`claude --version` ≥ 2.1.32)
- Conta na Anthropic com acesso ao Claude Code (plano Pro, Max ou Team)

### Passo a passo

```bash
# 1. Clone o repositório
git clone https://github.com/Pl3ntz/quarterdeck.git

# 2. Copie os agentes para o Claude Code
cp quarterdeck/agents/*.md ~/.claude/agents/

# 3. Copie as rules de orquestração
cp quarterdeck/rules/*.md ~/.claude/rules/

# 4. Pronto! Inicie uma nova sessão do Claude Code
claude
```

O Claude Code detecta automaticamente os agentes em `~/.claude/agents/` e as rules em `~/.claude/rules/`.

### Configuração do seu projeto

Crie um `CLAUDE.md` na raiz do seu projeto para dar contexto aos agentes:

```markdown
# Meu Projeto

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16

## Serviços
- backend (porta 8000)
- scheduler
```

> Veja [examples/project-config.md](examples/project-config.md) para um template completo.

---

## Como o output funciona

Todo agente retorna no mesmo formato padronizado:

```markdown
### ACHADOS (ordenados por severidade)
- **[CRITICAL]** SQL injection — `src/api/users.py:42` — Query usa concatenação de string

### PRÓXIMO PASSO: Corrigir o SQL injection antes do merge.

### RESUMO: O endpoint de usuários tinha risco de SQL injection que poderia
expor dados sensíveis. Analisei todos os endpoints do módulo de autenticação
e verifiquei padrões de query. Encontrei 1 vulnerabilidade CRITICAL e 2
issues MEDIUM — ambos com correção sugerida.
```

O RESUMO sempre segue a mesma lógica: **impacto no sistema** → **como foi analisado** → **resultado concreto com números**. Você lê e já sabe o que importa.

---

## Workflows prontos

O PE sabe automaticamente qual workflow usar baseado na sua demanda:

| Quando você diz... | O que acontece |
|---|---|
| "Implementa feature X" | planner → tdd-guide → code-reviewer + security-reviewer (paralelo) |
| "Corrige o bug do login" | tdd-guide (reproduz + corrige) → code-reviewer |
| "Refatora o módulo de auth" | architect → refactor-cleaner → code-reviewer |
| "O sistema caiu!" | incident-responder (diagnóstico) → devops-specialist (deploy fix) |
| "Review do PR #42" | code-reviewer + security-reviewer + ux-reviewer (paralelo) |
| "Audita o projeto" | security-reviewer + performance-optimizer + code-reviewer (paralelo) |

---

## Customização

### Trocar modelo de um agente

No frontmatter do arquivo `.md`:

```yaml
model: opus    # Raciocínio profundo ($5/$25 por MTok)
model: sonnet  # Execução focada ($3/$15 por MTok) — melhor custo/qualidade
model: haiku   # Tarefas simples ($1/$5 por MTok)
```

### Adicionar/remover ferramentas

```yaml
tools: Read, Grep, Glob, Bash    # Ferramentas disponíveis para o agente
```

### Trocar idioma

Os agentes vêm configurados para **pt-BR**. Para mudar, edite a regra de idioma no Output Format de cada agente.

> Veja [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) para o guia completo.

---

## Documentação

| Documento | O que cobre |
|-----------|-------------|
| [docs/AGENTS.md](docs/AGENTS.md) | Catálogo completo dos 16 agentes com ferramentas e output |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura do sistema e fluxo de uma demanda |
| [docs/CRAWLER-PROTOCOL.md](docs/CRAWLER-PROTOCOL.md) | Como funciona a execução paralela por ondas |
| [docs/OUTPUT-FORMAT.md](docs/OUTPUT-FORMAT.md) | Formato de output com exemplos por agente |
| [docs/PATTERNS-APPLIED.md](docs/PATTERNS-APPLIED.md) | Padrões e técnicas que fundamentam o projeto |
| [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) | Como adaptar para seu projeto |

---

## FAQ

### Preciso usar todos os 16 agentes?

Não. Comece com os 4 mais úteis: **code-reviewer**, **planner**, **tdd-guide**, e **deep-researcher**. Adicione outros conforme sentir necessidade.

### Funciona com qualquer linguagem/framework?

Sim. Os agentes são genéricos. Eles leem o código do seu projeto e se adaptam. O `CLAUDE.md` na raiz do projeto ajuda a dar contexto sobre stack, convenções e serviços.

### Quanto custa?

O Quarterdeck em si é gratuito (MIT). O custo é do uso do Claude Code (plano Anthropic). A distribuição de modelos é otimizada: agentes simples usam Haiku ($1/MTok), agentes de execução usam Sonnet ($3/MTok), e só os estratégicos usam Opus ($5/MTok).

### Posso criar meus próprios agentes?

Sim. Crie um arquivo `.md` em `~/.claude/agents/` seguindo o template em [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md). O Claude Code detecta automaticamente.

### Funciona no VS Code / JetBrains?

Sim. O Claude Code tem extensões para VS Code e JetBrains. Os agentes do Quarterdeck funcionam em qualquer interface do Claude Code (CLI, desktop, IDE).

---

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para o guia completo.

```bash
# Fork → Branch → Commit → PR
git checkout -b feat/meu-agente
git commit -m "feat: adiciona agente X"
git push origin feat/meu-agente
```

---

## Licença

MIT — veja [LICENSE](LICENSE).

---

Criado por [@Pl3ntz](https://github.com/Pl3ntz)
