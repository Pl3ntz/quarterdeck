#!/usr/bin/env bash
# scan-range.sh <base> <sha> — scan the content INTRODUCED by a commit range for a
# push: each changed file's blob at <sha> + every commit message in base..sha.
# Reads real blob bytes (binary/gitattributes-proof). Exit 1 if any BLOCK.
set -uo pipefail

base="${1:-}"; sha="${2:-}"
[[ -z "$base" || -z "$sha" ]] && { echo "usage: scan-range.sh <base> <sha>" >&2; exit 2; }

GUARD="$HOME/.claude/scripts/leak-guard"
SCAN="$GUARD/scan-content.sh"
# Allow-listed private repo (real identifiers legitimately live there) → skip.
bash "$GUARD/repo-skip.sh" && exit 0
[[ -x "$SCAN" ]] || { echo "leak-guard: scanner missing ($SCAN) — BLOCKING (fail-closed)" >&2; exit 1; }

rc=0
while IFS= read -r -d '' f; do
  [[ -z "$f" ]] && continue
  blob="$(git show "$sha:$f" 2>/dev/null || true)"
  s=0
  { printf 'PATH: %s\n' "$f"; printf '%s\n' "$blob"; } | "$SCAN" "$f" || s=$?
  # Keep the two severities apart on the way up: 1 (hard) must never be masked by a later 2.
  if [ "$s" -eq 1 ]; then rc=1; elif [ "$s" -eq 2 ] && [ "$rc" -ne 1 ]; then rc=2; fi
done < <(git diff --name-only --diff-filter=ACMR -z "$base..$sha" 2>/dev/null)

# Commit messages in the range (secrets pasted into a message leak on push too).
msgs="$(git log --format='%B' "$base..$sha" 2>/dev/null || true)"
if [[ -n "$msgs" ]]; then
  s=0
  printf '%s\n' "$msgs" | "$SCAN" "commit-message" || s=$?
  if [ "$s" -eq 1 ]; then rc=1; elif [ "$s" -eq 2 ] && [ "$rc" -ne 1 ]; then rc=2; fi
fi

exit $rc
