# Agent Catalog

Quick reference for all 26 agents, organized by squad.

---

## Planning & Design Squad

### architect

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | Architecture decisions, system design, trade-off evaluation |

**What it does:** Analyzes current architecture and proposes design decisions with alternatives and trade-offs. Always presents multiple options — never a single solution.

**Output:** Design decision + alternatives table (pros/cons) + trade-offs + SUMMARY

---

### planner

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | Complex features that need a phased plan with risks and dependencies |

**What it does:** Creates detailed implementation plans with phases, steps, risks, and mitigations. Each step references specific file paths.

**Output:** Phased plan + risks + SUMMARY

---

## Quality Gate Squad

> All agents in this squad are **read-only** and **always run in parallel**.

### code-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | After writing or modifying code — validates quality, security, and maintainability |

**What it does:** Reviews code by priority: CRITICAL (security, data loss) > HIGH (logic, error handling) > MEDIUM (quality, performance) > LOW (style, naming). Checks Python/FastAPI and TypeScript patterns.

**Special modes (BMAD cherry-picks):**
- **Blind Review** (`--blind`): Receives ONLY the diff, without project context. Breaks anchoring bias — finds problems that context "normalizes". Used as an additional layer, not a substitute.
- **Surface Area Stats**: Quantitative metrics at the beginning of output (files changed, modules, lines of logic, boundary crossings, new public interfaces).
- **Concern-based grouping**: Groups findings by change intent (concern), not by file. Helps the Captain understand the change as a whole.

**Output:** Surface Area Stats + Findings ordered by severity + By Concern + SUMMARY

---

### security-reviewer

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Infrastructure audit, hardening, secrets, firewall, SSL, systemd |

**What it does:** Audits infrastructure security (SSH, firewall, systemd, PostgreSQL, Redis, Nginx, SSL). Different from code-reviewer — focuses on infra, not code patterns.

**Output:** Threat table by area + findings + SUMMARY

---

### ux-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | After UI changes — accessibility (WCAG 2.2 AA + selective AAA), consistency, interaction states, modern web platform |

**What it does:** Framework-agnostic frontend reviewer covering 12 areas:

| Area | What it checks |
|------|----------------|
| **WCAG 2.2 AA** | Complete coverage including 2.4.11 Focus Not Obscured, 2.5.7 Dragging, 2.5.8 Target Size (24x24 + spacing), 3.2.6 Consistent Help, 3.3.7 Redundant Entry, 3.3.8 Accessible Auth |
| **Selective AAA** | 2.4.13 Focus Appearance, 1.4.6 Contrast Enhanced (7:1), 2.4.12 Focus Not Obscured Enhanced, 3.3.9 Accessible Auth Enhanced |
| **Media queries** | prefers-reduced-motion, prefers-color-scheme, prefers-contrast, forced-colors |
| **Color & vision** | Beyond contrast — CVD (8% of men), dark mode pitfalls (halation, naive inversion), forced-colors mode |
| **Motion safety** | Vestibular triggers (parallax, scrolljacking), animation duration limits, autoplay controls |
| **Component patterns** | Toast (aria-live), carousel, combobox (ARIA 1.2), date picker, infinite scroll, data tables, tooltip, native `<dialog>`, popover |
| **Loading states** | Skeleton (aria-busy), spinner (role=status), optimistic UI |
| **Cognitive (COGA)** | Progress indicators, error recovery, auto-save, search, consistent layout |
| **Mobile UX** | Safe areas (notch/Dynamic Island), dynamic viewport units (svh/lvh/dvh), gesture conflicts |
| **Internationalization** | RTL via CSS logical properties, lang/dir attributes, text expansion buffer |
| **Modern platform** | View Transitions API, scroll-driven animations, `:has()`, container queries |
| **Interaction states** | Default, hover, focus, active, disabled, loading, error, empty |

**Output:** Findings ordered by user impact + WCAG ref + JSON machine-parseable + SUMMARY

---

### staff-engineer

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | Changes that affect multiple projects or shared infrastructure |

**What it does:** Evaluates organizational impact (L4): cross-system dependencies, pattern propagation, tech debt with business impact.

**Output:** Cross-system impact + pattern propagation + tech debt + SUMMARY

---

## Implementation Squad

> All agents in this squad **write code** and need **zone assignment** from the PE.

### tdd-guide

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write (code writing) |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | New features, bug fixes, refactoring — always with tests first |

**What it does:** Implements using TDD (Red-Green-Refactor). Writes tests first, then minimal implementation to pass. Ensures 80%+ coverage.

