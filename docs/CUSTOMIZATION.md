# Customization Guide

[← back to README](../README.md)

Quarterdeck is built for customization. Adapt agents, rules, and project configuration to fit your needs.

---

## Quick Customization Checklist

- [ ] Change an agent's model (cost optimization)
- [ ] Add/remove tools for an agent
- [ ] Change language (pt-BR to English or vice versa)
- [ ] Create a new custom agent
- [ ] Configure project context (`CLAUDE.md`)

---

## 1. Change an Agent's Model

Each agent's **model** determines its reasoning depth and cost. Edit the `.md` file frontmatter in `~/.claude/agents/`.

### Available Models

| Model | Cost | Best for | Reasoning | Token limit |
|-------|------|----------|-----------|------------|
| **opus** | $5/$25 per MTok | Strategic decisions, deep reasoning, architecture | 99-level thinking | 200K–1M context |
| **sonnet** | $3/$15 per MTok | Code review, implementation, general-purpose | 10-level thinking | 200K context |
| **haiku** | $1/$5 per MTok | Simple tasks, lookups, documentation generation | 1-level thinking | 200K context |

### Example: Downgrade code-reviewer to save costs

**Before** (agents/code-reviewer.md):
```yaml
---
name: code-reviewer
model: sonnet
color: cyan
---
```

**After** (cost-optimized):
```yaml
---
name: code-reviewer
model: haiku
color: cyan
---
```

**Note:** Haiku is less capable. Use only for trivial code reviews. For production use, keep Sonnet.

### Example: Upgrade architect to Opus[1m]

For extended context window (1 million tokens) on projects with large codebases:

```yaml
---
name: architect
model: opus[1m]
color: blue
---
```

---

## 2. Add or Remove Tools

Tools define what an agent can do. Edit the `tools:` field in the frontmatter.

### Available Tools

| Tool | What it does |
|------|-------------|
| **Read** | Read files from local filesystem |
| **Write** | Write new files |
| **Edit** | Edit existing files (diff-based) |
| **Bash** | Execute shell commands |
| **Grep** | Search file contents |
| **Glob** | List files matching patterns |
| **WebSearch** | Search the web (only for agents with research role) |
| **WebFetch** | Fetch full HTML from URLs (only for agents with research role) |
| **Skill(local-mind:super-search)** | Advanced memory recall (optional, for quality-gate agents) |

### Example: Add WebFetch to a custom research agent

```yaml
---
name: my-researcher
tools: Read, WebSearch, WebFetch, Bash, Grep, Glob
model: opus
color: neutral
---
```

### Example: Remove Bash from a read-only reviewer

```yaml
---
name: my-reviewer
tools: Read, Grep, Glob
model: sonnet
color: cyan
---
```

---

## 3. Change Language

Agents come configured for **Portuguese (pt-BR)**. To change the output language, edit the **Output Format** section near the end of each agent's `.md` file.

### Example: Switch code-reviewer to English

Find this section in `agents/code-reviewer.md`:

```markdown
## Output Format

Output in Portuguese (pt-BR): SEMPRE pt-BR, exceto se Owner pedir inglês explicitamente.
- **Achados** → **[CRITICAL|HIGH|MEDIUM|LOW]** [título]
- Use markdown sections, bullets, tables
```

Change to:

```markdown
## Output Format

Output in English: ALWAYS English for this agent.
- **Findings** → **[CRITICAL|HIGH|MEDIUM|LOW]** [title]
- Use markdown sections, bullets, tables
```

Then update all Portuguese text in the agent's system prompt accordingly (ex: "Especialista em code review" → "Code review specialist").

---

## 4. Create a Custom Agent

Create a new `.md` file in `~/.claude/agents/` following this template.

### Agent Template

```yaml
---
name: my-agent-name
description: Short description of what this agent does
tools: Read, Bash, Grep, Glob
model: sonnet
color: cyan
---

# My Custom Agent

You are a specialist in [your domain].

[... rest of your system prompt ...]

## Output Format

Output in Portuguese (pt-BR):
- **Achados** → **[CRITICAL|HIGH|MEDIUM|LOW]** [título]
- Explicação concisa do problema
- Use markdown: titles (##), bullets, tables, code blocks
- Target: ≤ 200 tokens

### Example Output

```
### ACHADOS
- **[HIGH]** Unhandled exception in auth module — `src/api/auth.py:142` — add try-catch

