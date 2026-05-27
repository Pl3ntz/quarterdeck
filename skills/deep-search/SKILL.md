---
name: deep-search
description: Deep multi-source web research with query decomposition, source triangulation, and confidence-scored synthesis. Finds information that surface searches miss.
---

# Deep Search Skill

This skill delegates to the **deep-researcher** agent for thorough, multi-source web research.

## What It Does

1. Decomposes your query into sub-questions
2. Generates multiple search queries using 7 reformulation strategies
3. Searches using WebSearch, WebFetch, and OSINT tools (whois, dig, curl)
4. Distills results into knowledge cards with source attribution
5. Triangulates sources and detects contradictions
6. Iterates up to 3 cycles to fill gaps
7. Produces a structured report with confidence scores

## Usage

```
/deep-search [your research question or topic]
```

## Arguments

Pass your research query as `$ARGUMENTS`. Be as specific as possible for better results.

**Good queries:**
- "What are the production-ready alternatives to Neo4j for graph databases in 2026?"
- "Compare FastAPI vs Litestar performance benchmarks and ecosystem maturity"
- "Who owns domain example.com and what infrastructure do they use?"

**Vague queries (will work but less focused):**
- "graph databases"
- "Python web frameworks"

## Invocation

When this skill is activated:

1. Spawn the `deep-researcher` agent (Opus model) with the Task tool
2. Pass `$ARGUMENTS` as the research query
3. Include any relevant context from the current conversation
4. The agent will return a structured research report

## Integration

- Use before `/plan` to inform architectural decisions with researched data
- Use standalone for any research question the Owner needs answered
- The PE can invoke this directly when the routing table matches "research, search deeply, find info about"
