#!/bin/bash
# hook-common.sh — shared helpers for PreToolUse hooks that inspect a Bash command.
#
# Source it: . "$HOME/.claude/hooks/lib/hook-common.sh"
#
# Why this file exists: three hooks independently parsed `cd <path> &&` out of a command
# string, and two of them shipped the same defect — the path arrives as literal text, so
# `cd ~/repo` produced the directory "~/repo", every subsequent `[ -f ... ]` test failed,
# and the hook silently allowed whatever it was meant to gate. A guardrail that fails OPEN
# is worse than no guardrail, because it manufactures confidence.
#
# Both were found on 2026-07-24 (eval-gate, test-gate). Keeping the logic in one place is
# the only reason the third copy will not repeat it.

# hook_command <json-on-stdin-already-captured>
# Extract tool_input.command from a hook payload.
hook_command() {
  printf '%s' "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null
}

# hook_transcript <payload>
hook_transcript() {
  printf '%s' "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null
}

# hook_expand_path <path>
# Expand a leading ~ or $HOME that arrived as literal text. Shell expansion never happened
# because the path came out of a JSON string, not out of the shell.
hook_expand_path() {
  local p="$1"
  case "$p" in
    "~")        printf '%s' "$HOME" ;;
    "~/"*)      printf '%s' "$HOME/${p#\~/}" ;;
    '$HOME')    printf '%s' "$HOME" ;;
    '$HOME/'*)  printf '%s' "$HOME/${p#\$HOME/}" ;;
    *)          printf '%s' "$p" ;;
  esac
}

# hook_work_dir <command>
# Best-effort working directory for a command, honouring a leading `cd <path> &&`.
# Falls back to $PWD. Always returns an expanded, absolute-ish path.
hook_work_dir() {
  local cmd="$1" dir
  dir=$(printf '%s' "$cmd" | grep -oE 'cd[[:space:]]+[^&;]+' | head -1 | sed -E 's/^cd[[:space:]]+//' | xargs)
  [ -z "$dir" ] && dir="$PWD"
  hook_expand_path "$dir"
}

# hook_allow — emit the "allow silently" response and exit.
hook_allow() { echo '{}'; exit 0; }

# hook_deny <reason>
hook_deny() {
  # Every deny is recorded. A guardrail firing is the highest-quality learning signal the
  # system produces -- the exact command, the rule that caught it, and the reason, all with
  # full context at the moment of the mistake -- and until 2026-07-25 none of it was kept.
  # The learning pipeline instead aggregated error-string frequency, which is why 57 rule
  # candidates accumulated and none was ever promoted: a frequency count cannot be turned
  # back into a rule.
  #
  # Best-effort and never fatal: a logging failure must not turn a deny into an allow.
  {
    LOG_DIR="$HOME/.claude/logs"
    mkdir -p "$LOG_DIR" 2>/dev/null
    python3 -c "
import json, os, sys
from datetime import datetime
try:
    entry = {
        'timestamp': datetime.now().isoformat(),
        'hook': os.path.basename(sys.argv[1]),
        'reason': sys.argv[2],
        'command': (sys.argv[3] or '')[:400],
    }
    with open(os.path.join(os.path.expanduser('~/.claude/logs'), 'guardrail-denies.jsonl'), 'a') as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + '\n')
except Exception:
    pass
" "${0:-unknown}" "$1" "${command:-}" 2>/dev/null
  } &

  echo "[Hook] $1" >&2
  python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                                         'permissionDecision': 'deny',
                                         'permissionDecisionReason': sys.argv[1]}}))" "$1"
  exit 0
}

# hook_override_requested <command> <VAR_NAME>
# True when an explicit, deliberate escape hatch is set, either in the environment or
# inline in the command itself (VAR=1 git commit ...). Mirrors LEAKGUARD_OFF.
hook_override_requested() {
  local cmd="$1" var="$2" hit=1
  [ "$(eval "printf '%s' \"\${$var:-}\"")" = "1" ] && hit=0
  [ $hit -ne 0 ] && printf '%s' "$cmd" | grep -q "$var=1" && hit=0
  [ $hit -ne 0 ] && return 1

  # An override is the sharpest learning signal this system produces, and the rarest.
  # A deny on its own is mostly noise -- a guardrail correctly stopping something carries
  # no lesson. An override means the guardrail was wrong, or the situation was genuinely
  # exceptional. Either way it is worth writing down, and neither is recoverable later:
  # by the time anyone reads a log, the context that made the override correct is gone.
  {
    mkdir -p "$HOME/.claude/logs" 2>/dev/null
    python3 -c "
import json, os, sys
from datetime import datetime
try:
    entry = {'timestamp': datetime.now().isoformat(), 'override': sys.argv[1],
             'hook': os.path.basename(sys.argv[2]), 'command': (sys.argv[3] or '')[:400]}
    with open(os.path.join(os.path.expanduser('~/.claude/logs'), 'guardrail-overrides.jsonl'), 'a') as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + '\n')
except Exception:
    pass
" "$var" "${0:-unknown}" "$cmd" 2>/dev/null
  } &
  return 0
}