### PRÓXIMO PASSO: Add error handling before next deploy.
```
```

### Step-by-Step

1. **Choose a name** (lowercase, hyphenated): `my-agent-name`
2. **Write a 1-line description** of what it does
3. **Pick tools** from the available list (comma-separated)
4. **Pick a model**: opus (reasoning), sonnet (balance), haiku (speed)
5. **Pick a color** for CLI display (cyan, red, blue, yellow, gray, green, etc.)
6. **Write the system prompt** (copy from an existing agent and adapt)
7. **Define output format** (follow the ACHADOS/PRÓXIMO PASSO pattern)
8. **Save** to `~/.claude/agents/my-agent-name.md`
9. **Claude Code auto-discovers it** — no restart needed

### Example: Create a Python-specific code reviewer

```yaml
---
name: python-reviewer
description: Specialist in Python code style, type hints, and best practices
tools: Read, Bash, Grep, Glob
model: sonnet
color: cyan
---

# Python Code Reviewer

You are a senior Python reviewer specializing in PEP 8, type hints, async/await patterns, and performance.

## Output Format

Output in Portuguese (pt-BR):
- **Achados** → **[CRITICAL|HIGH|MEDIUM|LOW]** [título] — `file:line`
- List issues found
- Use markdown, target ≤ 200 tokens

### Example Output

```
### ACHADOS
- **[MEDIUM]** Missing type hint on function — `src/app.py:45` — add `def process(data: str) -> dict:`
- **[LOW]** Could use f-string instead of .format() — `src/utils.py:12`

### PRÓXIMO PASSO: Add type hints to public API functions.
```
```

---

## 5. Configure Project Context

Create a `CLAUDE.md` file at your **project root** to give agents context about your stack, services, and conventions.

### Minimal CLAUDE.md

```markdown
# my-project

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16

## Key Directories
- `backend/` - API code
- `frontend/` - UI code
- `scripts/` - Automation

## Conventions
- Type hints required on all public functions
- Async/await for I/O operations
- Tests in `tests/` mirroring code structure
```

### Full CLAUDE.md (with services and deploy)

```markdown
# my-project

## Server
- **Host**: your-server (ssh your-server)
- **Path**: /path/to/project

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16
- Cache: Redis

## Services

| Service | Unit | Port | Health |
|---------|------|------|--------|
| backend | my-app-backend | 8000 | /api/health |
| scheduler | my-app-scheduler | — | systemctl status |
| cache | redis-server | 6379 | redis-cli ping |

## Deploy
- Flow: git pull → pip install → alembic upgrade head → systemctl restart my-app-backend
- Rollback: revert commit → systemctl restart my-app-backend

## Key Directories
- `backend/` - API and business logic
- `frontend/` - React components
- `migrations/` - Alembic migrations
- `tests/` - Unit and integration tests

## Conventions
- Type hints required (mypy strict mode)
- Async/await for I/O
- Tests required for all public functions
- Commit messages: `type: description` (feat, fix, refactor, etc.)
- PR labels: breaking, feature, bugfix, docs
```

### Where to place CLAUDE.md

- **For local projects**: `/path/to/your-project/CLAUDE.md`
- **For remote projects (ssh)**: `/path/on/server/CLAUDE.md`

Agents read this automatically to understand your project context.

---

## 6. Copy Quarterdeck Rules to Your Setup

Rules define global behavior (testing, security, output format, git workflow). Copy them from Quarterdeck to your Claude Code setup:

```bash
# Copy all rules
cp quarterdeck/rules/*.md ~/.claude/rules/

# Or selectively:
cp quarterdeck/rules/testing.md ~/.claude/rules/
cp quarterdeck/rules/security.md ~/.claude/rules/
cp quarterdeck/rules/principal-engineer-always-on.md ~/.claude/rules/
```

### Key Rules to Know

