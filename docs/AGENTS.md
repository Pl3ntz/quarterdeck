# The 26 Agents

Complete catalog of Quarterdeck's specialized agent team, organized into 8 functional squads.

**Back to:** [README](../README.md)

---

## Standardized Output Format

Every agent returns results in the same structured format for consistency:

```markdown
### FINDINGS (ordered by severity)
- **[CRITICAL]** SQL injection — `src/api/users.py:42` — Query uses string concatenation
- **[HIGH]** Missing input validation — `src/routes/auth.ts:15` — User email not sanitized

### NEXT STEP: Fix the SQL injection before merging.

### SUMMARY: The users endpoint had multiple security issues found
during comprehensive analysis. Identified 1 CRITICAL vulnerability and
2 MEDIUM issues with suggested fixes in each case.
```

The **SUMMARY** follows a consistent pattern: system impact → how analyzed → concrete result with numbers.

---

## 🔍 Planning & Design Squad

Strategic thinking before building. Designs systems and creates implementation plans.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [architect](../agents/architect.md) | System design, scalability, and architectural trade-offs | Read, Grep, Glob, Bash, Skill(local-mind:super-search) | Opus |
| [planner](../agents/planner.md) | Creates phased implementation plans with risks and dependencies | Read, Grep, Glob, Bash, Skill(local-mind:super-search) | Opus |

---

## 🛡️ Quality Gate Squad

Validation layer (read-only) — always run in parallel. Never modify code; only provide structured feedback.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [code-reviewer](../agents/code-reviewer.md) | Code quality, patterns, bugs, maintainability | Read, Grep, Glob, Bash, Skill(local-mind:super-search) | Sonnet |
| [security-reviewer](../agents/security-reviewer.md) | Infrastructure hardening, threat modeling, vulnerability analysis | Read, Bash, Grep, Glob, Skill(local-mind:super-search) | Opus |
| [ux-reviewer](../agents/ux-reviewer.md) | Accessibility (WCAG 2.2), visual consistency, interaction states | Read, Grep, Glob, Bash, Skill(local-mind:super-search) | Sonnet |
| [staff-engineer](../agents/staff-engineer.md) | Cross-system impact, pattern propagation, tech debt evaluation | Read, Grep, Glob, Bash, Skill(local-mind:super-search) | Opus |

---

## 🔨 Implementation Squad

Write code following established patterns. Each has focused responsibility and must report progress back to PE.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [tdd-guide](../agents/tdd-guide.md) | Test-Driven Development with 80%+ coverage (tests first) | Read, Write, Edit, Bash, Grep, Glob | Sonnet |
| [e2e-runner](../agents/e2e-runner.md) | End-to-end testing with Playwright and API testing | Read, Write, Edit, Bash, Grep, Glob | Sonnet |
| [build-error-resolver](../agents/build-error-resolver.md) | Fixes build errors, type errors, service startup issues | Read, Write, Edit, Bash, Grep, Glob, Skill(local-mind:super-search) | Haiku |
| [refactor-cleaner](../agents/refactor-cleaner.md) | Dead code removal and consolidation of duplicates | Read, Write, Edit, Bash, Grep, Glob | Sonnet |

---

## ⚙️ Operations Squad

Keep systems running — diagnose issues, deploy changes, optimize performance, manage databases.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [incident-responder](../agents/incident-responder.md) | Diagnose outages (5-phase: triage, diagnose, remediate, verify, document) | Read, Bash, Grep, Glob, Skill(local-mind:super-search) | Opus |
| [devops-specialist](../agents/devops-specialist.md) | CI/CD pipelines, deployment automation, systemd, monitoring | Read, Write, Edit, Bash, Grep, Glob | Sonnet |
| [performance-optimizer](../agents/performance-optimizer.md) | Profiling, bottleneck identification, resource tuning | Read, Bash, Grep, Glob, Skill(local-mind:super-search) | Sonnet |
| [database-specialist](../agents/database-specialist.md) | PostgreSQL schema, query optimization, indexes, migrations | Read, Bash, Grep, Glob, Skill(local-mind:super-search) | Sonnet |

---

## 📚 Intelligence Squad

Research and documentation — validate sources, generate docs from code.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [deep-researcher](../agents/deep-researcher.md) | Multi-source research, OSINT, triangulation, confidence-scored synthesis | WebSearch, WebFetch, Bash, Read, Grep, Glob, Skill(local-mind:super-search) | Opus |
| [doc-updater](../agents/doc-updater.md) | Generate documentation and codemaps from actual codebase | Read, Write, Edit, Bash, Grep, Glob | Haiku |

