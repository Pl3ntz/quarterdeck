# Agent Catalog

Quick reference for all 26 agents, organized by squad.

---

## Planning & Design Squad

### architect

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Architecture decisions, system design, trade-off evaluation |

**What it does:** Analyzes current architecture and proposes design decisions with alternatives and trade-offs. Always presents multiple options — never a single solution.

**Output:** Design decision + alternatives table (pros/cons) + trade-offs + SUMMARY

---

### planner

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Skill(local-mind:super-search) |
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

**What it does:** Revisa código por prioridade: CRITICAL (segurança, perda de dados) > HIGH (lógica, error handling) > MEDIUM (qualidade, performance) > LOW (estilo, naming). Verifica patterns Python/FastAPI e TypeScript.

**Special modes (BMAD cherry-picks):**
- **Blind Review** (`--blind`): Recebe APENAS o diff, sem contexto do projeto. Quebra anchoring bias — encontra problemas que o contexto "normaliza". Usado como camada adicional, não substituta.
- **Surface Area Stats**: Métricas quantitativas no início do output (arquivos alterados, módulos, linhas de lógica, boundary crossings, novas interfaces públicas).
- **Concern-based grouping**: Agrupa achados por intenção da mudança (concern), não por arquivo. Ajuda o Captain a entender a mudança como um todo.

**Output:** Surface Area Stats + Findings ordered by severity + By Concern + SUMMARY

---

### security-reviewer

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Infrastructure audit, hardening, secrets, firewall, SSL, systemd |

**What it does:** Audita segurança de infraestrutura (SSH, firewall, systemd, PostgreSQL, Redis, Nginx, SSL). Diferente do code-reviewer — foca em infra, não em patterns de código.

**Output:** Threat table by area + findings + SUMMARY

---

### ux-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | After UI changes — accessibility (WCAG 2.2 AA), consistency, interaction states |

**What it does:** Revisa frontend por acessibilidade, contraste, navegação por teclado, touch targets, design consistency, estados de interação (hover, focus, disabled, loading, error, empty).

**Output:** Findings ordered by user impact + SUMMARY

---

### staff-engineer

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **When to use** | Changes that affect multiple projects or shared infrastructure |

**What it does:** Avalia impacto organizacional (L4): cross-system dependencies, propagação de padrões, dívida técnica com impacto no negócio.

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

**What it does:** Implementa usando TDD (Red-Green-Refactor). Escreve testes primeiro, depois implementação mínima para passar. Garante cobertura 80%+.

**Output:** Tests written + coverage + SUMMARY

---

### e2e-runner

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Critical user flow tests with Playwright |

**What it does:** Cria e executa testes E2E com Playwright. Gerencia testes instáveis (flaky), captura screenshots/vídeos, e usa Page Object Model.

**Output:** Results (passed/failed/flaky) + failures + SUMMARY

---

### build-error-resolver

| Field | Value |
|-------|-------|
| **Model** | Haiku |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Build failed, type errors, service won't start |

**What it does:** Corrige erros de build com minimal diff. Não refatora, não otimiza, não redesenha — apenas corrige o erro e verifica que o build passa.

**Output:** Errors fixed + pending + SUMMARY

---

### refactor-cleaner

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | Dead code removal, cleanup, duplicate consolidation |

**What it does:** Identifica e remove código morto, dependências não utilizadas, e duplicatas. Usa ferramentas de análise (knip, vulture) e verifica todas as referências antes de remover.

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

**What it does:** Segue workflow de 5 fases: Triage (2min) > Diagnose (5-10min) > Remediate (opções) > Verify > Document. Nunca executa correções — apenas diagnostica e recomenda.

**Output:** Affected services + root cause + options (quick vs complete) + SUMMARY

---

### devops-specialist

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Bash, Grep, Glob |
| **When to use** | CI/CD, deploy, systemd, monitoring, Nginx, SSL |

**What it does:** Analisa e melhora pipelines CI/CD, automatiza deploys, configura serviços systemd, e gerencia infraestrutura (Nginx, SSL). Sempre apresenta antes de executar.