| Rule | Purpose |
|------|---------|
| `principal-engineer-always-on.md` | PE orchestration, agent squad model, workflow chains |
| `zero-assumption-protocol.md` | Mandatory reasoning discipline (verify, don't assume) |
| `output-discipline.md` | Standardized output format (concise, no filler) |
| `testing.md` | Test coverage requirements (80%+ minimum) |
| `security.md` | Security checklist before commits |
| `git-workflow.md` | Conventional commits, PR workflow |
| `production-gate-mandatory.md` | Step-by-step approval for production changes |
| `coding-style.md` | Immutability, file organization, error handling |

---

## 7. Customize Rules for Your Project

Edit rules in `~/.claude/rules/` to match your team's standards.

### Example: Adjust test coverage threshold

**File**: `~/.claude/rules/testing.md`

**Before**:
```markdown
## Minimum Test Coverage: 80%
```

**After**:
```markdown
## Minimum Test Coverage: 90%
```

### Example: Add company-specific security checklist

**Edit**: `~/.claude/rules/security.md`

**Add**:
```markdown
## Company-Specific Checks

Before ANY commit:
- [ ] No hardcoded API keys (use AWS Secrets Manager)
- [ ] All user inputs validated with Zod
- [ ] HIPAA-compliant data handling (PII not in logs)
```

---

## 8. Model Cost Estimation

Quick reference for choosing models by task:

| Task | Recommended | Cost |
|------|-------------|------|
| Code review | sonnet | $3/$15 per MTok |
| Implement feature | tdd-guide (sonnet) | $3/$15 per MTok |
| Audit security | security-reviewer (opus) | $5/$25 per MTok |
| Plan architecture | architect (opus) | $5/$25 per MTok |
| Fix build error | build-error-resolver (haiku) | $1/$5 per MTok |
| Update docs | doc-updater (haiku) | $1/$5 per MTok |

**Tip:** Start with Haiku for simple tasks, Sonnet for normal work, Opus for deep reasoning.

---

## 9. Common Customization Patterns

### Pattern: Minimal Setup (5 agents)

Copy only the agents you need:

```bash
cp quarterdeck/agents/code-reviewer.md ~/.claude/agents/
cp quarterdeck/agents/tdd-guide.md ~/.claude/agents/
cp quarterdeck/agents/planner.md ~/.claude/agents/
cp quarterdeck/agents/deep-researcher.md ~/.claude/agents/
cp quarterdeck/agents/build-error-resolver.md ~/.claude/agents/
```

### Pattern: Cost Optimization

Downgrade non-critical agents to Haiku:

```yaml
# doc-updater
model: haiku

# build-error-resolver
model: haiku

# Keep sonnet for code-reviewer and tdd-guide
# Keep opus for architect, planner, security-reviewer
```

### Pattern: Portuguese Monolingual Team

All agents output Portuguese. No changes needed — agents default to pt-BR.

### Pattern: English Monolingual Team

Switch all agents to English by editing each agent's Output Format section:

```markdown
## Output Format

Output in English (EN-US):
- **Findings** → **[CRITICAL|HIGH|MEDIUM|LOW]** [title]
- Brief explanation
```

### Pattern: Custom Agent for Your Framework

Create framework-specific agents (ex: Next.js, Django, Rust):

```bash
# Create
cat > ~/.claude/agents/nextjs-reviewer.md << 'EOF'
---
name: nextjs-reviewer
description: Next.js specialist for App Router, RSC, middleware, and performance
tools: Read, Bash, Grep, Glob
model: sonnet
color: cyan
---

[... rest of system prompt ...]
EOF
```

---

## 10. Verify Your Setup

After customization, verify agents are discoverable:

```bash
# List agents in Claude Code
ls ~/.claude/agents/

# Check that CLAUDE.md is at project root
ls /path/to/your-project/CLAUDE.md

# Confirm rules are loaded
ls ~/.claude/rules/
```

When you start Claude Code, agents auto-discover from `~/.claude/agents/` and rules from `~/.claude/rules/`.

---

## Troubleshooting

**Q: Agent not showing up in Claude Code**
- A: Check file is in `~/.claude/agents/` and has `.md` extension
- A: Verify YAML frontmatter is valid (use online YAML linter)

**Q: "Unknown model" error**
- A: Use only: `haiku`, `sonnet`, `opus`, or `opus[1m]` (1M context window)

**Q: Agent output format is wrong**
- A: Check the Output Format section near the end of the agent's `.md`
- A: Ensure "## Output Format" section exists

**Q: CLAUDE.md not being read**
- A: Ensure it's at project root, not in a subdirectory
- A: Agents read it automatically on startup

---

## Next Steps

- [Agent Catalog](AGENTS.md) — Full list of 26 agents with details
- [Architecture](ARCHITECTURE.md) — How Quarterdeck works internally
- [README](../README.md) — Back to main docs