**Output:** Tests written + coverage + SUMMARY

---

### e2e-runner

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Critical user flow tests with Playwright |

**What it does:** Creates and runs E2E tests with Playwright. Manages flaky tests, captures screenshots/videos, and uses Page Object Model.

**Output:** Results (passed/failed/flaky) + failures + SUMMARY

---

### build-error-resolver

| Field | Value |
|-------|-------|
| **Model** | Haiku |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Build failed, type errors, service won't start |

**What it does:** Fixes build errors with minimal diff. Doesn't refactor, optimize, or redesign — only fixes the error and verifies the build passes.

**Output:** Errors fixed + pending + SUMMARY

---

### refactor-cleaner

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Dead code removal, cleanup, duplicate consolidation |

**What it does:** Identifies and removes dead code, unused dependencies, and duplicates. Uses analysis tools (knip, vulture) and verifies all references before removing.

**Output:** Items removed + impact + SUMMARY

---

## Operations Squad

### incident-responder

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (diagnosis) |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Service down, errors increasing, users reporting issues |

**What it does:** Follows a 5-phase workflow: Triage (2min) > Diagnose (5-10min) > Remediate (options) > Verify > Document. Never executes fixes — only diagnoses and recommends.

**Output:** Affected services + root cause + options (quick vs complete) + SUMMARY

---

### devops-specialist

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | CI/CD, deploy, systemd, monitoring, Nginx, SSL |

**What it does:** Analyzes and improves CI/CD pipelines, automates deploys, configures systemd services, and manages infrastructure (Nginx, SSL). Always presents before executing.

**Output:** Findings + proposed changes + SUMMARY

---

### performance-optimizer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Slow service, limited resources, before scaling decisions |

**What it does:** Measures system metrics (CPU, memory, disk), analyzes slow PostgreSQL queries, Redis, Nginx tuning, and async Python/FastAPI patterns. Always with measured values, never assumptions.

**Output:** Metrics + bottlenecks + SUMMARY

---

### database-specialist

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Schema design, slow queries, indexing, migrations, database health |

**What it does:** Analyzes PostgreSQL health, identifies slow queries via EXPLAIN ANALYZE, recommends indexes, validates migration safety, and monitors bloat/vacuum.

**Output:** Findings with EXPLAIN ANALYZE evidence + SUMMARY

---

## Intelligence Squad

### deep-researcher

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (web research) |
| **Tools** | WebSearch, WebFetch, Bash, Read, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Deep multi-source research, comparisons, OSINT, triangulation |

**What it does:** Researches in 6 phases: Plan > Search > Distill > Evaluate > Iterate > Synthesize. Uses 7 query reformulation strategies. Every claim needs 3+ sources for HIGH confidence.

**Output:** Findings with confidence level + contradictions + gaps + SUMMARY

---

### doc-updater

| Field | Value |
|-------|-------|
| **Model** | Haiku |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Update codemaps, READMEs, documentation |

**What it does:** Generates and updates documentation based on actual code. Never documents from memory — always reads the current codebase first.

**Output:** Changes made + SUMMARY

---

## Language Squad

> Language review agents. **Read-only**, scope restricted to their language — never touch code, variables, or text in another language.

### ortografia-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob |
| **When to use** | Review any PT-BR text — docs, strings, comments, agent outputs, READMEs |

**What it does:** Brazilian Portuguese reviewer at ENEM perfect score level. Covers 11 axes of normative grammar:

