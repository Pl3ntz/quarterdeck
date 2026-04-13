# Architecture — Quarterdeck

## Overview

The name **Quarterdeck** comes from the command area of a ship — where the Captain makes decisions and coordinates the crew. In this system:

- **Captain** = you, the person operating Claude Code
- **PE** = Claude Code acting as your Principal Engineer
- **Agents** = 26 specialists that execute tasks under PE coordination

```
Layer 1: Captain (You)
  └── Decides, approves, directs

Layer 2: PE (Principal Engineer — always active)
  └── Orchestrates agents, synthesizes results, debates with you

Layer 3: 26 Specialized Agents (8 Squads)
  └── Execute focused tasks, report to PE
```

## Design Principles

### 1. Specialization > Generalization

Each agent is a specialist in ONE thing. A generic agent that does everything produces mediocre results. 26 specialists produce deep results.

### 2. Parallel by Default

The Crawler Protocol defines: **parallel is the default, sequential is the exception**. Only go sequential when there's a real data dependency.

### 3. Conflict is Prevented, Not Resolved

Agents that write code receive **exclusive file zones** before being spawned. Two agents never edit the same file in the same wave.

### 4. Standardized Output

All agents use the structured communication format (impact → approach → result). The PE can synthesize outputs from multiple agents quickly because the format is predictable.

### 5. Read Before Write

The Ground Truth Protocol ensures every agent reads existing code before analyzing or modifying. This eliminates assumptions and hallucinations.

## Flow of a Typical Request

```
Captain: "Implement JWT authentication in project X"
  │
  ▼
PE decomposes into waves:
  │
  ├── Wave 1 (PARALLEL — reconnaissance):
  │   ├── Explore: current auth structure
  │   ├── Explore: existing tests
  │   └── deep-researcher: JWT best practices
  │
  ├── [PE synthesizes and presents to Captain]
  │
  ├── Wave 2 (SEQUENTIAL — planning):
  │   └── planner: phased plan with risks
  │
  ├── [Captain approves plan]
  │
  ├── Wave 3 (SEQUENTIAL — implementation):
  │   └── tdd-guide: tests first, then implements
  │
  ├── [user reviews implementation]
  │
  └── Wave 4 (PARALLEL — validation):
      ├── code-reviewer: quality and patterns
      └── security-reviewer: auth bypass, JWT security
```

## Responsibility Distribution

### Who does what (no overlap)

| Responsibility | Agent | Who does NOT do it |
|---|---|---|
| SQL injection, XSS, input validation | code-reviewer | security-reviewer |
| Infra hardening, firewall, systemd | security-reviewer | code-reviewer |
| Code quality, naming, patterns | code-reviewer | ux-reviewer |
| Accessibility, spacing, focus states | ux-reviewer | code-reviewer |
| HOW to build (patterns, trade-offs) | architect | planner |
| IN WHAT ORDER to build (phases, risks) | planner | architect |
| Unit + integration tests | tdd-guide | e2e-runner |
| E2E tests (Playwright) | e2e-runner | tdd-guide |
| Incidents (REACTIVE) | incident-responder | devops-specialist |
| CI/CD and deploy (PROACTIVE) | devops-specialist | incident-responder |

## Cost Model

Model distribution is optimized for cost/quality:

- **Opus** (7) for deep reasoning: architect, planner, security-reviewer, incident-responder, staff-engineer, editor-chefe, deep-researcher
- **Sonnet** (16) for focused execution: code-reviewer, ux-reviewer, tdd-guide, e2e-runner, devops-specialist, performance-optimizer, database-specialist, refactor-cleaner, ortografia-reviewer, grammar-reviewer, tech-recruiter, jornalista, redator, escritor-tecnico, editor-de-texto, fact-checker
- **Haiku** (3) for simple tasks: build-error-resolver, doc-updater, seo-reviewer

This distribution saves ~60% vs using Opus for all agents, with minimal quality loss.
