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
PORTF="${QD_PORTFOLIOLIST:-$HOME/.claude/local/quarterdeck-denylist-portfolio.txt}"

# A public repository is allowed to name ITSELF. Blocking a project name inside that project's own repo would
# make it uncommittable, and the risk this guard exists for is cross-contamination: one
# project's identifiers appearing in a DIFFERENT public repo. QD_SELF is a regex alternation
# of the terms this particular repo may use, written by the installer into .git/leakguard-self
# and exported by the hook. It exempts nothing else.
# --git-common-dir, not --git-dir: inside a linked worktree --git-dir points at
# <main>/.git/worktrees/<name>, which holds neither of these files, so a worktree silently lost
# both its self-exemption and its mode.
qd_common_dir() { git rev-parse --path-format=absolute --git-common-dir 2>/dev/null; }
SELF_FILE="${QD_SELF_FILE:-}"
if [[ -z "$SELF_FILE" ]]; then
  _gd="$(qd_common_dir)"
  [[ -n "$_gd" ]] && SELF_FILE="$_gd/leakguard-self"
fi
QD_SELF=""
[[ -n "$SELF_FILE" && -r "$SELF_FILE" ]] && QD_SELF="$(grep -vE '^[[:space:]]*(#|$)' "$SELF_FILE" 2>/dev/null | paste -sd '|' -)"

# Two kinds of repo, two answers to "is naming the Owner a leak?".
#
#   project — a repo ABOUT something he built. It has to carry its own GPL copyright, its own
#             AUTHORS file, its own site domain and the contact address the extension stores
#             require. Blocking those froze six public repos over data the remotes were
#             already serving. Hard denylist only.
#   meta    — a public mirror of his config, dotfiles or tooling. Nothing there needs to say
#             who he is, and that was the original reason this guard exists. Hard denylist
#             PLUS the identity tier.
#
# Written to .git/leakguard-mode by install-public-repo-guard.sh. ABSENT = meta, so a repo
# nobody classified gets the stricter tier rather than the looser one. QD_MODE overrides, for
# tests.
if [[ -z "${QD_MODE:-}" ]]; then
  MODE_FILE="${QD_MODE_FILE:-}"
  if [[ -z "$MODE_FILE" ]]; then
    _gd="$(qd_common_dir)"
    [[ -n "$_gd" ]] && MODE_FILE="$_gd/leakguard-mode"
  fi
  QD_MODE="meta"
  [[ -n "$MODE_FILE" && -r "$MODE_FILE" ]] && \
    QD_MODE="$(grep -vE '^[[:space:]]*(#|$)' "$MODE_FILE" 2>/dev/null | head -1 | tr -d '[:space:]')"
fi
[[ "$QD_MODE" == "project" ]] || QD_MODE="meta"

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
if [[ -z "$deny_alt" ]]; then
  echo "‼️  quarterdeck-guard: a denylist existe mas nao tem nenhum padrao:" >&2
  echo "    $DENY" >&2
  echo "    Uma lista vazia desarmaria o guard inteiro em silencio, entao isto BLOQUEIA" >&2
  echo "    (fail-closed), igual ao arquivo ausente." >&2
  echo "    Como proceder: restaure a lista, ou aponte QD_DENYLIST para a correta." >&2
  exit 1
fi

# In meta mode the identity tier is appended to the SAME alternation, so it goes through the
# same self-exemption pass and reports under the same BLOCKED heading. Fail-closed: a meta repo
# whose identity list is unreadable blocks, exactly as it does for the hard list.
if [[ "$QD_MODE" == "meta" ]]; then
  if [[ ! -r "$PORTF" ]]; then
    echo "‼️  quarterdeck-guard: identity list not found/readable at:" >&2
    echo "    $PORTF" >&2
    echo "    This repo is in META mode, which requires it. BLOCKING (fail-closed)." >&2
    echo "    Restore the file, or mark the repo as a project:" >&2
    echo "      echo project > \"\$(git rev-parse --git-dir)/leakguard-mode\"" >&2
    exit 1
  fi
  portf_alt="$(build_alt "$PORTF")"
  [[ -n "$portf_alt" ]] && deny_alt="${deny_alt:+$deny_alt|}$portf_alt"
fi

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
