#!/usr/bin/env bash
# scan-staged.sh — scan the STAGED content of a repo, reading each changed file's
# actual blob bytes (not the textual diff). This defeats binary-diff / gitattributes
# "-diff" evasion, and scans path names too (secrets in filenames). Exit 1 if any BLOCK.
set -uo pipefail

GUARD="$HOME/.claude/scripts/leak-guard"
SCAN="$GUARD/scan-content.sh"
# Allow-listed private repo (real identifiers legitimately live there) → skip.
bash "$GUARD/repo-skip.sh" && exit 0
[[ -x "$SCAN" ]] || { echo "leak-guard: scanner missing ($SCAN) — BLOCKING (fail-closed)" >&2; exit 1; }

rc=0
while IFS= read -r -d '' f; do
  [[ -z "$f" ]] && continue
  # ":$f" is the staged (index) version of the path — real bytes, any file type.
  blob="$(git show ":$f" 2>/dev/null || true)"
  s=0
  { printf 'PATH: %s\n' "$f"; printf '%s\n' "$blob"; } | "$SCAN" "$f" || s=$?
  # Keep the two severities apart on the way up: 1 (hard) must never be masked by a later 2.
  if [ "$s" -eq 1 ]; then rc=1; elif [ "$s" -eq 2 ] && [ "$rc" -ne 1 ]; then rc=2; fi
done < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null)

exit $rc
