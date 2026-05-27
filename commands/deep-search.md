---
description: Deep multi-source research with query decomposition, OSINT, source triangulation, and confidence-scored synthesis
---

# Deep Search Command

This command invokes the **deep-researcher** agent for thorough, multi-source web research that goes beyond surface-level searches.

## What This Command Does

1. **Decomposes** your question into sub-queries using a DAG structure
2. **Searches** using 7 reformulation strategies (direct, decomposition, semantic expansion, perspective shift, multilingual, negation, temporal)
3. **Fetches** and analyzes specific pages for deep extraction
4. **OSINT** tools (whois, dig, curl) for infrastructure/domain research
5. **Triangulates** sources — flags claims with fewer than 2 independent confirmations
6. **Detects contradictions** — reports conflicting information with both sides
7. **Iterates** up to 3 research cycles to fill gaps
8. **Synthesizes** a structured report with confidence scores (HIGH/MEDIUM/LOW)

## When to Use

- Researching technologies, tools, or frameworks for adoption decisions
- Investigating a domain, company, or infrastructure (OSINT)
- Comparing alternatives with pros/cons backed by evidence
- Understanding current state of a rapidly evolving topic
- Validating claims or assumptions before making decisions
- Finding information in multiple languages (PT-BR, EN, ES)

## Example Usage

```
/deep-search What are the best graph database alternatives to Neo4j for production use in 2026?
/deep-search Compare Bun vs Deno vs Node.js runtime performance and ecosystem maturity
/deep-search Who owns example.com and what infrastructure stack do they use?
/deep-search What changed in FastAPI 0.115+ that affects WebSocket middleware?
```

## Output Format

The agent produces a structured report:
- **Executive Summary**: 2-4 sentence overview
- **Findings**: Each with confidence score and source count
- **Contradictions & Debates**: Conflicting information with both sides
- **Sources**: Table with URLs, dates, and authority ratings
- **Unresolved Gaps**: What remains unanswered
- **Search Strategy**: What queries were used and why

## Integration with Other Commands

- `/deep-search` -> `/plan`: Research first, then plan implementation
- `/deep-search` -> `/tdd`: Research best practices, then implement with TDD
- PE auto-routes to this when detecting "research", "search deeply", "find info about"

## Related

- Agent: `~/.claude/agents/deep-researcher.md`
- Skill: `~/.claude/skills/deep-search/SKILL.md`
