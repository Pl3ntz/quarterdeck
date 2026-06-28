#!/usr/bin/env bash
# ci-leak-scan.sh — CI-safe denylist scan for the PUBLIC quarterdeck repo.
#
# Reads text on stdin, scans it against a denylist supplied as a base64 secret
# (QD_DENYLIST_B64), and on a hard match FAILS WITHOUT printing the match —
# public CI logs are public, so echoing a real identifier here would BE the leak.
#
# Fail-closed: if the secret is missing or undecodable, exit 1 (block).
# Exit 0 = clean. Exit 1 = hard match or fail-closed.
set -uo pipefail

if [[ -z "${QD_DENYLIST_B64:-}" ]]; then
  echo "::error::leak-guard: QD_DENYLIST_B64 secret not set (fail-closed)."
  echo "::error::Set it from the local denylist: gh secret set QD_DENYLIST_B64 --repo <owner>/quarterdeck < <(base64 < ~/.claude/local/quarterdeck-denylist.txt)"
  exit 1
fi

deny="$(printf '%s' "$QD_DENYLIST_B64" | base64 -d 2>/dev/null)" || {
  echo "::error::leak-guard: could not decode QD_DENYLIST_B64 (fail-closed)."; exit 1; }

# Collapse non-comment, non-blank patterns into one alternation (mirrors leak-scan.sh).
alt="$(printf '%s\n' "$deny" | grep -vE '^[[:space:]]*(#|$)' | paste -sd '|' -)"
if [[ -z "$alt" ]]; then
  echo "::error::leak-guard: denylist decoded empty (fail-closed)."; exit 1
fi

# Count matching lines WITHOUT revealing them. The matched text never reaches the log.
n="$(grep -inE "$alt" 2>/dev/null | wc -l | tr -d ' ')"

if [[ "${n:-0}" -gt 0 ]]; then
  echo "::error::🔴 leak-guard: ${n} line(s) match the denylist (real identifier/secret in tracked content)."
  echo "::error::Matches are intentionally NOT shown (public log). Inspect them locally:"
  echo "::error::   git ls-files | xargs cat | QD_DENYLIST=~/.claude/local/quarterdeck-denylist.txt bash ~/.claude/scripts/quarterdeck-guard/leak-scan.sh"
  echo "::error::Remove the content (and ROTATE if it was a secret) before re-pushing."
  exit 1
fi
echo "✅ leak-guard: no denylist matches in scanned content."
exit 0
