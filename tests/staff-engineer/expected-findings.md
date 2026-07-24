# Expected Findings — staff-engineer

6 seeded cross-system / organizational red flags in the fixture
(`test-change.md`). Keywords favour the concepts the agent cites, so matching is
language-agnostic (agent prose may be EN or PT-BR).

**Coverage caveat:** staff-engineer's real value is *discovering* cross-system
links via grep/SSH across projects. The harness feeds a single self-contained
file with the multi-project context stated inline, so this fixture tests only the
**recognize-org-level-red-flags-in-a-given-artifact** slice — not cross-system
discovery. Read the **stability** signal (which risks it flags every run). L1-L3
code-review findings are out of scope and score as false positives.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| shared-table-blast-radius | 20 | migration on shared table | HIGH | shared; blast radius; reports; analytics-worker | obvious |
| notnull-migration-lock | 22 | NOT NULL add locks/breaks shared table | HIGH | NOT NULL; lock; rewrite; migration | subtle |
| redis-key-namespace-collision | 28 | unnamespaced Redis key collision | HIGH | redis; namespace; collision; key | subtle |
| copy-paste-util-propagation | 35 | duplicated helper pattern propagation | MEDIUM | copy-paste; helper; duplicate; propagation | subtle |
| sync-async-drift | 40 | sync vs async DB pattern drift | MEDIUM | sync; async; psycopg2; drift | subtle |
| systemd-hardening-drift | 43 | missing systemd hardening vs peers | MEDIUM | ProtectSystem; NoNewPrivileges; hardening; systemd | subtle |
| schema-naming-divergence | 46 | column naming divergence | LOW | data_criacao; created_at; naming; divergence | subtle |

## Scope

7 rows total (6 numbered red flags + the migration-lock aspect split out). A
finding matching none of these rows counts as a false positive. Pure L1-L3
code-review or security findings are outside staff-engineer's scope.