**Output:** Findings + proposed changes + SUMMARY

---

### performance-optimizer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Slow service, limited resources, before scaling decisions |

**What it does:** Mede métricas de sistema (CPU, memória, disco), analisa queries PostgreSQL lentas, Redis, Nginx tuning, e patterns async Python/FastAPI. Sempre com valores medidos, nunca suposições.

**Output:** Metrics + bottlenecks + SUMMARY

---

### database-specialist

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **When to use** | Schema design, slow queries, indexing, migrations, database health |

**What it does:** Analisa saúde do PostgreSQL, identifica queries lentas via EXPLAIN ANALYZE, recomenda indexes, valida segurança de migrations, e monitora bloat/vacuum.

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
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | Review any PT-BR text — docs, strings, comments, agent outputs, READMEs |

**What it does:** Brazilian Portuguese reviewer at ENEM perfect score level. Covers 11 axes of normative grammar:

| Axis | What it detects |
|------|------------------------|
| **Ortografia** | "necesário" → "necessário", uso de S/SS/Ç/SC/X/Z, G/J, CH/X |
| **Acentuação** | Proparoxítonas sem acento, hiatos, acentos diferenciais (pôr/por, têm/tem) |
| **Acordo Ortográfico 2009** | "idéia" → "ideia", "vôo" → "voo", regras de hífen com prefixos |
| **Concordância verbal** | "Fazem dois anos" → "Faz dois anos" (haver/fazer impessoais) |
| **Concordância nominal** | "menas" (não existe), "meio nervosa" (invariável como advérbio) |
| **Regência** | "Assisti o jogo" → "Assisti ao jogo", "Prefiro X do que Y" → "Prefiro X a Y" |
| **Crase** | Obrigatória (à noite, às 10h), proibida (antes de verbos, masculinos) |
| **Colocação pronominal** | "Me disseram" → "Disseram-me", próclise/mesóclise/ênclise |
| **Pontuação** | Vírgula entre sujeito e verbo (proibida), vocativo sem vírgula, adjunto deslocado |
| **Vícios de linguagem** | "subir para cima", "elo de ligação", "surpresa inesperada" (pleonasmos) |
| **Confusões clássicas** | mas/mais, mal/mau, há/a, onde/aonde, a fim/afim |

**Absolute scope:**
- SOMENTE texto PT-BR — ignora completamente texto em outros idiomas
- NUNCA altera nomes de variáveis, funções ou identificadores de código
- NUNCA altera termos técnicos em inglês (ex: "SQL injection", "deploy")

**Output:** Findings with `file:line` + Recurring patterns + SUMMARY

**Tested against:** 60+ erros propositais em 10 categorias. Coverage: ~95%. False positives: 0.

---

### grammar-reviewer

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | Review any English text — docs, strings, comments, agent outputs, READMEs |

**What it does:** American English reviewer at GRE Analytical Writing score 6/6 (perfect score) level. Covers 10 axes:

| Axis | What it detects |
|------|------------------------|
| **Spelling** | "occured" → "occurred", "definately" → "definitely" (40+ palavras mais erradas) |
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
- SOMENTE texto em inglês — ignora completamente texto em outros idiomas
- NUNCA altera nomes de variáveis, funções ou identificadores de código
- Enforce American English spelling (nunca British)

**Output:** Findings with `file:line` + Recurring patterns + SUMMARY

**Tested against:** 80+ erros propositais em 11 categorias. Coverage: ~98%. False positives: 0.

---

## Strategy Squad

### seo-reviewer

| Field | Value |
|-------|-------|
| **Model** | Haiku |
| **Type** | Read-only |
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | After UI changes, new pages, before deploy — audit technical SEO |

**What it does:** Technical SEO auditor that reviews code and web content for search engine optimization. Covers 8 areas:

