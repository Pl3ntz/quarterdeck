# Catálogo de Agentes

Referência rápida de todos os 20 agentes, organizados por squad.

---

## Planning & Design Squad

### architect

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only (análise) |
| **Ferramentas** | Read, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Decisões de arquitetura, design de sistema, avaliação de trade-offs |

**O que faz:** Analisa a arquitetura atual e propõe decisões de design com alternativas e trade-offs. Sempre apresenta múltiplas opções — nunca uma solução única.

**Output:** Decisão de design + tabela de alternativas (prós/contras) + trade-offs + RESUMO

---

### planner

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only (análise) |
| **Ferramentas** | Read, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Features complexas que precisam de plano faseado com riscos e dependências |

**O que faz:** Cria planos de implementação detalhados com fases, passos, riscos e mitigações. Cada passo referencia file paths específicos.

**Output:** Plano em fases + riscos + RESUMO

---

## Quality Gate Squad

> Todos os agentes deste squad são **read-only** e **sempre rodam em paralelo**.

### code-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **Quando usar** | Após escrever ou modificar código — valida qualidade, segurança e manutenabilidade |

**O que faz:** Revisa código por prioridade: CRITICAL (segurança, perda de dados) > HIGH (lógica, error handling) > MEDIUM (qualidade, performance) > LOW (estilo, naming). Verifica patterns Python/FastAPI e TypeScript.

**Modos especiais (BMAD cherry-picks):**
- **Blind Review** (`--blind`): Recebe APENAS o diff, sem contexto do projeto. Quebra anchoring bias — encontra problemas que o contexto "normaliza". Usado como camada adicional, não substituta.
- **Surface Area Stats**: Métricas quantitativas no início do output (arquivos alterados, módulos, linhas de lógica, boundary crossings, novas interfaces públicas).
- **Concern-based grouping**: Agrupa achados por intenção da mudança (concern), não por arquivo. Ajuda o Captain a entender a mudança como um todo.

**Output:** Surface Area Stats + Achados ordenados por severidade + Por Concern + RESUMO

---

### security-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Auditoria de infraestrutura, hardening, secrets, firewall, SSL, systemd |

**O que faz:** Audita segurança de infraestrutura (SSH, firewall, systemd, PostgreSQL, Redis, Nginx, SSL). Diferente do code-reviewer — foca em infra, não em patterns de código.

**Output:** Tabela de ameaças por área + achados + RESUMO

---

### ux-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **Quando usar** | Após mudanças de UI — acessibilidade (WCAG 2.2 AA), consistência, estados de interação |

**O que faz:** Revisa frontend por acessibilidade, contraste, navegação por teclado, touch targets, design consistency, estados de interação (hover, focus, disabled, loading, error, empty).

**Output:** Achados ordenados por impacto no usuário + RESUMO

---

### staff-engineer

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash, Skill(local-mind:super-search) |
| **Quando usar** | Mudanças que afetam múltiplos projetos ou infraestrutura compartilhada |

**O que faz:** Avalia impacto organizacional (L4): cross-system dependencies, propagação de padrões, dívida técnica com impacto no negócio.

**Output:** Impacto cross-system + propagação de padrão + dívida técnica + RESUMO

---

## Implementation Squad

> Todos os agentes deste squad **escrevem código** e precisam de **zone assignment** do PE.

### tdd-guide

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Write (escrita de código) |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | Novas features, bug fixes, refactoring — sempre com testes primeiro |

**O que faz:** Implementa usando TDD (Red-Green-Refactor). Escreve testes primeiro, depois implementação mínima para passar. Garante cobertura 80%+.

**Output:** Testes escritos + cobertura + RESUMO

---

### e2e-runner

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Write |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | Testes de fluxos críticos de usuário com Playwright |

**O que faz:** Cria e executa testes E2E com Playwright. Gerencia testes instáveis (flaky), captura screenshots/vídeos, e usa Page Object Model.

**Output:** Resultados (passou/falhou/instável) + falhas + RESUMO

---

### build-error-resolver

| Campo | Valor |
|-------|-------|
| **Modelo** | Haiku |
| **Tipo** | Write |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | Build falhou, type errors, serviço não inicia |

**O que faz:** Corrige erros de build com minimal diff. Não refatora, não otimiza, não redesenha — apenas corrige o erro e verifica que o build passa.

**Output:** Erros corrigidos + pendentes + RESUMO

---

### refactor-cleaner

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Write |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | Remoção de dead code, cleanup, consolidação de duplicatas |

**O que faz:** Identifica e remove código morto, dependências não utilizadas, e duplicatas. Usa ferramentas de análise (knip, vulture) e verifica todas as referências antes de remover.

**Output:** Itens removidos + impacto + RESUMO

---

## Operations Squad

### incident-responder

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only (diagnóstico) |
| **Ferramentas** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Serviço caiu, erros aumentando, usuários reportando problemas |

**O que faz:** Segue workflow de 5 fases: Triage (2min) > Diagnose (5-10min) > Remediate (opções) > Verify > Document. Nunca executa correções — apenas diagnostica e recomenda.

**Output:** Serviços afetados + causa raiz + opções (rápida vs completa) + RESUMO

---

### devops-specialist

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Write |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | CI/CD, deploy, systemd, monitoring, Nginx, SSL |

**O que faz:** Analisa e melhora pipelines CI/CD, automatiza deploys, configura serviços systemd, e gerencia infraestrutura (Nginx, SSL). Sempre apresenta antes de executar.

