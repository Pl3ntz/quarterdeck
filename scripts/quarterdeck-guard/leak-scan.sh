#!/usr/bin/env bash
# leak-scan.sh — scan stdin text against the quarterdeck leak denylist.
#
# Exit 0 = clean. Exit 1 = HARD-tier match (caller should block).
# Reads added-diff text on stdin. Prints offending matches to stderr.
# WARN-tier matches are printed but do NOT change the exit code.
#
# FAIL-CLOSED: if the hard denylist is missing/unreadable, exit 1 (block).
set -uo pipefail

DENY="${QD_DENYLIST:-$HOME/.claude/local/quarterdeck-denylist.txt}"
WARN="${QD_WARNLIST:-$HOME/.claude/local/quarterdeck-denylist-warn.txt}"

if [[ ! -r "$DENY" ]]; then
  echo "‼️  quarterdeck-guard: hard denylist not found/readable at:" >&2
  echo "    $DENY" >&2
  echo "    BLOCKING (fail-closed). Run install-quarterdeck-guard.sh or restore the file." >&2
  exit 1
fi

input="$(cat)"
[[ -z "$input" ]] && exit 0

# Collapse non-comment, non-blank patterns into one alternation.
build_alt() { grep -vE '^[[:space:]]*(#|$)' "$1" 2>/dev/null | paste -sd '|' -; }

rc=0

deny_alt="$(build_alt "$DENY")"
if [[ -n "$deny_alt" ]]; then
  hits="$(printf '%s\n' "$input" | grep -inE "$deny_alt" 2>/dev/null)"
  if [[ -n "$hits" ]]; then
    echo "🔴 quarterdeck-guard: BLOCKED — real identifier(s) in staged/pushed content:" >&2
    printf '%s\n' "$hits" | sed 's/^/      /' >&2
    rc=1
  fi
fi

if [[ -r "$WARN" ]]; then
  warn_alt="$(build_alt "$WARN")"
  if [[ -n "$warn_alt" ]]; then
    whits="$(printf '%s\n' "$input" | grep -inE "$warn_alt" 2>/dev/null)"
    if [[ -n "$whits" ]]; then
      echo "🟡 quarterdeck-guard: WARN — ambiguous codename(s) (review, NOT blocked):" >&2
      printf '%s\n' "$whits" | sed 's/^/      /' >&2
    fi
  fi
fi

exit $rc
