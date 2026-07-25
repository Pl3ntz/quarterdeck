#!/bin/bash
# Eval Gate — PreToolUse Hook on Bash
#
# BLOCKS `git commit` when a staged agents/*.md has an eval fixture whose stability
# report is missing or older than the agent file itself. In other words: you changed
# the agent's prompt, so the last measurement no longer describes what you are
# committing.
#
# Why this can block now (it used to only warn): the old gate looked for the eval
# COMMAND in the session transcript, which proved the command was typed, not that it
# ran against this version of the agent, and not what it scored. This version reads
# the artifact the runner already writes -- tests/<agent>/stability-report.md -- and
# compares its `Generated` timestamp against the agent file's mtime. That check is
# deterministic and instant, so the original objection (K LLM calls are slow and
# expensive, they must not run inline on commit) no longer applies: the harness still
# runs manually, the gate only verifies that it did, on this version.
#
# What it deliberately does NOT do: judge the score. Thresholds are per-agent
# (fact-checker sits at 71% BY DESIGN, since the headless harness has no web access),
# so the score is reported and left to the Owner. Staleness is objective; "good
# enough" is not.
#
# Escape hatch: EVALGATE_OFF=1 git commit ...
#
# Outside contributors are unaffected: fixtures are local-only, so `tests/<agent>/`
# does not exist in a fresh clone and every agent falls through as ungated.
#
# I/O Contract (PreToolUse):
# - Input: JSON via stdin (tool_input.command)
# - Output: JSON on stdout. {} = allow silently; hookSpecificOutput.permissionDecision
#   "deny" = block with a reason.
# - Exit 0 always.

input=$(cat)

command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[ -z "$command" ] && { echo '{}'; exit 0; }

# Only gate git commit (supports `cd <dir> && ... && git commit`)
if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit\b'; then
  echo '{}'
  exit 0
fi

# Explicit, deliberate override -- mirrors the leak-guard's LEAKGUARD_OFF.
if [ "${EVALGATE_OFF:-}" = "1" ] || echo "$command" | grep -q 'EVALGATE_OFF=1'; then
  echo '{}'
  exit 0
fi

# Working dir from `cd <path> &&`, else PWD.
# The tilde and $HOME must be expanded by hand: the path arrives as a literal string, so
# `cd ~/dev/repo` would otherwise produce the directory "~/dev/repo", every subsequent -f
# test would fail, and the gate would silently allow the commit. That is how this hook
# passed on nearly every real invocation before 2026-07-24.
work_dir=$(echo "$command" | grep -oE 'cd[[:space:]]+[^&;]+' | head -1 | sed -E 's/^cd[[:space:]]+//' | xargs)
[ -z "$work_dir" ] && work_dir="$PWD"
case "$work_dir" in
  "~") work_dir="$HOME" ;;
  "~/"*) work_dir="$HOME/${work_dir#\~/}" ;;
  '$HOME') work_dir="$HOME" ;;
  '$HOME/'*) work_dir="$HOME/${work_dir#\$HOME/}" ;;
esac

# Only act on a Quarterdeck-shaped repo (has the eval harness + agents dir).
# Any other repo commits normally -- this hook is installed globally.
[ -f "$work_dir/scripts/eval/stability_runner.py" ] && [ -d "$work_dir/agents" ] || { echo '{}'; exit 0; }

# Staged agent definitions in this commit
changed=$(git -C "$work_dir" diff --cached --name-only 2>/dev/null | grep -E '^agents/[^/]+\.md$')
[ -z "$changed" ] && { echo '{}'; exit 0; }

verdict=$(WORK_DIR="$work_dir" CHANGED="$changed" python3 <<'PY'
import os, re, sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["WORK_DIR"])
stale, missing, fresh = [], [], []

for rel in os.environ["CHANGED"].splitlines():
    rel = rel.strip()
    if not rel:
        continue
    name = Path(rel).stem
    fixture_dir = root / "tests" / name
    # Ungated unless this agent actually ships a fixture.
    if not (fixture_dir / "expected-findings.md").exists() and not (root / "evals" / name).exists():
        continue

    report = fixture_dir / "stability-report.md"
    if not report.exists():
        missing.append(name)
        continue

    try:
        text = report.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        missing.append(name)
        continue

    m = re.search(r"\*\*Generated:\*\*\s*(\S+)", text)
    if not m:
        missing.append(name)
        continue
    try:
        generated = datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        missing.append(name)
        continue

    agent_mtime = datetime.fromtimestamp((root / rel).stat().st_mtime, tz=timezone.utc)
    score = re.search(r"\*\*Stability score\*\*[^*]*\*\*([\d]+%)\*\*", text)
    score = score.group(1) if score else "?"

    if generated < agent_mtime:
        stale.append(f"{name} (report {generated:%Y-%m-%d %H:%M}Z, agent edited {agent_mtime:%Y-%m-%d %H:%M}Z, last score {score})")
    else:
        fresh.append(f"{name} {score}")

parts = []
if missing:
    parts.append("never evaluated: " + ", ".join(missing))
if stale:
    parts.append("stale: " + "; ".join(stale))
if parts:
    detail = " | ".join(parts)
    names = " ".join(missing + [s.split(" ")[0] for s in stale])
    print("BLOCK\t" + detail + "\t" + names)
elif fresh:
    print("OK\t" + ", ".join(fresh))
PY
)

case "$verdict" in
  BLOCK*)
    detail=$(printf '%s' "$verdict" | cut -f2)
    names=$(printf '%s' "$verdict" | cut -f3)
    msg="EVAL GATE: ${detail}. Rode: python scripts/eval/stability_runner.py --agent <name> --runs 5 (para: ${names}). Override deliberado: EVALGATE_OFF=1 git commit ..."
    echo "[Hook] $msg" >&2
    python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                                         'permissionDecision': 'deny',
                                         'permissionDecisionReason': sys.argv[1]}}))" "$msg"
    exit 0
    ;;
  OK*)
    scores=$(printf '%s' "$verdict" | cut -f2)
    python3 -c "
import json, sys
print(json.dumps({'systemMessage': 'EVAL GATE ok: ' + sys.argv[1]}))" "$scores"
    exit 0
    ;;
esac

echo '{}'
exit 0