| Axis | What it detects |
|------|------------------------|
| **Spelling** | "necesário" → "necessário", S/SS/Ç/SC/X/Z, G/J, CH/X usage |
| **Accents** | Missing proparoxytone accents, hiatuses, differential accents (pôr/por, têm/tem) |
| **2009 Spelling Reform** | "idéia" → "ideia", "vôo" → "voo", prefix hyphen rules |
| **Verb agreement** | "Fazem dois anos" → "Faz dois anos" (impersonal haver/fazer) |
| **Noun agreement** | "menas" (doesn't exist), "meio nervosa" (invariable as adverb) |
| **Regency** | "Assisti o jogo" → "Assisti ao jogo", "Prefiro X do que Y" → "Prefiro X a Y" |
| **Crase** | Mandatory (à noite, às 10h), forbidden (before verbs, masculine nouns) |
| **Pronoun placement** | "Me disseram" → "Disseram-me", proclisis/mesoclisis/enclisis |
| **Punctuation** | Comma between subject and verb (forbidden), vocative without comma |
| **Language vices** | "subir para cima", "elo de ligação", "surpresa inesperada" (pleonasms) |
| **Classic confusions** | mas/mais, mal/mau, há/a, onde/aonde, a fim/afim |

**Absolute scope:**
- ONLY PT-BR text — completely ignores text in other languages
- NEVER changes variable names, functions, or code identifiers
- NEVER changes technical terms in English (e.g., "SQL injection", "deploy")

**Output:** Findings with `file:line` + Recurring patterns + SUMMARY

**Tested against:** 60+ erros propositais em 10 categorias. Coverage: ~95%. False positives: 0.

---

### grammar-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob |
| **When to use** | Review any English text — docs, strings, comments, agent outputs, READMEs |

**What it does:** American English reviewer at GRE Analytical Writing score 6/6 (perfect score) level. Covers 10 axes:

| Axis | What it detects |
|------|------------------------|
| **Spelling** | "occured" → "occurred", "definately" → "definitely" (40+ most misspelled words) |
| **Homophones** | "it's/its", "their/there/they're", "affect/effect" (22+ pares) |
| **British vs American** | "colour" → "color", "travelling" → "traveling" — enforce AmE |
| **Subject-verb agreement** | "Everyone have" → "Everyone has", collective nouns, inverted sentences |
| **Pronoun case** | "Between you and I" → "Between you and me", who/whom |
| **Sentence errors** | Comma splices, run-ons, fragments, dangling modifiers |
| **Parallel structure** | "reading, swimming, and to hike" → "reading, swimming, and hiking" |
| **Punctuation** | Oxford comma, hyphens (well-known, two-year-old), AmE quotation rules |
| **Word usage** | "could of" → "could have", "irregardless" → "regardless", redundancies |
| **Style** | Wordy expressions ("due to the fact that" → "because"), formal register |

**Absolute scope:**
- ONLY English text — completely ignores text in other languages
- NEVER changes variable names, functions, or code identifiers
- Enforces American English spelling (never British)

**Output:** Findings with `file:line` + Recurring patterns + SUMMARY

**Tested against:** 80+ erros propositais em 11 categorias. Coverage: ~98%. False positives: 0.

---

## Strategy Squad

### seo-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | After UI changes, new pages, before deploy — audit technical SEO + AI search readiness |

**What it does:** Framework-agnostic SEO auditor covering 13 areas (expanded for 2025-2026):

| Area | What it checks |
|------|---------------|
| **AI Search / GEO** | AI Overviews citation optimization, citation blocks (40-60 words), fact density, "Last Updated" signals — sites cited in AI Overviews gain +35% CTR |
| **AI Crawler Management** | robots.txt multi-tier strategy: block training bots (GPTBot, ClaudeBot, Google-Extended), allow search bots (OAI-SearchBot, ChatGPT-User, PerplexityBot, Claude-SearchBot) |
| **Core Web Vitals** | LCP ≤2.5s, INP ≤200ms (with optimization patterns + LoAF API), CLS ≤0.1, bfcache eligibility |
| **Performance** | Speculation Rules API, Early Hints (103), Resource hints, font-display swap, AVIF/WebP |
| **Crawlability** | robots.txt, XML sitemap, canonical URLs, hreflang bidirectional, IndexNow protocol |
| **Indexability** | noindex leaks, redirect chains, soft 404s, status codes, 3-click reachability |
| **Rendering** | Universal principles (HTML complete in server response, meta consistency server↔client, structured data in source) — replaces framework-specific rules |
| **JavaScript SEO** | Hydration risks, islands architecture, streaming SSR, Server Components |
| **Meta tags** | Title (50-60 chars), description (150-160 chars), viewport, canonical, favicon (≥48px) |
| **Structured Data** | 7 deprecated types flagged (Book Actions, Course Info, etc.), 4 new types (ProfilePage, DiscussionForumPosting, Person E-E-A-T, VideoObject+Clip) |
| **Content & Authority** | Helpful Content System (integrated to core), topical authority/clusters, freshness, AI content policy, parasite SEO detection |
| **Video SEO** | VideoObject schema, Clip/SeekToAction key moments, mandatory transcripts |
| **International** | ccTLD vs subdirectory vs subdomain strategy, content localization, Search Console per region |

**Extras:**
- 25 common SEO mistakes ranked by severity (CRITICAL→LOW)
- SEO & accessibility overlap
- Page Experience (interstitials, HSTS, security headers)

**Output:** Surface Area (pages, stack, rendering, AI search readiness) + Findings + Quick Wins + SUMMARY

---

### tech-recruiter

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | Hire devs — JDs, candidate evaluation, interview design, hiring processes |

**What it does:** Tech recruitment specialist with 4 operation modes:

**Mode 1 — Job Description Review:**
- Evaluates structure, requirements (max 6 must-haves), inclusive language, gender/age bias
- Score 1-10 with justification
- Rewrites the JD if score < 7
- Detects: "Ninja/Rockstar" titles, hidden salaries, impossible requirements (e.g., "10+ years of React")

**Mode 2 — Candidate Evaluation:**
- Analyzes LinkedIn profile (tenure, growth, recommendations, headline)
- Analyzes GitHub (consistency, quality, READMEs, commit messages, OS contributions)
- Analyzes resume (red flags: buzzwords without context, "expert in 25+ languages")
- Evaluates code (SQL injection, hardcoded secrets, bare except, god functions)
- Determines seniority: Junior / Mid / Senior / Staff with concrete justification
- **Growth potential**: evaluates whether the candidate can grow to the desired level and timeline
- **Alternative fit**: if not suitable for this role, suggests which role/level would be ideal
- Recommendation: ADVANCE / HOLD / PASS — each with concrete next steps

**Mode 3 — Interview Design:**
- Pipeline by level (Junior→Staff) with appropriate assessment types
- Technical questions by stack (Python/FastAPI, TypeScript/React, DevOps, Go)
- Behavioral questions (STAR method, 7 essential categories)
- System design (URL shortener→payment system by level)
- Standardized scoring rubric

**Mode 4 — Process Audit:**
- Conversion funnel (2026 benchmarks)
- Metrics: time-to-hire, cost-per-hire, offer acceptance rate
- Bias detection in process (affinity, confirmation, halo/horn)
- D&I: blind screening, diverse panels, structured interviews

**Mode 5 — Profile Assessment / "What's my level?" (NEW):**

Seniority assessment using the 5-axis framework (based on engineeringladders.com + FAANG calibration):

| Axis | What it measures | Score 1 (Junior) → Score 5 (Principal) |
|------|-----------|----------------------------------------|
| **Technology** | Technical depth | Adopts → Specializes → Evangelizes → Masters → Creates |
| **System** | System design | Enhances → Designs → Owns → Evolves → Leads |
| **People** | Mentoring and leadership | Learns → Supports → Mentors → Coordinates → Manages |
| **Process** | Process maturity | Follows → Enforces → Challenges → Adjusts → Defines |
| **Influence** | Impact scope | Subsystem → Team → Multiple Teams → Company → Community |

Delivers:
- **5-axis scorecard** with evidence for each score
- **Calibrated level** (Junior/Mid/Senior/Staff/Principal) + FAANG equivalence (L3-L8)
- **Profile shape** (I/T/Pi/M-shaped) with analysis
- **Skills gap analysis** with estimated closure time and strategy
- **Growth roadmap** personalized (quick wins + medium term + plateau risks)
- **Market positioning** with market research (WebSearch) — expected salary, company fit
- **IC vs Management** — recommendation based on observed signals
- **Title calibration** — if current title doesn't match actual level

**Mode 6 — Salary/Offer Review (NEW):**
- Market positioning (P25/P50/P75) with dated sources
- Total compensation breakdown (base + equity + bonus + benefits)
- Competitive analysis: does the offer attract talent or lose to competitors?
- Adjustment recommendations with justification

**Reference data:**
- Salary benchmarks by region (US, EU, BR, LATAM)
- Funnel rates (191 applications/hire, 82% offer acceptance)
- Sourcing effectiveness (referrals = 11x inbound, internal = 32x)
- Onboarding 30/60/90 days
- Career ladder mapping: FAANG (L3-L8), Stripe (L1-L5), Radford (P1-P6)
- Average timeline between levels: Junior→Mid (1-2y), Mid→Senior (2-4y), Senior→Staff (3-5y)

**Ferramentas:** Read, Grep, Glob, Bash, **WebSearch, WebFetch** (validação de mercado em tempo real)

**Output:** Varies by mode — always with concrete alternatives (never just criticism)

**Tested against:** JD com 17 erros + candidato com 35 red flags. Coverage: ~98%. False positives: 0.

---

## Editorial Squad

Full professional editorial pipeline for journalistic, technical, and academic content production. All agents operate under [Sourcing Discipline Protocol](../rules/sourcing-discipline.md) — minimum 3-source triangulation, primary > secondary > tertiary hierarchy, mandatory citation with URL and date, never fabricate sources.

**Recommended pipeline:**

```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
  (pauta)      (apura)      (escreve)  (verifica)     (lapida)          (revisa)
```

**Technical parallel path:** `escritor-tecnico` → `ortografia-reviewer` (skips jornalista/fact-checker for technical/academic content).

### editor-chefe

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (direction) |
| **Tools** | Read, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Start of editorial project: define story angle, editorial line, approve scope |

**What it does:** Transforms vague ideas into actionable story assignments with a differentiated angle. Evaluates newsworthiness, calibrates scope, maps required sources, applies FENAJ code and identifies ethical/legal/editorial risks. Doesn't investigate or write — decides the WHAT and the WHY.

**Output:** Structured story assignment (type, central question, angle, newsworthiness, provisional thesis, required sources, risks, scope, editorial line, references, next steps).

---

### jornalista

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write (investigation) |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Bash |
| **When to use** | Investigate story approved by editor-chefe — investigation, interviews, triangulation |

**What it does:** Rigorous investigation with professional methodology — desk research, source identification, interviews with explicit attribution conditions (on the record / background / deep background / off), cross-verification, mandatory search for the "other side". Delivers structured raw material to the redator. Rule of Two applied: Bash only for local processing, never external curl/wget/scp.

**Output:** Investigated material (confirmed facts with triangulated sources, verbatim quotes, documents, other side, timeline, sensitive points, gaps, angle recommendation).

---

### redator

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Transform investigated material into publishable editorial text |

**What it does:** Chooses genre (news, feature, profile, interview, analysis, opinion, chronicle), structure, lead (5W2H, anecdotal, descriptive, contrastive, quotation, statistical), nut graph (when needed), accepted closing (circular, strong quote, open future, symbolic detail). Applies rigor with attribution verbs (stated ≠ alleged ≠ confessed), legal language (suspect/defendant/indicted/convicted per procedural stage) and professional PT-BR style. Never adds facts — uses only the investigated material.

**Output:** Ready editorial text per chosen genre + lead justification + cited sources + identified gaps.

---

### escritor-tecnico

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Technical/scientific writing: academic articles, documentation, ADRs, design docs, post-mortems, presentations |

**What it does:** Production (not review) of technical and academic texts following established standards. Covers 10 document types: ABNT paper (NBR 14724:2024, 6023:2018, 10520:2023), IMRAD scientific article, Diataxis technical documentation (tutorial/how-to/reference/explanation), Nygard-format ADR, Google-style design doc, blameless SRE post-mortem, Minto/BLUF executive report, excellent README, changelog (Keep a Changelog + SemVer), slides (Duarte/Knaflic + 10/20/30 Kawasaki).

**Output:** Ready document in the appropriate canonical format + cited sources + gaps.

---

### fact-checker

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only (independent verification) |
| **Tools** | Read, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Verify factual claims in produced texts — **Rule of Two applied to journalism** |

**What it does:** Independent verification following Brazilian fact-checking agency methodology (Lupa, Aos Fatos, AFP Checamos, Comprova, Estadao Verifica). 8 steps: selection → survey → official databases → FOI → field → experts → checked party response → publish with label. Classifies each claim with one of 7 Lupa 2023+ labels: TRUE, FALSE, EXAGGERATED, UNDERESTIMATED, CONTRADICTORY, UNSUSTAINABLE, LACKS CONTEXT. Never accepts the redator's work as truth — re-verifies independently.

**Output:** Structured verification report (verified claims + classification + sources + suggested corrections + final recommendation: PUBLISH / PUBLISH WITH CORRECTIONS / RETURN TO REDATOR / RETURN TO JORNALISTA / DO NOT PUBLISH).

---

### editor-de-texto

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write (editing) |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Final editing of editorial texts — cuts, sharpens, reorganizes, applies FENAJ |

**What it does:** 4 surgical operations — CUT (reduce 20-40% by eliminating redundancies, idle adjectives, fillers, periphrases, corporate jargon), SHARPEN (replace generic with precise), REORGANIZE (weak lead, missing nut graph, buried information, dry closing), ADJUST RHYTHM (long vs short sentences, paragraphs). Applies full FENAJ checklist, verifies presumption of innocence (suspect/defendant/indicted/convicted), eliminates forbidden journalistic cliches. Never adds facts — only edits the existing text.

**Output:** Final edited text + edit diff (cuts, attribution corrections, legal corrections, removed cliches) + reduction metrics + FENAJ checklist + unresolvable issues requiring return.
