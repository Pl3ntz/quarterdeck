#!/usr/bin/env bash
# host-build-policy.sh — decide, per repository, whether builds may run on this host.
#
# block-build.sh enforces "no heavy build on the Mac", a rule born from a containerised
# multi-service stack that nearly took the machine down. The command pattern it matches cannot
# distinguish that from a two-second bundle of a browser extension, so it blocked both, and
# ordinary work in every small project stopped. This script records the exception per repo.
#
# The marker is .git/allow-host-build, deliberately NOT in the working tree: several of these
# repos are public, and which machine builds what is not something they should publish.
#
# Containerised repos are the ones the rule was written for, so --scan flags them and --allow-all
# skips them. Detection is by evidence in the repo (a compose file), never a hardcoded list of
# project names -- this script is mirrored publicly.
#
# Usage:
#   host-build-policy.sh --scan                 status per repo
#   host-build-policy.sh --allow <path> [...]   builds allowed on the host for these repos
#   host-build-policy.sh --block <path> [...]   back to the default (blocked)
#   host-build-policy.sh --allow-all            allow every repo WITHOUT a compose file

set -uo pipefail
SEARCH_DIRS=("$HOME/dev" "$HOME/dev/personal")

gitdir() { git -C "$1" rev-parse --absolute-git-dir 2>/dev/null; }

containerised() {
  # Advisory only. Searches a few levels because the repo this rule was written for keeps its
  # compose under infra/, and a root-only check reported it as NOT containerised -- the one
  # answer that had to be right.
  local r="$1"
  find "$r" -maxdepth 3 \( -name node_modules -o -name .git \) -prune -o \
       -type f \( -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' \) -print 2>/dev/null \
    | head -1 | grep -q .
}

# Repos that keep the block regardless. A compose file is a weak proxy for "heavy" -- plenty of
# small frontends have one -- so the real list is explicit and lives OUTSIDE any repo, in
# ~/.claude/local/, exactly like the production-gate host aliases. One repo name per line.
BLOCKCONF="${HOST_BUILD_BLOCKCONF:-$HOME/.claude/local/host-build-block.conf}"
kept_blocked() {
  [ -r "$BLOCKCONF" ] || return 1
  grep -vE '^[[:space:]]*(#|$)' "$BLOCKCONF" | tr -d ' \t' | grep -qxF "$1"
}

status() {
  local g; g="$(gitdir "$1")"
  [ -n "$g" ] && [ -f "$g/allow-host-build" ] && { echo allowed; return; }
  echo blocked
}

allow_one() {
  local r="${1%/}" g; g="$(gitdir "$r")"
  [ -n "$g" ] || { printf '  SKIP     %-26s (not a git repo)\n' "$(basename "$r")"; return; }
  {
    echo "# Builds may run on this host for this repo. Read by block-build.sh."
    echo "# Written by host-build-policy.sh. Delete this file to restore the block."
  } > "$g/allow-host-build"
  printf '  ALLOW    %-26s %s\n' "$(basename "$r")" "$(containerised "$r" && echo '(has a compose file -- builds probably belong in the container)')"
}

block_one() {
  local r="${1%/}" g; g="$(gitdir "$r")"
  [ -n "$g" ] || { printf '  SKIP     %-26s (not a git repo)\n' "$(basename "$r")"; return; }
  rm -f "$g/allow-host-build"
  printf '  BLOCK    %-26s\n' "$(basename "$r")"
}

case "${1:-}" in
  --scan)
    printf '%-28s %-10s %s\n' "REPO" "HOST BUILD" "CONTAINERISED"
    for d in "${SEARCH_DIRS[@]}"; do
      for r in "$d"/*/; do
        [ -e "$r/.git" ] || continue
        printf '%-28s %-10s %s\n' "$(basename "${r%/}")" "$(status "${r%/}")" \
          "$(containerised "${r%/}" && echo yes || echo no)"
      done
    done | sort -u
    ;;
  --allow-all)
    for d in "${SEARCH_DIRS[@]}"; do
      for r in "$d"/*/; do
        [ -e "$r/.git" ] || continue
        if kept_blocked "$(basename "${r%/}")"; then
          printf '  KEEP     %-26s (listed in %s)\n' "$(basename "${r%/}")" "$(basename "$BLOCKCONF")"
        else
          allow_one "${r%/}"
        fi
      done
    done
    ;;
  --allow) shift; [ $# -gt 0 ] || { echo "usage: --allow <path> [...]" >&2; exit 2; }
           for r in "$@"; do allow_one "$r"; done ;;
  --block) shift; [ $# -gt 0 ] || { echo "usage: --block <path> [...]" >&2; exit 2; }
           for r in "$@"; do block_one "$r"; done ;;
  *) echo "usage: $(basename "$0") --scan | --allow-all | --allow <path>... | --block <path>..." >&2
     exit 2 ;;
esac
