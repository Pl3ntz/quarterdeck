<p align="center">
  <img src="assets/logo-full.png" alt="Quarterdeck — Agent Orchestration for Claude Code" width="600">
</p>

<p align="center">
  <strong>The command bridge for Claude Code</strong><br>
  Turn Claude into a full engineering team with 26 specialized agents working in parallel.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#the-26-agents">Agents</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="docs/ARCHITECTURE.md">Architecture</a> &bull;
  <a href="docs/CUSTOMIZATION.md">Customization</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/agents-26-brightgreen.svg" alt="26 Agents">
  <img src="https://img.shields.io/badge/squads-8-orange.svg" alt="8 Squads">
  <img src="https://img.shields.io/badge/Claude_Code-2.1.32+-purple.svg" alt="Claude Code">
</p>

---

## What is Quarterdeck?

**Quarterdeck** is the command area of a ship — where the Captain coordinates the crew. In this project, **you are the Captain**.

[Claude Code](https://claude.ai/code) (Anthropic's CLI for AI-assisted development) operates as a single generic agent by default. Quarterdeck transforms it into a **team of 26 specialists** — each focused on one area (code review, security, testing, deployment, research, etc.) — working **in parallel**, like a real engineering squad.

### Before vs After

| Without Quarterdeck | With Quarterdeck |
|---|---|
| 1 generic agent does everything | 26 specialists, each doing what they're best at |
| Sequential execution (one thing at a time) | Parallel execution (3-5 agents simultaneously) |
| Unpredictable, freeform output | Standardized output (FINDINGS + SUMMARY) |
| No memory of past mistakes | Agents remember and warn about recurring errors |
| You manage everything manually | PE (Principal Engineer) orchestrates automatically |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Pl3ntz/quarterdeck.git

# 2. Copy agents to Claude Code
cp quarterdeck/agents/*.md ~/.claude/agents/

# 3. Copy orchestration rules
cp quarterdeck/rules/*.md ~/.claude/rules/

# 4. Start a new Claude Code session
claude
```

Claude Code auto-discovers agents in `~/.claude/agents/` and rules in `~/.claude/rules/`.

### Prerequisites

- [Claude Code](https://claude.ai/code) installed (`claude --version` ≥ 2.1.32)
- Anthropic account with Claude Code access (Pro, Max, or Team plan)

### Project Configuration

Create a `CLAUDE.md` at your project root to give agents context:

```markdown
# My Project

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16

## Services
- backend (port 8000)
- scheduler
```

> See [examples/project-config.md](examples/project-config.md) for a full template.

---

## How It Works

```
Captain (you) ──→ PE (Principal Engineer) ──→ 26 Agents
   decides            orchestrates              execute
```

| Role | Who | What they do |
|------|-----|-------------|
| **Captain** | **You** — the person using Claude Code | Give requests, approve plans, make decisions |
| **PE** | Claude Code with Quarterdeck rules | Interprets your request, picks which agents to use, coordinates parallel work, synthesizes results |
| **Agents** | 26 specialists (`.md` files) | Each executes a focused task and reports back to the PE |

**Absolute rule:** Agents never act on their own. The PE coordinates everything and presents results to you. You decide.

### Example

You say: _"Implement JWT authentication"_

The PE automatically decomposes into parallel waves:

```
Wave 1 — Reconnaissance (3 agents in parallel):
  ├── Explore: analyzes current auth code
  ├── Explore: checks existing tests
  └── deep-researcher: researches JWT best practices

Wave 2 — Planning (1 agent):
  └── planner: creates phased plan with risks

     → PE presents the plan → You approve ✓

Wave 3 — Implementation (1 agent):
  └── tdd-guide: writes tests first, then implements

     → PE shows the code → You review ✓

Wave 4 — Validation (2 agents in parallel):
  ├── code-reviewer: checks code quality
  └── security-reviewer: checks auth security

     → PE synthesizes results and presents to you
```

**Result:** What would take 4 sequential steps runs in 4 waves, with waves 1 and 4 running 3 and 2 agents **simultaneously**.

---

## The 26 Agents

Organized into 8 squads (functional teams):

### Planning & Design — think before building

| Agent | What it does | Model |
|-------|-------------|-------|
| [**architect**](agents/architect.md) | Designs architecture, evaluates trade-offs, proposes alternatives | Opus |
| [**planner**](agents/planner.md) | Creates implementation plans with phases, risks, and dependencies | Opus |

### Quality Gate — validate without modifying (always run in parallel)

| Agent | What it does | Model |
|-------|-------------|-------|
| [**code-reviewer**](agents/code-reviewer.md) | Reviews code for quality, bugs, and patterns | Sonnet |
| [**security-reviewer**](agents/security-reviewer.md) | Audits infrastructure security (SSH, firewall, SSL, databases) | Opus |
| [**ux-reviewer**](agents/ux-reviewer.md) | Checks accessibility, visual consistency, interaction states | Sonnet |
| [**staff-engineer**](agents/staff-engineer.md) | Evaluates cross-project impact and tech debt | Opus |

### Implementation — write code

| Agent | What it does | Model |
|-------|-------------|-------|
| [**tdd-guide**](agents/tdd-guide.md) | Implements with TDD (tests first, 80%+ coverage) | Sonnet |
| [**e2e-runner**](agents/e2e-runner.md) | Creates and runs end-to-end tests with Playwright | Sonnet |
| [**build-error-resolver**](agents/build-error-resolver.md) | Fixes build errors with minimal changes | Haiku |
| [**refactor-cleaner**](agents/refactor-cleaner.md) | Removes dead code and consolidates duplicates | Sonnet |

### Operations — keep the system running

| Agent | What it does | Model |
|-------|-------------|-------|
| [**incident-responder**](agents/incident-responder.md) | Diagnoses outages (doesn't execute — only recommends) | Opus |
| [**devops-specialist**](agents/devops-specialist.md) | CI/CD, automated deploys, systemd, monitoring | Sonnet |
| [**performance-optimizer**](agents/performance-optimizer.md) | Finds bottlenecks in CPU, memory, queries, cache | Sonnet |
| [**database-specialist**](agents/database-specialist.md) | PostgreSQL schema, slow queries, indexes, migrations | Sonnet |

### Intelligence — research and document

| Agent | What it does | Model |
|-------|-------------|-------|
| [**deep-researcher**](agents/deep-researcher.md) | Deep web research with source triangulation | Opus |
| [**doc-updater**](agents/doc-updater.md) | Generates documentation from actual code | Haiku |

### Language — review spelling and grammar

| Agent | What it does | Model |
|-------|-------------|-------|
| [**ortografia-reviewer**](agents/ortografia-reviewer.md) | PT-BR reviewer (spelling, grammar, agreement) | Sonnet |
| [**grammar-reviewer**](agents/grammar-reviewer.md) | EN-US reviewer (spelling, grammar, punctuation, style) | Sonnet |

### Strategy — SEO and recruiting

| Agent | What it does | Model |
|-------|-------------|-------|
| [**seo-reviewer**](agents/seo-reviewer.md) | Technical SEO + AI Search/GEO audit: Core Web Vitals, structured data, AI crawler management | Sonnet |
| [**tech-recruiter**](agents/tech-recruiter.md) | Tech recruiting: job descriptions, candidate evaluation, interviews | Sonnet |

### Editorial — content production with verified sources

Full professional editorial pipeline. All agents operate under the [Sourcing Discipline Protocol](rules/sourcing-discipline.md) — minimum 3-source triangulation, mandatory citations with URL and date.

| Agent | What it does | Model |
|-------|-------------|-------|
| [**editor-chefe**](agents/editor-chefe.md) | Editorial direction: story angle, editorial line, project approval | Opus |
| [**jornalista**](agents/jornalista.md) | Investigation, interviews, source triangulation, raw material | Sonnet |
| [**redator**](agents/redator.md) | Editorial writing: lead, narrative, voice and rhythm | Sonnet |
| [**escritor-tecnico**](agents/escritor-tecnico.md) | Technical writing: IMRAD, Diataxis, ADRs, design docs, post-mortems | Sonnet |
| [**fact-checker**](agents/fact-checker.md) | Independent verification (Rule of Two): 7 labels, 3+ source triangulation | Sonnet |
| [**editor-de-texto**](agents/editor-de-texto.md) | Final editing: cuts, lead/closing polish, legal language | Sonnet |

**Recommended pipeline:**
```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
  (assigns)     (reports)    (writes)   (verifies)     (polishes)        (proofreads)
```

> See [docs/AGENTS.md](docs/AGENTS.md) for the full catalog with tools and output examples.

---

## Standardized Output

Every agent returns in the same structured format:

```markdown
### FINDINGS (ordered by severity)
- **[CRITICAL]** SQL injection — `src/api/users.py:42` — Query uses string concatenation

### NEXT STEP: Fix the SQL injection before merging.

### SUMMARY: The users endpoint had a SQL injection risk that could
expose sensitive data. Analyzed all endpoints in the auth module
and verified query patterns. Found 1 CRITICAL vulnerability and 2
MEDIUM issues — both with suggested fixes.
```

The SUMMARY always follows the same logic: **system impact** → **how it was analyzed** → **concrete result with numbers**. You read it and immediately know what matters.

---

## Built-in Workflows

The PE automatically knows which workflow to use based on your request:

| When you say... | What happens |
|---|---|
| "Implement feature X" | planner → tdd-guide → code-reviewer + security-reviewer (parallel) |
| "Fix the login bug" | tdd-guide (reproduce + fix) → code-reviewer |
| "Refactor the auth module" | architect → refactor-cleaner → code-reviewer |
| "The system is down!" | incident-responder (diagnosis) → devops-specialist (deploy fix) |
| "Review PR #42" | code-reviewer + security-reviewer + ux-reviewer (parallel) |
| "Audit the project" | security-reviewer + performance-optimizer + code-reviewer (parallel) |

---

## Customization

### Change an agent's model

In the `.md` file frontmatter:

```yaml
model: opus    # Deep reasoning ($5/$25 per MTok)
model: sonnet  # Focused execution ($3/$15 per MTok) — best cost/quality
model: haiku   # Simple tasks ($1/$5 per MTok)
```

### Add/remove tools

```yaml
tools: Read, Grep, Glob, Bash    # Tools available to the agent
```

### Change language

Agents come configured for **pt-BR**. To change, edit the language rule in each agent's Output Format section.

> See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for the full guide.

---

## Documentation

| Document | What it covers |
|----------|---------------|
| [docs/AGENTS.md](docs/AGENTS.md) | Full catalog of 26 agents with tools and output |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture and request flow |
| [docs/CRAWLER-PROTOCOL.md](docs/CRAWLER-PROTOCOL.md) | How parallel wave execution works |
| [docs/OUTPUT-FORMAT.md](docs/OUTPUT-FORMAT.md) | Output format with per-agent examples |
| [docs/PATTERNS-APPLIED.md](docs/PATTERNS-APPLIED.md) | Patterns and techniques behind the project |
| [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) | How to adapt for your project |
| [docs/CONTINUOUS-LEARNING.md](docs/CONTINUOUS-LEARNING.md) | Automatic pattern capture and injection |

---

## FAQ

### Do I need all 26 agents?

No. Start with the 4 most useful: **code-reviewer**, **planner**, **tdd-guide**, and **deep-researcher**. Add others as needed.

### Does it work with any language/framework?

Yes. Agents are generic. They read your project's code and adapt. A `CLAUDE.md` at the project root helps provide context about your stack, conventions, and services.

### How much does it cost?

Quarterdeck itself is free (MIT). The cost is from Claude Code usage (Anthropic plan). Model distribution is optimized: simple agents use Haiku ($1/MTok), execution agents use Sonnet ($3/MTok), and only strategic ones use Opus ($5/MTok).

### Can I create my own agents?

Yes. Create a `.md` file in `~/.claude/agents/` following the template in [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md). Claude Code auto-discovers it.

### Does it work in VS Code / JetBrains?

Yes. Claude Code has extensions for VS Code and JetBrains. Quarterdeck agents work in any Claude Code interface (CLI, desktop app, IDE).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

```bash
# Fork → Branch → Commit → PR
git checkout -b feat/my-agent
git commit -m "feat: add agent X"
git push origin feat/my-agent
```

---

## License

MIT — see [LICENSE](LICENSE).

---

Created by [@Pl3ntz](https://github.com/Pl3ntz)
