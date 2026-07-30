#!/bin/bash
# Suite Gate — PreToolUse hook on Bash.
#
# Blocks `git commit` in this repo when hooks/ or scripts/ are staged and the guardrail
# suite does not pass against the files being COMMITTED.
#
# Why against the committed files and not the installed ones: on 2026-07-25 a commit
# claimed to fix a hook that silently failed open, while the file in that commit did not
# carry the fix at all -- the fix existed only in the private config and was never synced.
# The suite passed the whole time, because it was testing the installed copy. Pointing it
# at the repo caught it immediately. A gate that validates something other than the artifact
# being shipped is the same failure it is meant to prevent.
#
# Chosen over the LLM review gate for this repo deliberately. The defects here have been
# behavioural -- a regex boundary that never matched, a tilde that was never expanded, a
# hook registered that the repo does not ship. Executing the hook and comparing the decision
# catches those; reading the diff mostly does not. It also costs 21s and nothing else, where
# a review would cost two model calls on essentially every commit, since 10 of the last 10
# commits here touched code.
#
# Escape hatch: SUITEGATE_OFF=1 git commit ...
#
# I/O Contract (PreToolUse): {} allows; permissionDecision deny blocks. Exit 0 always.

. "$HOME/.claude/hooks/lib/hook-common.sh"

input=$(cat)
command=$(hook_command "$input")
[ -z "$command" ] && hook_allow

echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit\b' || hook_allow
hook_override_requested "$command" "SUITEGATE_OFF" && hook_allow

work_dir=$(hook_work_dir "$command")
root=$(git -C "$work_dir" rev-parse --show-toplevel 2>/dev/null) || hook_allow

suite="$root/scripts/test-guardrails.sh"
[ -f "$suite" ] && [ -d "$root/hooks" ] || hook_allow

git -C "$root" diff --cached --name-only 2>/dev/null | grep -qE '^(hooks|scripts)/' || hook_allow

out=$(HOOKS="$root/hooks" bash "$suite" 2>&1)
if [ $? -eq 0 ]; then
  python3 -c "
import json, sys
print(json.dumps({'systemMessage': 'SUITE GATE ok: ' + sys.argv[1].strip().splitlines()[-1]}))" "$out"
  exit 0
fi

failures=$(printf '%s' "$out" | grep '^  FAIL' | head -3 | tr -s ' ' | tr '\n' ' ')
hook_deny "SUITE GATE: a suite de guardrails falha contra os arquivos DESTE commit. ${failures}. Como proceder: rode HOOKS=<repo>/hooks bash scripts/test-guardrails.sh -v, conserte o que falhar e commite. Override deliberado: SUITEGATE_OFF=1 git commit ..."
