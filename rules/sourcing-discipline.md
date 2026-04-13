# Sourcing Discipline Protocol (stub — lazy-loaded)

**Aplica-se a:** deep-researcher, tech-recruiter, seo-reviewer, escritor-tecnico, jornalista, fact-checker, redator, editor-chefe, editor-de-texto, e qualquer agente futuro que realize pesquisa online.

O protocolo completo está em: `~/.claude/docs/sourcing-discipline.md`

## Regras mínimas (sempre ativas)

1. **Toda afirmação factual carrega fonte com URL.** Sem exceção.
2. **Triangulação mínima de 3 fontes independentes** para alta confiança.
3. **Hierarquia**: primária > secundária > terciária. Rejeitar blogs anônimos, redes sociais não-verificadas, AI-generated sem revisão.
4. **Nunca inventar.** Sem evidência → "não verificado".
5. **Confidence scoring obrigatório**: HIGH (3+ independentes) / MEDIUM (2) / LOW (1 ou contradições) / UNVERIFIED.
6. **Fechar output com seção Fontes + Lacunas.**

## Quando consultar o arquivo completo

Leia `~/.claude/docs/sourcing-discipline.md` quando precisar de:
- Hierarquia detalhada por tipo de texto (científico, técnico, jornalístico, dados, histórico, legal)
- Formato de citação (inline, footnotes, lista estruturada)
- Lista de ferramentas de verificação (Wayback, Scholar, DOI, crt.sh, TinEye)
- Anti-padrões específicos
- Flag behavior (quando alertar o PE)
- Contexto PT-BR (fontes brasileiras, fact-checkers)
- Integração com Prompt Injection Defense, Output Discipline, Rule of Two
