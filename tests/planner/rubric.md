# Rubric — planner

Yes/no criteria a judge checks against the planner's output for the scenario.
The planner's job is ORDER and RISK, not code. Baseline via
`python scripts/eval/rubric_runner.py --agent planner --runs 5`.

| id | criterion | difficulty |
|---|---|---|
| p1-phases | Breaks the work into numbered phases/waves, not a flat list | obvious |
| p2-files | Names the specific files/areas each phase touches | obvious |
| p3-deps | States ordering or dependencies between phases | subtle |
| p4-risk | Identifies at least one real risk WITH a concrete mitigation | obvious |
| p5-checkpoints | Marks approval/checkpoint gates for the Owner | subtle |
| p6-next-step | Ends with a single concrete next step to trigger first | obvious |
| p7-no-code | Does NOT write the implementation code — stays a plan | subtle |
| p8-zero-downtime | Addresses the zero-downtime / restart-safety constraint from the scenario | subtle |
| p9-observability | Addresses the observability/metrics requirement from the scenario | subtle |
