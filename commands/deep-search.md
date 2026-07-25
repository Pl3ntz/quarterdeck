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
5. **Triangulates** sources (`[HIGH]` requires ≥3 independent organizations with ≥1 primary; same-org/echo sources collapse to one)
6. **Detects contradictions** (reports conflicting information with both sides)
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

## Output Format (Canonical Minimum)

The agent produces EXACTLY these sections (the contract enforced in `deep-researcher.md`):
- `### FINDINGS` (max 5, ranked by confidence; each `[HIGH|MEDIUM|LOW]` + source count + indices `[1,3]`)
- `### CONTRADICTIONS` (disagreements with an assessment, or `- none`)
- `### GAPS` (what went unanswered / single-source / unverified)
- `### NEXT STEP` (always present)
- `### OPEN QUESTIONS / ASSUMPTIONS` (when scope is ambiguous; the agent is one-shot, the PE decides whether to re-spawn)
- `### SOURCES` (one line per source: URL + date + tier (primary/secondary/tertiary) + QUALITY)
- `### APPENDIX` (optional, outside the budget: queries, domains, tools that failed)

Confidence: **HIGH = ≥3 independent organizations with ≥1 primary**; MEDIUM = 2; LOW = 1; UNVERIFIED = 0.

## Validation step (wire-in, MANDATORY)

After the deep-researcher returns, run the deterministic validator on its output before using it:

```bash
python3 ~/.claude/scripts/deep-researcher-validate.py <report-file> --fix --liveness
```

The validator (deterministic: what prompt-only cannot reliably enforce):
- **auto-downgrades** any `[HIGH]` not backed by ≥3 distinct organizations (OSINT/infra claims use a verbatim-command-output floor instead);
- **curls** every SOURCES URL (404/NXDOMAIN on a cited URL = fabrication flag; 403/429 = blocked, not dead);
- **flags** missing required sections and hedging-as-grounding.

Use the `--fix` output (corrected labels) as the delivered result. If the validator reports CONTRACT violations (a missing required section, since it cannot invent content), **re-spawn** the agent with that feedback rather than shipping. See `~/.claude/evals/deep-researcher/` for the eval harness that measures this.

## Integration with Other Commands

- `/deep-search` -> `/plan`: Research first, then plan implementation
- `/deep-search` -> `/tdd`: Research best practices, then implement with TDD
- PE auto-routes to this when detecting "research", "search deeply", "find info about"

## Related

- Agent: `~/.claude/agents/deep-researcher.md`
- Skill: `~/.claude/skills/deep-search/SKILL.md`
