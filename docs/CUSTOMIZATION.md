# Customization — How to Adapt for Your Project

## Step 1: Copy the agents

```bash
cp quarterdeck/agents/*.md ~/.claude/agents/
cp quarterdeck/rules/*.md ~/.claude/rules/
```

## Step 2: Configure the language

Agents come configured for **pt-BR**. To switch to English or another language, edit the language rule in each agent's Output Format:

```markdown
# From:
- **IDIOMA: Sempre em pt-BR...**

# To:
- **LANGUAGE: Always in English...**
```

## Step 3: Adjust the models

In each agent's frontmatter, adjust the model to match your plan:

```yaml
---
model: sonnet   # Best cost/quality for most tasks
model: opus     # More expensive, best for deep reasoning
model: haiku    # Cheapest, good for simple tasks
---
```

**Recommended distribution:**
- Opus: strategic agents (architect, planner, security-reviewer)
- Sonnet: execution agents (code-reviewer, tdd-guide, devops-specialist)
- Haiku: simple agents (build-error-resolver, doc-updater)

## Step 4: Add project context

Create a `CLAUDE.md` at your project root with:

```markdown
# My Project

## Stack
- Backend: Python 3.12 / FastAPI
- Frontend: TypeScript / React
- Database: PostgreSQL 16
- Cache: Redis

## Services
- backend.service (port 8000)
- scheduler.service

## Conventions
- Tests: pytest
- Linting: ruff
- Formatting: ruff format
```

Agents automatically load the project's `CLAUDE.md` and adapt their behavior.

## Step 5: Customize individual agents

### Add tools

```yaml
---
tools: Read, Grep, Glob, Bash, Skill(local-mind:super-search)
---
```

### Add project-specific sections

At the end of the agent file, add a section:

```markdown
## Project Guidelines

- Endpoints always async (`async def`)
- Use Pydantic v2 for validation
- All queries via SQLAlchemy async
```

### Adjust token budget

In the Output Format, change the limit:

```markdown
Rules:
- Maximum output: 600 tokens   # increase for agents that need more detail
```

## Step 6: Add or remove agents

### Create a new agent

Create `~/.claude/agents/my-agent.md`:

```yaml
---
name: my-agent
description: Specialist in [domain]. Use when [trigger].
tools: Read, Grep, Glob
model: sonnet
---

[Role description in 1-2 sentences]

## Ground Truth First

1. **Read before analyzing** — [specific instruction]
2. **Look for patterns** — [specific instruction]
3. **Ask when in doubt** — [specific instruction]

## [Domain-specific sections]

## Output Format (MANDATORY)

Structure your response EXACTLY as follows:

### FINDINGS (max 5, ordered by severity)
- **[CRITICAL|HIGH|MEDIUM|LOW]** [title] — [location] — [description + fix]

### NEXT STEP: [1-2 sentences]

### SUMMARY:
System/business impact.
How it was analyzed/approached.
What was found, with concrete numbers.

Rules:
- Maximum output: 400 tokens
- No preamble, no filler
```

### Remove an agent

Simply delete the corresponding `.md` file from `~/.claude/agents/`.

## Step 7: Configure the PE rule

The `principal-engineer-always-on.md` rule is the heart of the system. Adjust:

- **Section 6 (Routing Table)**: add/remove routes for your agents
- **Section 8 (Workflow Chains)**: define work chains for your workflows
- **Section 15 (Crawler Protocol)**: adjust the parallel routing tables
- **Section 16 (PE Synthesis)**: adjust the synthesis format

## Tips

1. **Start with few agents** — You don't need all 26 from the start
2. **Most useful agents to begin with**: code-reviewer, planner, tdd-guide, deep-researcher
3. **Add as needed** — When you miss a specialist, add one
4. **Test the output** — Run an agent and validate whether the SUMMARY format is clear
5. **Iterate** — Adjust prompts based on the results you observe
