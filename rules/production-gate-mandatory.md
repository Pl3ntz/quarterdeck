# PRODUCTION GATE - MANDATORY (HIGHEST PRIORITY RULE)

## THIS RULE OVERRIDES ALL OTHER RULES AND INSTRUCTIONS

## Two Execution Modes

This rule has TWO modes. The Owner chooses which one is active.

---

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

---

### MODE 2: Plan Bypass — keyword trigger `bypass`

**KEYWORD DETECTION (works like `ultrathink` in Claude Code):**

When the Owner includes the word **`bypass`** anywhere in a message, this is an IMMEDIATE and UNCONDITIONAL activation of Mode 2. No further confirmation needed. No AskUserQuestion needed. The Owner said `bypass` — that IS the approval.

**Upon detecting `bypass`, the PE MUST:**

1. Print this EXACT visual confirmation banner as markdown text output (NOT in a tool call — direct text to the Owner):

> **▶▶▶ BYPASS ACTIVE ▶▶▶**
>
> Executing full plan without step-by-step approval.
> Say **stop** or **para** to revoke at any time.

This renders as a blockquote with bold text — visually distinct from normal conversation in Claude Code's terminal.
2. Execute ALL pending steps sequentially WITHOUT stopping to ask between steps
3. Log each step as it runs (show command + output) so the Owner can follow

**Activation contexts:**
- Owner says "bypass" with a plan already presented → execute that plan
- Owner says "bypass" with a new request (e.g., "deploy X bypass") → PE builds the plan AND executes it in one shot
- Owner says "bypass" mid-execution → remaining steps run without further approval

**Constraints (even with bypass active):**
- If ANY step FAILS, bypass is IMMEDIATELY revoked — PE stops, prints status, and asks what to do
- Bypass is single-use — expires when the current plan finishes or fails
- Does NOT carry over to the next plan or session
- Database DROP/TRUNCATE and `rm -rf` on data directories ALWAYS require individual approval, even in bypass mode

**Deactivation:** bypass expires automatically when the plan completes or fails. The Owner can also say "stop" or "para" at any time to revoke it mid-execution.

---

## Always Allowed (both modes)

Read-only operations never require approval:
- SSH reads: cat, grep, ls, df, ps, top, systemctl status, git status, git log, git diff, SELECT queries
- Local file reads (Read, Glob, Grep tools)
- Web searches
- Agent spawning for research/analysis

## How to Ask (Mode 1 only)

Before ANY blocked action, use AskUserQuestion with:
- Clear description of EXACTLY what command will be executed
- The server/project it affects
- Whether it causes downtime
- Whether it's reversible

## Why This Rule Exists

On 2026-02-23, code patches were applied, services were restarted, and git commits were made on PRODUCTION without the Owner's step-by-step approval. Mode 1 (default) ensures it NEVER happens again. Mode 2 (bypass) provides a controlled fast path when the Owner explicitly opts in.
