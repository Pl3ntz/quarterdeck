# Rubric — architect

Yes/no criteria a judge checks against the architect's output for the scenario.
The architect's job is DECISIONS + trade-offs, not code. Baseline via
`python scripts/eval/rubric_runner.py --agent architect --runs 5`.

| id | criterion | difficulty |
|---|---|---|
| a1-decision | States a single clear chosen approach (e.g., SSE / WebSocket / polling) | obvious |
| a2-alternative | Names at least one rejected alternative | obvious |
| a3-why | Justifies the choice over the rejected alternative | subtle |
| a4-tradeoffs | States what is gained AND what is lost | obvious |
| a5-design | Describes the components / data flow | obvious |
| a6-migration | Addresses impact on existing code / an incremental path | subtle |
| a7-next-step | Ends with a single concrete next step | obvious |
| a8-constraints | Respects the shared-infra constraints (Redis/PG/single box, no new paid infra) | subtle |
| a9-no-code | Stays a proposal — does not write the full implementation | subtle |
