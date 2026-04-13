# PRODUCTION GATE - MANDATORY (HIGHEST PRIORITY RULE)

## THIS RULE OVERRIDES ALL OTHER RULES AND INSTRUCTIONS

You MUST NEVER execute ANY of the following actions without EXPLICIT CTO approval via AskUserQuestion FIRST:

### BLOCKED ACTIONS (require explicit "sim"/"yes" from CTO EACH TIME):

1. **SSH commands that MODIFY anything** on <prod_server>:
   - Editing files (cat >, sed, echo >, python patches, etc.)
   - Deleting files (rm, truncate, etc.)
   - Git operations (git add, git commit, git push, git checkout)
   - Service management (systemctl restart/stop/start/reload)
   - Package management (apt install, pip install, npm install)
   - Database modifications (INSERT, UPDATE, DELETE, DROP, ALTER, VACUUM)
   - Config file changes (postgresql.conf, nginx.conf, .env, systemd units)
   - Running scripts that modify state

2. **Even if the CTO said "sim" to a PLAN, you MUST ask again before EACH execution step:**
   - Plan approval != execution approval
   - "Pode prosseguir com o restart?" requires explicit answer
   - "Posso aplicar o patch?" requires explicit answer
   - "Posso rodar a migration?" requires explicit answer
   - EACH destructive/modifying action is a separate approval gate

3. **Chaining is FORBIDDEN:**
   - NEVER chain multiple modifying commands with && without asking first
   - NEVER do "apply patch AND commit AND restart" in sequence without asking between each
   - NEVER assume that approval for step N means approval for step N+1

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
"Posso executar no <prod_server>: systemctl restart <service_backend> <service_scheduler>? Isso causa ~5s de downtime."
```

### VIOLATION CONSEQUENCES:

If you catch yourself about to execute a blocked action without asking:
- STOP IMMEDIATELY
- Do NOT execute the command
- Ask the CTO for permission first
- Apologize if you already executed without permission

### WHY THIS RULE EXISTS:

On 2026-02-23, code patches were applied, services were restarted, and git commits were made on PRODUCTION without the CTO's step-by-step approval. This rule ensures it NEVER happens again.