| Area | What it checks |
|------|---------------|
| **Core Web Vitals** | LCP ≤2.5s, INP ≤200ms, CLS ≤0.1 — hero image lazy (BAD), blocking JS/CSS, missing dimensions |
| **Crawlability** | robots.txt (bloqueando CSS/JS?), XML sitemap (existe?), canonical URLs, hreflang |
| **Indexability** | noindex acidental, redirect chains, soft 404s, status codes |
| **Meta tags** | Title (50-60 chars, keyword first), description (150-160 chars), viewport, canonical |
| **Structured data** | JSON-LD: Organization, WebSite, BreadcrumbList, Article, Product, FAQ — valida Rich Results |
| **Rendering** | SSR/SSG para SEO-critical pages, CSR flagado como HIGH, hash routing, JS-only nav |
| **Images** | Alt text, width/height (CLS), lazy loading, format (AVIF/WebP), srcset, fetchpriority |
| **Content** | Heading hierarchy (1x H1, sem skip), internal linking, semantic HTML, keyword stuffing |

**Extras:**
- Detecta framework automaticamente (Next.js, React, Astro) e aplica regras framework-specific
- Social meta tags (Open Graph, Twitter Card)
- 20 erros SEO comuns ranqueados por severidade (CRITICAL→LOW)
- SEO & acessibilidade overlap

**Output:** Surface Area (pages, stack, rendering) + Findings + Quick Wins + SUMMARY

**Tested against:** ~20 erros propositais em 9 categorias. Coverage: ~85%. False positives: 0.

---

### tech-recruiter

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only (analysis) |
| **Tools** | Read, Grep, Glob, Bash |
| **When to use** | Hire devs — JDs, candidate evaluation, interview design, hiring processes |

**What it does:** Tech recruitment specialist with 4 operation modes:

**Modo 1 — Revisão de Job Description:**
- Avalia estrutura, requisitos (max 6 must-haves), linguagem inclusiva, bias de gênero/idade
- Score 1-10 com justificativa
- Reescreve a JD se score < 7
- Detecta: títulos "Ninja/Rockstar", salários ocultos, requisitos impossíveis (ex: "10+ anos de React")

**Modo 2 — Avaliação de Candidato:**
- Analisa perfil LinkedIn (tenure, crescimento, recomendações, headline)
- Analisa GitHub (consistência, qualidade, READMEs, commit messages, contribuições OS)
- Analisa currículo (red flags: buzzwords sem contexto, "expert in 25+ languages")
- Avalia código (SQL injection, secrets hardcoded, bare except, god functions)
- Determina seniority: Junior / Mid / Senior / Staff com justificativa concreta
- **Growth potential**: avalia se o candidato pode crescer para o nível desejado e em qual prazo
- **Alternative fit**: se não é adequado para esta vaga, sugere qual vaga/nível seria ideal
- Recomendação: ADVANCE / HOLD / PASS — cada uma com next steps concretos

**Modo 3 — Design de Entrevista:**
- Pipeline por nível (Junior→Staff) com assessment types adequados
- Perguntas técnicas por stack (Python/FastAPI, TypeScript/React, DevOps, Go)
- Perguntas comportamentais (STAR method, 7 categorias essenciais)
- System design (URL shortener→payment system por nível)
- Rubric de scoring padronizada

**Modo 4 — Auditoria de Processo:**
- Funil de conversão (benchmarks 2026)
- Métricas: time-to-hire, cost-per-hire, offer acceptance rate
- Bias detection no processo (affinidade, confirmação, halo/horn)
- D&I: blind screening, painéis diversos, structured interviews

**Modo 5 — Profile Assessment / "Qual meu nível?" (NOVO):**

Avaliação de seniority usando o framework de 5 eixos (baseado em engineeringladders.com + calibração FAANG):

| Eixo | O que mede | Score 1 (Junior) → Score 5 (Principal) |
|------|-----------|----------------------------------------|
| **Technology** | Profundidade técnica | Adopts → Specializes → Evangelizes → Masters → Creates |
| **System** | Design de sistemas | Enhances → Designs → Owns → Evolves → Leads |
| **People** | Mentoring e liderança | Learns → Supports → Mentors → Coordinates → Manages |
| **Process** | Maturidade de processos | Follows → Enforces → Challenges → Adjusts → Defines |
| **Influence** | Escopo de impacto | Subsystem → Team → Multiple Teams → Company → Community |