**Output:** Achados + mudanças propostas + RESUMO

---

### performance-optimizer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Serviço lento, recursos limitados, antes de decisões de scaling |

**O que faz:** Mede métricas de sistema (CPU, memória, disco), analisa queries PostgreSQL lentas, Redis, Nginx tuning, e patterns async Python/FastAPI. Sempre com valores medidos, nunca suposições.

**Output:** Métricas + gargalos + RESUMO

---

### database-specialist

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Bash, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Design de schema, queries lentas, indexação, migrations, saúde do banco |

**O que faz:** Analisa saúde do PostgreSQL, identifica queries lentas via EXPLAIN ANALYZE, recomenda indexes, valida segurança de migrations, e monitora bloat/vacuum.

**Output:** Achados com evidência de EXPLAIN ANALYZE + RESUMO

---

## Intelligence Squad

### deep-researcher

| Campo | Valor |
|-------|-------|
| **Modelo** | Opus |
| **Tipo** | Read-only (pesquisa web) |
| **Ferramentas** | WebSearch, WebFetch, Bash, Read, Grep, Glob, Skill(local-mind:super-search) |
| **Quando usar** | Pesquisa profunda multi-fonte, comparações, OSINT, triangulação |

**O que faz:** Pesquisa em 6 fases: Plan > Search > Distill > Evaluate > Iterate > Synthesize. Usa 7 estratégias de reformulação de queries. Toda afirmação precisa de 3+ fontes para confiança HIGH.

**Output:** Achados com nível de confiança + contradições + lacunas + RESUMO

---

### doc-updater

| Campo | Valor |
|-------|-------|
| **Modelo** | Haiku |
| **Tipo** | Write |
| **Ferramentas** | Read, Write, Edit, Bash, Grep, Glob |
| **Quando usar** | Atualizar codemaps, READMEs, documentação |

**O que faz:** Gera e atualiza documentação baseada no código real. Nunca documenta de memória — sempre lê o codebase atual primeiro.

**Output:** Alterações realizadas + RESUMO

---

## Language Squad

> Agentes de revisão linguística. **Read-only**, escopo restrito ao idioma — nunca tocam em código, variáveis, ou texto de outro idioma.

### ortografia-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash |
| **Quando usar** | Revisar qualquer texto PT-BR — docs, strings, comments, agent outputs, READMEs |

**O que faz:** Revisor de português brasileiro de nível ENEM nota 1000. Cobre 11 eixos da gramática normativa:

| Eixo | Exemplos do que detecta |
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

**Escopo absoluto:**
- SOMENTE texto PT-BR — ignora completamente texto em outros idiomas
- NUNCA altera nomes de variáveis, funções ou identificadores de código
- NUNCA altera termos técnicos em inglês (ex: "SQL injection", "deploy")

**Output:** Achados com `arquivo:linha` + Padrões recorrentes + RESUMO

**Testado contra:** 60+ erros propositais em 10 categorias. Cobertura: ~95%. Falsos positivos: 0.

---

### grammar-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash |
| **Quando usar** | Revisar qualquer texto em inglês — docs, strings, comments, agent outputs, READMEs |

**O que faz:** Revisor de inglês americano de nível GRE Analytical Writing score 6/6 (nota máxima). Cobre 10 eixos:

| Eixo | Exemplos do que detecta |
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

**Escopo absoluto:**
- SOMENTE texto em inglês — ignora completamente texto em outros idiomas
- NUNCA altera nomes de variáveis, funções ou identificadores de código
- Enforce American English spelling (nunca British)

**Output:** Findings com `file:line` + Recurring patterns + SUMMARY

**Testado contra:** 80+ erros propositais em 11 categorias. Cobertura: ~98%. Falsos positivos: 0.

---

## Strategy Squad

### seo-reviewer

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only |
| **Ferramentas** | Read, Grep, Glob, Bash |
| **Quando usar** | Após mudanças de UI, novas páginas, antes de deploy — auditar SEO técnico |

**O que faz:** Auditor SEO técnico que revisa código e conteúdo web para otimização de motores de busca. Cobre 8 áreas:

| Área | O que verifica |
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

**Output:** Surface Area (pages, stack, rendering) + Findings + Quick Wins + RESUMO

**Testado contra:** ~20 erros propositais em 9 categorias. Cobertura: ~85%. Falsos positivos: 0.

---

### tech-recruiter

| Campo | Valor |
|-------|-------|
| **Modelo** | Sonnet |
| **Tipo** | Read-only (análise) |
| **Ferramentas** | Read, Grep, Glob, Bash |
| **Quando usar** | Contratar devs — JDs, avaliação de candidatos, design de entrevistas, processos seletivos |

**O que faz:** Especialista em recrutamento tech com 4 modos de operação:

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
- Recomendação: ADVANCE / HOLD / PASS

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

**Dados de referência:**
- Benchmarks salariais por região (US, EU, BR, LATAM)
- Funnel rates (191 applications/hire, 82% offer acceptance)
- Sourcing effectiveness (referrals = 11x inbound, internal = 32x)
- Onboarding 30/60/90 dias

**Output:** Varia por modo (JD Score + Rewrite / Candidate Assessment + Seniority / Interview Plan / Findings + RESUMO)

**Testado contra:** JD com 17 erros + candidato com 35 red flags. Cobertura: ~98%. Falsos positivos: 0.
