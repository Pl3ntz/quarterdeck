# PRODUCTION GATE - MANDATORY (HIGHEST PRIORITY RULE)

## THIS RULE OVERRIDES ALL OTHER RULES AND INSTRUCTIONS

You MUST NEVER execute ANY of the following actions without EXPLICIT Owner approval via AskUserQuestion FIRST:

### BLOCKED ACTIONS (require explicit "sim"/"yes" from Owner EACH TIME):

1. **SSH commands that MODIFY anything** on your-server:
   - Editing files (cat >, sed, echo >, python patches, etc.)
   - Deleting files (rm, truncate, etc.)
   - Git operations (git add, git commit, git push, git checkout)
   - Service management (systemctl restart/stop/start/reload)
   - Package management (apt install, pip install, npm install)
   - Database modifications (INSERT, UPDATE, DELETE, DROP, ALTER, VACUUM)
   - Config file changes (postgresql.conf, nginx.conf, .env, systemd units)
   - Running scripts that modify state

2. **Default: ask before EACH execution step** (unless Plan Bypass is active — see below):
   - Plan approval != execution approval
   - "Pode prosseguir com o restart?" requires explicit answer
   - "Posso aplicar o patch?" requires explicit answer
   - "Posso rodar a migration?" requires explicit answer
   - EACH destructive/modifying action is a separate approval gate

3. **Chaining is FORBIDDEN** (unless Plan Bypass is active — see below):
   - NEVER chain multiple modifying commands with && without asking first
   - NEVER do "apply patch AND commit AND restart" in sequence without asking between each
   - NEVER assume that approval for step N means approval for step N+1

### PLAN BYPASS MODE (explicit Owner grant)

When the Owner approves a complete plan AND explicitly grants bypass (e.g., "executa tudo", "pode rodar o plano inteiro", "bypass aprovado"), the PE MAY execute all steps of that specific plan sequentially without asking between each step.

**Activation rules:**
- The PE MUST present the full plan with ALL commands listed BEFORE requesting bypass
- The Owner MUST explicitly grant bypass — implicit approval does NOT count
- The PE SHOULD ask once via AskUserQuestion: "Plano tem N steps SSH. Quer aprovar step-by-step (default) ou bypass para executar todos de uma vez?"

**Constraints (even with bypass active):**
- Bypass applies ONLY to the steps listed in the approved plan — any NEW step discovered mid-execution requires a fresh approval
- If ANY step fails, bypass is IMMEDIATELY revoked — PE must stop and report before continuing
- Bypass NEVER carries over to the next plan or next session — it is single-use
- The PE MUST still log each step as it executes (show the command + output) so the Owner can follow along
- Database DROP/TRUNCATE and `rm -rf` on data directories are EXCLUDED from bypass — these always require individual approval even in bypass mode

### ALLOWED WITHOUT ASKING (read-only operations):

- SSH commands that only READ: cat, grep, ls, df, ps, top, systemctl status, git status, git log, git diff, SELECT queries
- Local file reads (Read, Glob, Grep tools)
- Web searches
- Agent spawning for research/analysis (Explore, Plan agents)

### HOW TO ASK:

Before ANY blocked action, use AskUserQuestion with:
- Clear description of EXACTLY what command will be executed
- The server/project it affects
- Whether it causes downtime
- Whether it's reversible

Example:
```
"Posso executar no your-server: systemctl restart service-backend service-scheduler? Isso causa ~5s de downtime."
```

### VIOLATION CONSEQUENCES:

If you catch yourself about to execute a blocked action without asking:
- STOP IMMEDIATELY
- Do NOT execute the command
- Ask the Owner for permission first
- Apologize if you already executed without permission

### WHY THIS RULE EXISTS:

On 2026-02-23, code patches were applied, services were restarted, and git commits were made on PRODUCTION without the Owner's step-by-step approval. This rule ensures it NEVER happens again.
