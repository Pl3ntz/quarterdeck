#!/bin/bash
# Review Gate — PreToolUse hook on Bash.
#
# Blocks `git commit` in an opted-in repo when the staged code has not been reviewed, or
# when the review found something CRITICAL that is still there.
#
# The point is to make review something that happened rather than something you remembered
# to do. Without it, the reviewers exist and nothing runs them -- which was true of every
# quality mechanism audited on 2026-07-25, and is the difference between owning a control
# and owning a claim.
#
# Deterministic and instant: it never reviews anything. scripts/review-staged.sh does that,
# when you choose, and records the result under the hash of the exact diff. This hook only
# checks that a record exists for the diff being committed. A hash mismatch means the code
# changed after the review, so the review no longer describes what is being committed.
#
# What it blocks on:
#   - staged code files with no review for this diff
#   - a review containing [CRITICAL]
#
# What it does NOT block on: HIGH, MEDIUM, LOW. Those are reported and left to the Owner.
# Blocking on everything trains you to reach for the override, which costs you the CRITICAL
# gate too.
#
# Opt-in per repo: create `.claude/review-gate` in the repo root. Nothing changes in repos
# without it, because turning this on across every repo at once would make the override the
# default habit.
#
# Escape hatch: REVIEWGATE_OFF=1 git commit ...
#
# I/O Contract (PreToolUse): {} allows; permissionDecision deny blocks. Exit 0 always.

. "$HOME/.claude/hooks/lib/hook-common.sh"

REVIEW_HOME="${REVIEW_HOME:-$HOME/.claude/reviews}"
CODE_RE='\.(py|ts|tsx|js|jsx|go|rs|rb|java|kt|swift|c|h|cpp|cs|php|sh|bash|sql|tf|ex|exs)$'

input=$(cat)
command=$(hook_command "$input")
[ -z "$command" ] && hook_allow

echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit\b' || hook_allow
hook_override_requested "$command" "REVIEWGATE_OFF" && hook_allow

work_dir=$(hook_work_dir "$command")
root=$(git -C "$work_dir" rev-parse --show-toplevel 2>/dev/null) || hook_allow

# Opt-in marker. Absent = this repo is not gated.
[ -f "$root/.claude/review-gate" ] || hook_allow

staged=$(git -C "$root" diff --cached --name-only 2>/dev/null | grep -E "$CODE_RE")
[ -z "$staged" ] && hook_allow

diff_text=$(git -C "$root" diff --cached -- $(echo "$staged" | tr '\n' ' ') 2>/dev/null)
hash=$(printf '%s' "$diff_text" | shasum -a 256 | cut -c1-16)
report="$REVIEW_HOME/$(basename "$root")/$hash.md"

count=$(echo "$staged" | wc -l | tr -d ' ')

if [ ! -f "$report" ]; then
  hook_deny "REVIEW GATE: ${count} arquivo(s) de codigo staged sem review para este diff (${hash}). Como proceder: rode bash ~/.claude/scripts/review-staged.sh e commite em seguida. Override deliberado: REVIEWGATE_OFF=1 git commit ..."
fi

if grep -q '\[CRITICAL\]' "$report" 2>/dev/null; then
  finding=$(grep -m1 -o '\*\*\[CRITICAL\]\*\*[^\n]*' "$report" | cut -c1-160)
  hook_deny "REVIEW GATE: achado CRITICAL neste diff. ${finding}. Como proceder: corrija o achado e rode o review de novo, ou: REVIEWGATE_OFF=1 git commit ... (relatorio: ${report})"
fi

summary=$(grep -oE '\[(HIGH|MEDIUM|LOW)\]' "$report" 2>/dev/null | sort | uniq -c | tr -s ' ' | tr '\n' ' ')
python3 -c "
import json, sys
msg = 'REVIEW GATE ok: diff ' + sys.argv[1] + ' revisado' + (' — ' + sys.argv[2].strip() if sys.argv[2].strip() else ', sem achados')
print(json.dumps({'systemMessage': msg}))" "$hash" "$summary"
exit 0
