<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-full-dark.png">
    <img src="assets/logo-full.png" alt="Quarterdeck: Agent Orchestration for Claude Code" width="600">
  </picture>
</p>

<p align="center">
  <strong>The command bridge for Claude Code</strong><br>
  A squad of specialists, and the guardrails that stop them from shipping something wrong.
</p>

<p align="center">
  <a href="#what-it-enforces">What it enforces</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#the-26-agents">Agents</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="docs/ARCHITECTURE.md">Architecture</a> &bull;
  <a href="docs/CUSTOMIZATION.md">Customization</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="NOTICE.md"><img src="https://img.shields.io/badge/notice-third--party-yellow.svg" alt="Third-Party Notice"></a>
  <img src="https://img.shields.io/badge/agents-26-brightgreen.svg" alt="26 Agents">
  <img src="https://img.shields.io/badge/guardrail_checks-49-red.svg" alt="49 Guardrail Checks">
  <img src="https://img.shields.io/badge/agents_with_measured_baselines-15-blue.svg" alt="15 Agents Measured">
  <img src="https://img.shields.io/badge/Claude_Code-2.1.32+-purple.svg" alt="Claude Code">
</p>

---

## What is Quarterdeck?

**Quarterdeck** is the command area of a ship, where the Captain coordinates the crew. In this project, **you are the Captain**.

