# Rubric — fact-checker

Yes/no criteria a judge checks against the fact-checker's verification report for
the scenario. The trecho mixes a true claim (PIX launched Nov 2020), an
exaggerated/unverified one (>90% use daily), and false ones (eliminated cash;
only country with free instant payments). Baseline via
`python scripts/eval/rubric_runner.py --agent fact-checker --runs 5`.

**Web-dependency caveat:** the headless harness gives the agent no reliable
WebSearch/WebFetch, which is fact-checker's core method. So `fc6-flags-unverifiable`
and `fc7-no-fabrication` measure the WORST case (verify-from-memory) and run low
(baseline 2/5 and 1/5) — a real signal that this agent must not be trusted without
live sourcing. The structural criteria (fc1–fc5) are stable at 5/5. A faithful
correctness/non-fabrication eval needs a web-enabled harness — tracked as future work.

| id | criterion | difficulty |
|---|---|---|
| fc1-per-claim | Breaks the trecho into distinct claims and verifies each separately | obvious |
| fc2-classification | Assigns a classification label per claim (verdadeiro/falso/exagerado/...) | obvious |
| fc3-discriminates | Does NOT rubber-stamp all claims — marks the true one true and a false one false | obvious |
| fc4-sources | Cites sources or states what would verify each claim | subtle |
| fc5-recommendation | Gives an overall recommendation (publicar / corrigir / devolver) | subtle |
| fc6-flags-unverifiable | Flags an unverifiable/exaggerated claim as such instead of asserting | subtle |
| fc7-no-fabrication | Does not invent statistics or sources to support a verdict | subtle |
