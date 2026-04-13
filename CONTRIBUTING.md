# Contributing

Thank you for considering contributing to Quarterdeck!

## How to Contribute

### Report Bugs

1. Open an [issue](https://github.com/Pl3ntz/quarterdeck/issues) describing:
   - Which agent had the problem
   - What you expected vs what happened
   - Claude Code version (`claude --version`)

### Suggest Improvements

1. Open an issue with the `enhancement` tag
2. Describe the use case and why the improvement would be useful

### Contribute Code

1. Fork the repository
2. Create a branch: `git checkout -b feat/my-agent`
3. Make your changes following the conventions below
4. Commit: `git commit -m "feat: add agent X"`
5. Push: `git push origin feat/my-agent`
6. Open a Pull Request

## Conventions

### Commit Format

```
<type>: <description>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### Agent Structure

Every agent must follow this structure:

```yaml
---
name: agent-name
description: Short description. When to use this agent.
tools: [required tools]
model: sonnet|opus|haiku
---
```

Required sections:
1. **Ground Truth First** — "Read before acting" instructions
2. **Domain sections** — Agent-specific content
3. **Output Format (MANDATORY)** — Standardized output format with FINDINGS + SUMMARY

### Output Rules

Every agent must have:
- `### FINDINGS` — Ordered by severity
- `### NEXT STEP` — Recommended action
- `### SUMMARY:` — Fluid text: impact → approach → concrete result
- Defined token budget

### Sensitive Data

Before submitting a PR, verify there are no:
- Server names or IPs
- Real project names
- Personal absolute paths (`/root/`, `/home/user/`)
- API keys, tokens, or passwords
- Company or client names

Use generic placeholders: `your-server`, `your-project`, `/path/to/<project>`

## Directory Structure

```
agents/     → Agent definitions (1 file per agent)
rules/      → PE orchestration rules
docs/       → Detailed documentation
examples/   → Examples and templates
```

## Questions?

Open an issue or reach out via GitHub.
