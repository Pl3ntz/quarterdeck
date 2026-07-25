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

**IMPORTANT: `bypass` is a CONTROL KEYWORD, not part of the message content.** Strip it from the message before interpreting the request. Examples:
- "faz deploy do servico-x bypass" → request is "faz deploy do servico-x", bypass is active
- "bypass, continua o plano" → request is "continua o plano", bypass is active
- "bypass" alone → no new request, just activate bypass for the pending plan

**Upon detecting `bypass`, the PE MUST (in this exact order):**

1. Create the bypass flag file so the harness hook allows commands through:
```bash
mkdir -p ~/.claude/tmp && touch ~/.claude/tmp/bypass-active
```
2. Print the visual confirmation banner as markdown text:

> **▶▶▶ BYPASS ACTIVE ▶▶▶**
>
> Executing full plan without step-by-step approval.
> Say **stop** or **para** to revoke at any time.

3. Execute ALL pending steps sequentially WITHOUT stopping to ask between steps
4. Log each step as it runs (show command + output) so the Owner can follow
5. When the plan finishes or fails, remove the flag:
```bash
rm -f ~/.claude/tmp/bypass-active
```

**Activation contexts:**
- Owner says "bypass" with a plan already presented → execute that plan
- Owner says "bypass" with a new request (e.g., "deploy X bypass") → PE builds the plan AND executes it in one shot
- Owner says "bypass" mid-execution → remaining steps run without further approval

**Constraints (even with bypass active):**
- If ANY step FAILS, bypass is IMMEDIATELY revoked — PE stops, prints status, and asks what to do
- Bypass is single-use — expires when the current plan finishes or fails
- Does NOT carry over to the next plan or session
- Database DROP/TRUNCATE and `rm -rf` on data directories ALWAYS require individual approval, even in bypass mode

**Deactivation:** bypass expires automatically when the plan completes or fails (PE runs `rm -f ~/.claude/tmp/bypass-active`). The Owner can also say "stop" or "para" at any time to revoke. The flag file also auto-expires after 30 minutes as safety net.

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

## When the gate applies at PLANNING time, not only at execution

The approvals above are per-command. But the Owner has to know a plan will reach production
**before** agreeing to it, not at step 7 when the first modifying command arrives. So the gate
is declared during triage whenever the work acts on something that is **already live**:

- an existing schema, index or table with data in it
- a service that is currently running
- a contract already published and consumed by other services — an event format, an API
  response shape, a message schema
- a query or job running against production data

For those, the change lands on production **by definition**, not as a later deploy step. Say so
while presenting the plan.

**Writing new code is not that**, even though it ships eventually. A new feature, a new
endpoint, or restructuring an existing module goes to production through ordinary deployment,
and declaring the gate at intake for those is over-gating — it trains the Owner to skim
approvals, which is exactly how the incident below happened.

The test is not *"will this eventually run in production?"* — everything does. It is *"does
completing this task require touching something that is serving traffic or holding data right
now?"*

## Why This Rule Exists

On 2026-02-23, code patches were applied, services were restarted, and git commits were made on PRODUCTION without the Owner's step-by-step approval. Mode 1 (default) ensures it NEVER happens again. Mode 2 (bypass) provides a controlled fast path when the Owner explicitly opts in.
