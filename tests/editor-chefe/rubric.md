# Rubric — editor-chefe

Yes/no criteria a judge checks against the editor-chefe's output (a PAUTA) for the
scenario. The editor-chefe DIRECTS — defines angle and plan, does not write the
piece. Baseline via `python scripts/eval/rubric_runner.py --agent editor-chefe --runs 5`.

| id | criterion | difficulty |
|---|---|---|
| ec1-angulo | Defines a specific editorial ANGLE, not just restating the topic | obvious |
| ec2-tipo | Specifies the piece type/format (reportagem, análise, perfil...) | obvious |
| ec3-plano | Gives a reporting/structure plan for the piece | obvious |
| ec4-fontes | Suggests concrete sources / who to hear (comerciantes, BC, especialistas) | subtle |
| ec5-newsworthiness | Justifies relevance / why now (newsworthiness) | subtle |
| ec6-linha | Considers audience / editorial line | subtle |
| ec7-directs-not-writes | Delivers a brief that DIRECTS — does not write the finished article | subtle |