---

## ✍️ Language Squad

Spelling, grammar, and writing quality for single languages (read-only).

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [ortografia-reviewer](../agents/ortografia-reviewer.md) | PT-BR orthography, grammar, agreement, regency (ENEM level) | Read, Grep, Glob | Sonnet |
| [grammar-reviewer](../agents/grammar-reviewer.md) | EN-US spelling, grammar, punctuation, style (GRE level) | Read, Grep, Glob | Sonnet |

---

## 🎯 Strategy Squad

Specialized advisors for SEO and technical recruiting.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [seo-reviewer](../agents/seo-reviewer.md) | Technical SEO + AI Search/GEO audit: Core Web Vitals, structured data, crawlability | Read, Grep, Glob, Bash | Sonnet |
| [tech-recruiter](../agents/tech-recruiter.md) | Tech hiring: JD creation, candidate evaluation, interviews, seniority assessment | Read, Grep, Glob, Bash, WebSearch, WebFetch | Sonnet |

---

## 📰 Editorial Squad

Full editorial pipeline under [Sourcing Discipline Protocol](../rules/sourcing-discipline.md) — minimum 3-source triangulation, mandatory citations with URL and date.

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| [editor-chefe](../agents/editor-chefe.md) | Editorial direction: story angle, editorial line, project approval | Read, Grep, Glob, WebSearch, WebFetch | Opus |
| [jornalista](../agents/jornalista.md) | Investigation, interviews, source triangulation, raw material production | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Bash | Sonnet |
| [redator](../agents/redator.md) | Editorial writing: transforms raw material into publishable text with voice and rhythm | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch | Sonnet |
| [escritor-tecnico](../agents/escritor-tecnico.md) | Technical writing: IMRAD, Diataxis, ADRs, design docs, post-mortems | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch | Sonnet |
| [fact-checker](../agents/fact-checker.md) | Independent verification (Rule of Two): 7 labels, 3+ source triangulation | Read, Grep, Glob, WebSearch, WebFetch | Opus |
| [editor-de-texto](../agents/editor-de-texto.md) | Final editing: cuts, lead/closing polish, FENAJ code, legal language | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch | Sonnet |

**Recommended pipeline:**
```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
  (assign)      (report)     (write)   (verify)       (polish)         (proofread)
```

---

## Parallel Execution Guide

The PE automatically runs agents in **parallel** when they have no dependencies:

### Always Parallel (no data dependencies)
- **Quality Gate squad**: all 4 agents review simultaneously
- **Multiple independent implementations**: zone-assigned agents don't conflict
- **Multi-agent research**: deep-researcher + Explore agents
- **Parallel validation**: code-reviewer + security-reviewer + ux-reviewer

### Wave-Based Sequences
```
Wave 1 (Reconnaissance) — all in parallel:
  ├── Explore codebase
  ├── Explore tests
  └── deep-researcher (external sources)

Wave 2 (Planning) — sequential after Wave 1:
  └── planner or architect

Wave 3 (Implementation) — parallel after Wave 2:
  ├── tdd-guide (zone A files)
  └── devops-specialist (zone B files)

Wave 4 (Validation) — parallel after Wave 3:
  ├── code-reviewer
  ├── security-reviewer
  └── ux-reviewer (if UI changes)
```

---

## Model Distribution

Quarterdeck optimizes cost vs. reasoning depth:

| Model | Cost | Use for | Agents |
|-------|------|---------|--------|
| **Opus** | $5/$25 per MTok | Deep reasoning, architecture, security, research | architect, planner, deep-researcher, security-reviewer, staff-engineer, incident-responder, editor-chefe, fact-checker |
| **Sonnet** | $3/$15 per MTok | Focused execution, quality reviews | code-reviewer, ux-reviewer, tdd-guide, e2e-runner, refactor-cleaner, devops-specialist, performance-optimizer, database-specialist, jornalista, redator, escritor-tecnico, editor-de-texto, ortografia-reviewer, grammar-reviewer, seo-reviewer, tech-recruiter |
| **Haiku** | $1/$5 per MTok | Simple, scoped tasks | build-error-resolver, doc-updater |

---

## See Also

- [Architecture](ARCHITECTURE.md) — System design and request flow
- [Crawler Protocol](CRAWLER-PROTOCOL.md) — How parallel wave execution works
- [Output Format](OUTPUT-FORMAT.md) — Per-agent output examples and standards
- [Customization](CUSTOMIZATION.md) — How to modify or create agents
