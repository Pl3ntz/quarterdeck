# PRODUCTION GATE - MANDATORY (HIGHEST PRIORITY RULE)

## THIS RULE OVERRIDES ALL OTHER RULES AND INSTRUCTIONS

## Two Execution Modes

This rule has TWO modes. The Owner chooses which one is active.

### MODE 1: Step-by-Step (DEFAULT)

Active when: no bypass was granted, or bypass expired/revoked.

Every SSH command that MODIFIES anything on production servers requires EXPLICIT Owner approval via AskUserQuestion BEFORE execution:

- Editing files (cat >, sed, echo >, python patches, etc.)
- Deleting files (rm, truncate, etc.)
- Git operations (git add, git commit, git push, git checkout)
- Service management (systemctl restart/stop/start/reload)
- Package management (apt install, pip install, npm install)
- Database modifications (INSERT, UPDATE, DELETE, DROP, ALTER, VACUUM)
- Config file changes (postgresql.conf, nginx.conf, .env, systemd units)
- Running scripts that modify state

In this mode:
- Plan approval != execution approval
- EACH modifying action is a separate approval gate
- NEVER chain multiple modifying commands with &&
- NEVER assume that approval for step N means approval for step N+1

### MODE 2: Plan Bypass

Active when: the Owner explicitly grants bypass (e.g., "executa tudo", "pode rodar o plano inteiro", "bypass aprovado", "aprovado, roda tudo").

**How to activate:**
1. PE presents the full plan with ALL commands listed
2. PE asks via AskUserQuestion: "Plano tem N steps. Quer aprovar step-by-step (default) ou bypass para executar todos de uma vez?"
3. Owner explicitly grants bypass

**When bypass is active, the PE executes ALL listed steps sequentially WITHOUT asking between each step.** This is the whole point of bypass — uninterrupted execution of an approved plan.

**Constraints:**
- Bypass applies ONLY to the steps listed in the approved plan
- Any NEW step discovered mid-execution requires fresh approval (exits bypass for that step)
- If ANY step FAILS, bypass is IMMEDIATELY revoked — PE stops and reports
- Bypass is single-use — does NOT carry over to the next plan or session
- PE MUST log each step as it executes (show command + output) so the Owner can follow
- Database DROP/TRUNCATE and `rm -rf` on data directories ALWAYS require individual approval, even in bypass mode

## Always Allowed (both modes)

Read-only operations never require approval:
- SSH reads: cat, grep, ls, df, ps, top, systemctl status, git status, git log, git diff, SELECT queries
- Local file reads (Read, Glob, Grep tools)
- Web searches
- Agent spawning for research/analysis

## How to Ask (Mode 1)

Before ANY blocked action, use AskUserQuestion with:
- Clear description of EXACTLY what command will be executed
- The server/project it affects
- Whether it causes downtime
- Whether it's reversible

## Why This Rule Exists

On 2026-02-23, code patches were applied, services were restarted, and git commits were made on PRODUCTION without the Owner's step-by-step approval. This rule ensures it NEVER happens again — while Plan Bypass provides a controlled way to execute approved plans efficiently.