Entrega:
- **Scorecard 5 eixos** com evidência para cada score
- **Nível calibrado** (Junior/Mid/Senior/Staff/Principal) + equivalência FAANG (L3-L8)
- **Profile shape** (I/T/Pi/M-shaped) com análise
- **Skills gap analysis** com tempo estimado de fechamento e estratégia
- **Growth roadmap** personalizado (quick wins + médio prazo + riscos de plateau)
- **Market positioning** com pesquisa de mercado (WebSearch) — salário esperado, fit de empresas
- **IC vs Management** — recomendação baseada nos sinais observados
- **Title calibration** — se o título atual não condiz com o nível real

**Modo 6 — Salary/Offer Review (NOVO):**
- Posicionamento no mercado (P25/P50/P75) com fontes datadas
- Breakdown de total compensation (base + equity + bonus + benefits)
- Análise competitiva: a oferta atrai talento ou perde para concorrentes?
- Recomendações de ajuste com justificativa

**Reference data:**
- Benchmarks salariais por região (US, EU, BR, LATAM)
- Funnel rates (191 applications/hire, 82% offer acceptance)
- Sourcing effectiveness (referrals = 11x inbound, internal = 32x)
- Onboarding 30/60/90 dias
- Career ladder mapping: FAANG (L3-L8), Stripe (L1-L5), Radford (P1-P6)
- Timeline médio entre níveis: Junior→Mid (1-2a), Mid→Senior (2-4a), Senior→Staff (3-5a)

**Ferramentas:** Read, Grep, Glob, Bash, **WebSearch, WebFetch** (validação de mercado em tempo real)

**Output:** Varia por modo — sempre com alternativas concretas (nunca só crítica)

**Tested against:** JD com 17 erros + candidato com 35 red flags. Coverage: ~98%. False positives: 0.

---

## Editorial Squad

Full professional editorial pipeline for journalistic, technical, and academic content production. All agents operate under [Sourcing Discipline Protocol](../rules/sourcing-discipline.md) — minimum 3-source triangulation, primary > secondary > tertiary hierarchy, mandatory citation with URL and date, never fabricate sources.

**Recommended pipeline:**

```
editor-chefe → jornalista → redator → fact-checker → editor-de-texto → ortografia-reviewer
  (pauta)      (apura)      (escreve)  (verifica)     (lapida)          (revisa)
```

**Technical parallel path:** `escritor-tecnico` → `ortografia-reviewer` (pula jornalista/fact-checker para conteúdo técnico/acadêmico).

### editor-chefe

| Field | Value |
|-------|-------|
| **Model** | Opus |
| **Type** | Read-only (direction) |
| **Tools** | Read, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Start of editorial project: define story angle, editorial line, approve scope |

**What it does:** Transforma ideias vagas em pautas executáveis com ângulo diferenciado. Avalia newsworthiness, calibra escopo, mapeia fontes necessárias, aplica código FENAJ e identifica riscos éticos/jurídicos/editoriais. Não apura nem escreve — decide o QUÊ e o PORQUÊ.

**Output:** Pauta estruturada (tipo, pergunta-central, ângulo, newsworthiness, tese provisória, fontes necessárias, riscos, escopo, linha editorial, referências, próximos passos).

---

### jornalista

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write (investigation) |
| **Tools** | Read, Write, Grep, Glob, WebSearch, WebFetch, Bash |
| **When to use** | Investigate story approved by editor-chefe — investigation, interviews, triangulation |

**What it does:** Apuração rigorosa com metodologia profissional — desk research, identificação de fontes, entrevistas com condição de atribuição explícita (on the record / background / deep background / off), verificação cruzada, busca obrigatória do "outro lado". Entrega material bruto estruturado para o redator. Rule of Two aplicado: Bash apenas para processamento local, nunca curl/wget/scp externos.

