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

# A public repository is allowed to name ITSELF. Blocking a project name inside that project's own repo would
# make it uncommittable, and the risk this guard exists for is cross-contamination: one
# project's identifiers appearing in a DIFFERENT public repo. QD_SELF is a regex alternation
# of the terms this particular repo may use, written by the installer into .git/leakguard-self
# and exported by the hook. It exempts nothing else.
SELF_FILE="${QD_SELF_FILE:-}"
if [[ -z "$SELF_FILE" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
  SELF_FILE="$(git rev-parse --git-dir 2>/dev/null)/leakguard-self"
fi
QD_SELF=""
[[ -n "$SELF_FILE" && -r "$SELF_FILE" ]] && QD_SELF="$(grep -vE '^[[:space:]]*(#|$)' "$SELF_FILE" 2>/dev/null | paste -sd '|' -)"

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
  # Drop lines whose ONLY denylist match is this repo's own name. A line that also carries a
  # different project's identifier still blocks -- the exemption is per line and per term, not
  # a blanket pass for the file.
  # python3, not sed: BSD sed on macOS does not support \b, so the word-boundary patterns in
  # the lists silently never matched here and the exemption removed nothing. Caught by testing
  # it, not by reading it.
  if [[ -n "$hits" && -n "$QD_SELF" ]]; then
    hits="$(printf '%s\n' "$hits" | QD_SELF="$QD_SELF" DENY_ALT="$deny_alt" python3 -c '
import os, re, sys
self_re = re.compile(os.environ["QD_SELF"], re.I)
deny_re = re.compile(os.environ["DENY_ALT"], re.I)
for line in sys.stdin.read().splitlines():
    if deny_re.search(self_re.sub("", line)):
        print(line)
' 2>/dev/null)"
  fi
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