[Claude Code](https://claude.ai/code) (Anthropic's CLI for AI-assisted development) operates as a single generic agent by default. Quarterdeck transforms it into a **team of 26 specialists**, each focused on one area (code review, security, testing, deployment, research, etc.), working **in parallel**, like a real engineering squad.

### Before vs After

| Without Quarterdeck | With Quarterdeck |
|---|---|
| One generic agent does everything | Specialists, each scoped to what it is good at |
| Sequential execution | Parallel execution, with write-agents isolated in their own worktree |
| Freeform output | Findings with file and line, so a claim can be checked |
| A destructive command runs because you did not read it closely | A gate refuses it and says which rule caught it |
| Code ships unreviewed when you are moving fast | The commit is blocked until this exact diff has been reviewed |
| A secret or a client's data reaches a public repo | Blocked at commit, and on the way out through fetch, search and MCP |
| An agent's prompt is edited and nobody knows if it got worse | The commit is blocked until its eval has been re-run on that version |

The second half of that table is the part most agent collections do not have. Prompts are
easy to copy; the checks that catch a bad one are not.

---

## What it enforces

Agent definitions are prompts, and prompts are easy to copy. These are the parts that run.

### Gates on `git commit`

| Gate | Refuses when | Cost |
|---|---|---|
| `review-gate` | staged code has no review for **this exact diff**, or the review found a CRITICAL | none at commit; the review runs when you choose |
| `eval-gate` | an agent's prompt changed and its stability report is older than the edit | none |
| `suite-gate` | the guardrail suite fails against the files **being committed** | 21s |
| `test-gate` | nothing ran the test suite this session | none |

Each keys on a hash or a timestamp, so a review or an eval stops counting the moment the
thing it described changes. Every gate has a named override, because a gate that blocks
everything trains you to disable it.

### Gates on execution

| Gate | Refuses |
|---|---|
| `production-gate` | anything that modifies a production host over SSH; read-only passes through |
| `block-build` | heavy builds on the host and on the server, where they compete with running services |
| `egress-guard` | validated PII, secrets or infrastructure identifiers leaving through fetch, search or an MCP tool |

The leak guard covers commits. `egress-guard` covers everything else, because committing was
never the only way data leaves.

### The suite

```bash
scripts/test-guardrails.sh -v          # 49 checks, no model calls
HOOKS=./hooks scripts/test-guardrails.sh   # test what you are about to ship
```

A guardrail without a test is a claim. Two of these silently failed **open** for months --
a literal `~` in `cd ~/repo` was never expanded, so every path check inside them missed --
and nothing noticed, because nothing executed them. The suite asserts the decision each hook
returns, for both path forms, and one commit here turned out to describe a fix its own diff
did not contain.

## What it measures

```bash
scripts/agent-usage-report.py --report --days 30
```

Cost and volume per (agent, model), read from `attributionAgent` in the session transcripts.
Native OpenTelemetry collapses every user-defined agent into `agent.name="custom"`, so this
is the only view that distinguishes them.

15 of the agents have K=5 stability baselines from `scripts/eval/`. The runners ship; the
fixtures deliberately do not, since `expected-findings.md` is the answer key and publishing
it would contaminate the benchmark.

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
| **Captain** | **You**, the person using Claude Code | Give requests, approve plans, make decisions |
| **PE** | Claude Code with Quarterdeck rules | Interprets your request, picks which agents to use, coordinates parallel work, synthesizes results |
| **Agents** | 26 specialists (`.md` files) | Each executes a focused task and reports back to the PE |

**Absolute rule:** Agents never act on their own. The PE coordinates everything and presents results to you. You decide.

### Example

You say: _"Implement JWT authentication"_

The PE automatically decomposes into parallel waves:

```
Wave 1: Reconnaissance (3 agents in parallel):
  ├── Explore: analyzes current auth code
  ├── Explore: checks existing tests
  └── deep-researcher: researches JWT best practices

Wave 2: Planning (1 agent):
  └── planner: creates phased plan with risks

     → PE presents the plan → You approve ✓

Wave 3: Implementation (1 agent):
  └── tdd-guide: writes tests first, then implements

     → PE shows the code → You review ✓

Wave 4: Validation (2 agents in parallel):
  ├── code-reviewer: checks code quality
  └── security-reviewer: checks auth security

     → PE synthesizes results and presents to you
```

**Result:** What would take 4 sequential steps runs in 4 waves, with waves 1 and 4 running 3 and 2 agents **simultaneously**.

---

## The 26 Agents

Organized into 8 squads (functional teams):

### Planning & Design: think before building

| Agent | What it does | Model |
|-------|-------------|-------|
| [**architect**](agents/architect.md) | Designs architecture, evaluates trade-offs, proposes alternatives | Opus |
| [**planner**](agents/planner.md) | Creates implementation plans with phases, risks, and dependencies | Opus |

### Quality Gate: validate without modifying (always run in parallel)

| Agent | What it does | Model |
|-------|-------------|-------|
| [**code-reviewer**](agents/code-reviewer.md) | Reviews code for quality, bugs, and patterns | Sonnet |
| [**security-reviewer**](agents/security-reviewer.md) | Audits infrastructure security (SSH, firewall, SSL, databases) | Opus |
| [**ux-reviewer**](agents/ux-reviewer.md) | Checks accessibility, visual consistency, interaction states | Sonnet |
| [**staff-engineer**](agents/staff-engineer.md) | Evaluates cross-project impact and tech debt | Opus |

### Implementation: write code

| Agent | What it does | Model |
|-------|-------------|-------|
| [**tdd-guide**](agents/tdd-guide.md) | Implements with TDD (tests first, 80%+ coverage) | Sonnet |
| [**e2e-runner**](agents/e2e-runner.md) | Creates and runs end-to-end tests with Playwright | Sonnet |
| [**build-error-resolver**](agents/build-error-resolver.md) | Fixes build errors with minimal changes | Haiku |
| [**refactor-cleaner**](agents/refactor-cleaner.md) | Removes dead code and consolidates duplicates | Sonnet |

### Operations: keep the system running

| Agent | What it does | Model |
|-------|-------------|-------|
| [**incident-responder**](agents/incident-responder.md) | Diagnoses outages (doesn't execute, only recommends) | Opus |
| [**devops-specialist**](agents/devops-specialist.md) | CI/CD, automated deploys, systemd, monitoring | Sonnet |
| [**performance-optimizer**](agents/performance-optimizer.md) | Finds bottlenecks in CPU, memory, queries, cache | Sonnet |
| [**database-specialist**](agents/database-specialist.md) | PostgreSQL schema, slow queries, indexes, migrations | Sonnet |

### Intelligence: research and document

| Agent | What it does | Model |
|-------|-------------|-------|
| [**deep-researcher**](agents/deep-researcher.md) | Deep web research with source triangulation | Opus |
| [**doc-updater**](agents/doc-updater.md) | Generates documentation from actual code | Haiku |

### Language: review spelling and grammar

| Agent | What it does | Model |
|-------|-------------|-------|
| [**ortografia-reviewer**](agents/ortografia-reviewer.md) | PT-BR reviewer (spelling, grammar, agreement) | Sonnet |
| [**grammar-reviewer**](agents/grammar-reviewer.md) | EN-US reviewer (spelling, grammar, punctuation, style) | Sonnet |

### Strategy: SEO and recruiting

| Agent | What it does | Model |
|-------|-------------|-------|
| [**seo-reviewer**](agents/seo-reviewer.md) | Technical SEO + AI Search/GEO audit: Core Web Vitals, structured data, AI crawler management | Sonnet |
| [**tech-recruiter**](agents/tech-recruiter.md) | Tech recruiting: job descriptions, candidate evaluation, interviews | Sonnet |

### Editorial: content production with verified sources

Full professional editorial pipeline. All agents operate under the [Sourcing Discipline Protocol](rules/sourcing-discipline.md): minimum 3-source triangulation, mandatory citations with URL and date.

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

## Companion Skills & Scripts

Beyond the 26 agents, Quarterdeck ships with one skill and four utility scripts vendored from [borghei/Claude-Skills](https://github.com/borghei/Claude-Skills) (see [NOTICE.md](NOTICE.md) for license attribution).

### Skill

| Skill | Purpose |
|---|---|
| [**skill-security-auditor**](skills/skill-security-auditor/) | Pre-install gate for untrusted skills/plugins. Detects `eval`/`exec`/`subprocess`, network exfiltration, credential harvesting, prompt injection. Use before installing any third-party skill. |

### Utility Scripts

Installed under `~/.claude/scripts/borghei/` and `~/.claude/scripts/improvement/`:

| Script | Purpose |
|---|---|
| `borghei/claudemd_optimizer.py` | Analyze a `CLAUDE.md` file: token estimate, completeness score, structural recommendations. |
| `borghei/context_analyzer.py` | Estimate context window usage across a project. Identifies the heaviest files to read with `offset/limit`. |
| `improvement/rule_promoter.py` | Promote validated patterns from `MEMORY.md` to permanent rules. **Hardened**: sanitizer rejects prompt-injection markers, shell tokens, non-https URLs. Default writes to a candidate review file; direct rule writes require interactive TTY confirmation. |
| `improvement/memory_health_checker.py` | Audit memory for stale, duplicate, or promotable entries. Reports the Improvement Maturity Level. |

### Conceptual Frameworks (PE Rule Sections 17-19)

Three orchestration patterns documented in the [PE rule](rules/principal-engineer-always-on.md):

- **Improvement Maturity Levels** (0-5): self-assessment scale for any continuous-learning behavior.
- **Promotion Criteria Matrix**: explicit thresholds (recurrence, consistency, impact, stability, clarity) before any pattern graduates to a permanent rule.
- **Skill Chain Pattern**: pure pipelines without PE judgment between steps, for repeatable automation where consistency matters more than discretion.

---

## Standardized Output

Every agent returns the same structure: findings ordered by severity, then one next step.

```markdown
### FINDINGS (ordered by severity)
- **[CRITICAL]** SQL injection — `src/api/users.py:42` — query built by string concatenation
- **[MEDIUM]** Missing index on `users.email` — `migrations/003.sql:12`

### NEXT STEP: Fix the SQL injection before merging.
```

Findings carry a file and line, so they are checkable rather than assertable. There is no
trailing summary section: Claude Code's own recap already covers the end of a session, and a
second hand-written one was removed in 2026-07-25 for contradicting the output rules.

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
model: sonnet  # Focused execution ($3/$15 per MTok), best cost/quality
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

No, and measurement says most people will not use most of them. Over 45 days of real use
here, four agents accounted for roughly half of all spawns, and eight were never invoked
once. An unused agent still costs tokens in every session, because the Agent tool injects
every agent's description whether or not you spawn it.

Start with **code-reviewer**, **security-reviewer**, **deep-researcher** and **tdd-guide**,
and add one when you notice yourself wanting it. `scripts/agent-usage-report.py` will tell
you which ones you actually reach for.

### Does it work with any language/framework?

Yes. Agents are generic. They read your project's code and adapt. A `CLAUDE.md` at the project root helps provide context about your stack, conventions, and services.

### How much does it cost?

Quarterdeck is MIT. The cost is Claude Code usage, and the tier per agent is set in its
frontmatter: Haiku for mechanical work, Sonnet for implementation and review, Opus for the
agents where a miss is expensive.

Two things measurement here changed about that answer. Most spend does not come from the
named agents at all -- it comes from generic workflow and general-purpose agents, which
inherit the session's model and multiply it by however many run in parallel, so pinning a
cheap tier on mechanical workflow stages matters more than the frontmatter of any single
agent. And Haiku's knowledge cutoff is old enough that it should not be writing code, whatever
it saves.

`scripts/agent-usage-report.py` gives you the real split rather than the intended one.

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

MIT. See [LICENSE](LICENSE).

Quarterdeck also bundles components vendored from third parties under their original licenses (MIT and MIT + Commons Clause). See [NOTICE.md](NOTICE.md) for the full license map and modifications log. The Commons Clause does not restrict personal use, modification, or non-commercial redistribution, only commercial resale of the vendored components.

---

Created by [@Pl3ntz](https://github.com/Pl3ntz)
