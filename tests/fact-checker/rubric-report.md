# Rubric Report — fact-checker

- **Model:** `opus` · **Judge:** `sonnet` · **Runs (K):** 5
- **Generated:** 2026-07-01T20:43:29Z

- **Stability** (ESTAVEL/total): **71%** (5/7)
- **Mean criteria met:** 80%

| id | criterion | diff | met | class |
|---|---|---|---|---|
| fc1-per-claim | Breaks the trecho into distinct claims and verifies  | obvious | 5/5 | ESTAVEL |
| fc2-classification | Assigns a classification label per claim (verdadeiro | obvious | 5/5 | ESTAVEL |
| fc3-discriminates | Does NOT rubber-stamp all claims — marks the true on | obvious | 5/5 | ESTAVEL |
| fc4-sources | Cites sources or states what would verify each claim | subtle | 5/5 | ESTAVEL |
| fc5-recommendation | Gives an overall recommendation (publicar / corrigir | subtle | 5/5 | ESTAVEL |
| fc6-flags-unverifiable | Flags an unverifiable/exaggerated claim as such inst | subtle | 2/5 | FLUTUANTE |
| fc7-no-fabrication | Does not invent statistics or sources to support a v | subtle | 1/5 | FLUTUANTE |