**Output:** Material apurado (fatos confirmados com fontes trianguladas, citações literais, documentos, outro lado, cronologia, pontos sensíveis, lacunas, recomendação de ângulo).

---

### redator

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Transform investigated material into publishable editorial text |

**What it does:** Escolhe gênero (notícia, reportagem, perfil, entrevista, análise, opinião, crônica), estrutura, lead (5W2H, anedótico, descritivo, contrastivo, citacional, estatístico), nut graph (quando necessário), fechamento aceito (circular, citação forte, futuro aberto, detalhe simbólico). Aplica rigor com verbos de atribuição (afirmou ≠ alegou ≠ confessou), linguagem jurídica (suspeito/réu/indiciado/condenado conforme momento processual) e estilo PT-BR profissional. Nunca adiciona fatos — usa só o material apurado.

**Output:** Texto editorial pronto conforme gênero escolhido + justificativa de lead + fontes citadas + lacunas identificadas.

---

### escritor-tecnico

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Technical/scientific writing: academic articles, documentation, ADRs, design docs, post-mortems, presentations |

**What it does:** Produção (não revisão) de textos técnicos e acadêmicos seguindo normas consagradas. Cobre 10 tipos de documento: trabalho ABNT (NBR 14724:2024, 6023:2018, 10520:2023), artigo científico IMRAD, documentação técnica Diátaxis (tutorial/how-to/reference/explanation), ADR formato Nygard, design doc Google style, post-mortem SRE blameless, relatório executivo Minto/BLUF, README excelente, changelog (Keep a Changelog + SemVer), slides (Duarte/Knaflic + 10/20/30 Kawasaki).

**Output:** Documento pronto no formato canônico apropriado + fontes citadas + lacunas.

---

### fact-checker

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Read-only (independent verification) |
| **Tools** | Read, Grep, Glob, WebSearch, WebFetch, Bash |
| **When to use** | Verify factual claims in produced texts — **Rule of Two applied to journalism** |

**What it does:** Verificação independente seguindo metodologia das agências brasileiras (Lupa, Aos Fatos, AFP Checamos, Comprova, Estadão Verifica). 8 passos: seleção → levantamento → bases oficiais → LAI → campo → especialistas → resposta da parte checada → publicar com etiqueta. Classifica cada alegação com uma das 7 etiquetas Lupa 2023+: VERDADEIRO, FALSO, EXAGERADO, SUBESTIMADO, CONTRADITÓRIO, INSUSTENTÁVEL, FALTA CONTEXTO. Nunca aceita trabalho do redator como verdade — re-verifica independentemente.

**Output:** Relatório de verificação estruturado (alegações verificadas + classificação + fontes + correções sugeridas + recomendação final: PUBLICAR / PUBLICAR COM CORREÇÕES / DEVOLVER AO REDATOR / DEVOLVER AO JORNALISTA / NÃO PUBLICAR).

---

### editor-de-texto

| Field | Value |
|-------|-------|
| **Model** | Sonnet |
| **Type** | Write (editing) |
| **Tools** | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch |
| **When to use** | Final editing of editorial texts — cuts, sharpens, reorganizes, applies FENAJ |

**What it does:** 4 operações cirúrgicas — CORTAR (reduzir 20-40% eliminando redundâncias, adjetivação ociosa, fillers, perífrases, corporativês), AFIAR (substituir genérico por preciso), REORGANIZAR (lead fraco, nut graph ausente, informação enterrada, fechamento seco), AJUSTAR RITMO (frases longas vs curtas, parágrafos). Aplica checklist FENAJ completo, verifica presunção de inocência (suspeito/réu/indiciado/condenado), elimina clichês jornalísticos proibidos ("tragédia anunciada", "em meio a", "cabe à sociedade refletir"). Nunca adiciona fatos — só edita o existente.

**Output:** Texto editado final + diff de edição (cortes, correções de atribuição, correções jurídicas, clichês removidos) + métricas de redução + checklist FENAJ + problemas não-resolvíveis que exigem devolução.
