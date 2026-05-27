# Frontend Baseline Viewport (MANDATORY)

> **Versão:** 1.0 (2026-05-21)
> **Localização canônica:** este arquivo (`~/.claude/rules/frontend-baseline-viewport.md`)
> **Cópias embarcadas:** ux-reviewer, e2e-runner, seo-reviewer, skill frontend-patterns
> **Referência no PE rule:** `~/.claude/rules/principal-engineer-always-on.md`

**Aplica-se a:** qualquer agent/skill que projete, gere, revise ou teste interface front-end.

## Regra

Todo conteúdo front-end (componentes, layouts, páginas, testes E2E, auditorias visuais, recomendações UX/SEO) **DEVE** partir do baseline:

| Dimensão | Valor |
|---|---|
| **Viewport baseline** | **1440 × 900 px** |
| **Referência física** | MacBook Air M-series 13" (escala default) |
| **Filosofia** | Projetar PARA 13" primeiro, escalar PARA CIMA para telas maiores |

## O que isso significa na prática

### Design / Layout
- Componentes devem **caber e respirar** em 1440×900 sem scroll horizontal e sem comprimir a ponto de quebrar densidade visual
- `max-width` de containers principais ≤ 1440px (qualquer largura extra em telas maiores vira margem lateral)
- Hierarquia visual e fold (área visível sem scroll) calculados em **900px de altura útil** (descontar ~80px de chrome do browser → ~820px reais)
- Grid system: pensar em 12 cols a 1440px como referência; varia para baixo (mobile/tablet) e mantém ou expande para cima

### Tipografia e densidade
- Tamanhos de fonte e espaçamentos calibrados para legibilidade em 1440×900 a distância de notebook (~50-60cm dos olhos)
- Evitar designs que só fazem sentido em 4K (ex: tipografia gigante, whitespace excessivo) — esses são exceções deliberadas, não default

### Responsividade (escalar PARA CIMA)
- **1440×900 é o piso "desktop"**, não o teto
- Breakpoints adicionais ACIMA (ex: `1920px+`, `2560px+`) recebem variações progressivas: mais densidade, grid expandido, segunda coluna, etc.
- Breakpoints ABAIXO (tablet, mobile) são tratados como adaptações específicas, não como base do design

### Testes E2E (Playwright / browser automation)
- Viewport default em `playwright.config.ts` ou setup equivalente: **1440×900**
- Screenshots de regressão visual: 1440×900
- Adicionar viewports menores (mobile/tablet) como variações específicas, não como substitutos do baseline

### Auditorias (UX, SEO, performance)
- Core Web Vitals e Lighthouse: rodar em 1440×900 como cenário principal
- Reviews de acessibilidade, hierarquia visual, estados de interação: avaliar primeiro em 1440×900
- Reportar problemas que aparecem APENAS em outros viewports separadamente

### Geração de UI (frontend-design, frontend-patterns)
- Mockups, componentes e demos gerados devem assumir 1440×900 como canvas inicial
- Quando gerar código com largura fixa, usar valores que se acomodam em 1440px

## Anti-padrões a evitar

- Projetar para 1920×1080 como default e depois "ajustar" para 13" (gera designs que ficam apertados ou cortam fold em 13")
- Assumir altura "infinita" (scroll vertical sem limite) sem considerar fold de 820px úteis
- Componentes com `min-width` que estourem 1440 (forçam scroll horizontal no baseline)
- Testar/revisar só em fullscreen do dev — sempre validar no viewport real do baseline
- Tratar 13" como "mobile grande" — é desktop com restrições específicas

## Exceções legítimas

Esta regra **não se aplica** quando o Owner definir explicitamente:
- Que a aplicação é mobile-first (smartphone) ou tablet-first
- Que o público-alvo usa monitor externo grande (ex: dashboards de NOC, traders, design pro)
- Que o projeto tem viewport target diferente (ex: TV, kiosk, embedded)

Nesses casos, o agent deve **confirmar com o Owner** antes de aplicar o baseline 1440×900.

## Verificação obrigatória (self-check antes de entregar)

Antes de finalizar qualquer output front-end, valide:

1. **Cabe em 1440×900?** O layout principal não tem overflow horizontal e o fold crítico cabe em ~820px úteis
2. **Escala para cima?** Telas maiores recebem tratamento adequado (max-width, grid expandido, etc.)
3. **Testes refletem o baseline?** Se há E2E/visual regression, o viewport está em 1440×900
4. **Auditoria foi feita no baseline?** Se há review de CWV/UX/SEO, o cenário principal é 1440×900
