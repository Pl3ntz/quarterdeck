#!/bin/bash
# Learning Check — Stop hook.
#
# Surfaces, at the end of a session, any guardrail override that was used without a lesson
# being written down.
#
# Why overrides and not denies: a deny is usually a guardrail working -- there is nothing to
# learn from being correctly stopped. An override is the opposite. It means the rule was
# wrong for this case, or the case was genuinely exceptional, and both are worth recording.
# Overrides are also rare, so this stays quiet instead of becoming background noise that
# gets ignored.
#
# Why it does not block: verify-completion.sh was retired on 2026-07-24 for being a Stop
# hook that refused to let a turn end until a required section appeared. Forcing a memory
# write after every override would manufacture noise memories, which is the failure this is
# meant to avoid -- the existing learning pipeline already produced 57 rule candidates that
# nobody ever promoted. This reports; the decision to write stays a judgement call.
#
# I/O Contract (Stop): echo input back (passthrough), never fail the Stop.

input=$(cat)
echo "$input"

# Synchronous on purpose: a backgrounded check races the parent exiting, and its stderr
# is lost before anything reads it. The work is a glob plus a small file read.
{
  LOGS="$HOME/.claude/logs"
  OVERRIDES="$LOGS/guardrail-overrides.jsonl"
  [ -f "$OVERRIDES" ] || exit 0

    # No 2>/dev/null here: the finding IS written to stderr, and redirecting it silenced
  # the only output this hook produces.
  python3 - "$OVERRIDES" <<'PY'
import json, os, sys, glob
from datetime import datetime, timedelta

path = sys.argv[1]
cutoff = datetime.now() - timedelta(hours=12)

recent = []
try:
    with open(path) as fh:
        for line in fh:
            try:
                e = json.loads(line)
                if datetime.fromisoformat(e["timestamp"]) >= cutoff:
                    recent.append(e)
            except Exception:
                continue
except OSError:
    raise SystemExit

if not recent:
    raise SystemExit

# Did anything get written to memory in the same window? Any project's memory counts:
# the lesson from an override is rarely scoped to the project it happened in.
mem_written = False
for f in glob.glob(os.path.expanduser("~/.claude/projects/*/memory/*.md")):
    try:
        if datetime.fromtimestamp(os.path.getmtime(f)) >= cutoff:
            mem_written = True
            break
    except OSError:
        continue

if mem_written:
    raise SystemExit

by_var = {}
for e in recent:
    by_var[e.get("override", "?")] = by_var.get(e.get("override", "?"), 0) + 1
summary = ", ".join(f"{k} x{v}" for k, v in sorted(by_var.items()))
print(f"[learning-check] {len(recent)} guardrail override(s) in the last 12h ({summary}) "
      f"and nothing written to memory. If one of them revealed a rule that is wrong, or a "
      f"case the rule should have allowed, that is worth a memory entry while the context "
      f"still exists.", file=sys.stderr)
PY
}

exit 0
