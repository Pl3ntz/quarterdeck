#!/usr/bin/env bash
# wt — git worktree helper for running several Claude Code sessions on one repo at once.
#
# Why: two sessions editing the same checkout race on the working tree, and the defence
# has been "assign each agent a file zone and hope". A worktree is a separate checkout
# with its own HEAD and index, sharing one .git, so the conflict stops being something to
# remember and becomes something that cannot happen. This is the Owner-facing half of the
# same idea that `isolation: 'worktree'` gives agents.
#
# Usage:
#   wt new <branch> [repo]    create (or reuse) a worktree for <branch>, print its path
#   wt ls [repo]              list worktrees for the repo
#   wt rm <branch> [repo]     remove the worktree (refuses if it has uncommitted work)
#   wt path <branch> [repo]   print the path only, for `cd "$(wt path foo)"`
#
# <repo> defaults to the current repo. Worktrees live in a sibling directory so editors
# and file watchers do not walk them as part of the main checkout.
#
#   ~/dev/worktrees/<repo>/<branch>/
#
# Suggested shell glue (add by hand, this script does not touch your rc files):
#   wt()  { local o; o=$(~/.claude/scripts/wt.sh "$@") || return; printf '%s\n' "$o"; }
#   wtc() { cd "$(~/.claude/scripts/wt.sh path "$@")" || return; }

set -uo pipefail

WT_HOME="${WT_HOME:-$HOME/dev/worktrees}"

die() { echo "wt: $*" >&2; exit 1; }

repo_root() {
  local start="${1:-$PWD}"
  git -C "$start" rev-parse --show-toplevel 2>/dev/null
}

resolve_repo() {
  # $1 = optional repo name or path
  if [ -n "${1:-}" ]; then
    if [ -d "$1/.git" ] || [ -f "$1/.git" ]; then repo_root "$1"; return; fi
    for base in "$HOME/dev" "$HOME/dev/personal"; do
      if [ -d "$base/$1/.git" ]; then repo_root "$base/$1"; return; fi
    done
    return 1
  fi
  repo_root "$PWD"
}

slug() { printf '%s' "$1" | tr '/' '-' | tr -cd 'A-Za-z0-9._-'; }

cmd_new() {
  local branch="${1:-}" repo_arg="${2:-}"
  [ -n "$branch" ] || die "usage: wt new <branch> [repo]"
  local root; root=$(resolve_repo "$repo_arg") || die "no git repo found for '${repo_arg:-$PWD}'"
  local name; name=$(basename "$root")
  local dest="$WT_HOME/$name/$(slug "$branch")"

  if [ -d "$dest" ]; then
    printf '%s\n' "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  # Reuse the branch if it exists (locally or on a remote); otherwise branch off HEAD.
  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$root" worktree add "$dest" "$branch" >&2 || die "worktree add failed"
  elif git -C "$root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git -C "$root" worktree add --track -b "$branch" "$dest" "origin/$branch" >&2 || die "worktree add failed"
  else
    git -C "$root" worktree add -b "$branch" "$dest" >&2 || die "worktree add failed"
  fi

  printf '%s\n' "$dest"
}

cmd_ls() {
  local root; root=$(resolve_repo "${1:-}") || die "no git repo found"
  git -C "$root" worktree list
}

cmd_path() {
  local branch="${1:-}" repo_arg="${2:-}"
  [ -n "$branch" ] || die "usage: wt path <branch> [repo]"
  local root; root=$(resolve_repo "$repo_arg") || die "no git repo found"
  local dest="$WT_HOME/$(basename "$root")/$(slug "$branch")"
  [ -d "$dest" ] || die "no worktree for '$branch' (create it: wt new $branch)"
  printf '%s\n' "$dest"
}

cmd_rm() {
  local branch="${1:-}" repo_arg="${2:-}"
  [ -n "$branch" ] || die "usage: wt rm <branch> [repo]"
  local root; root=$(resolve_repo "$repo_arg") || die "no git repo found"
  local dest="$WT_HOME/$(basename "$root")/$(slug "$branch")"
  [ -d "$dest" ] || die "no worktree at $dest"

  # Never discard work silently -- that is the one way a worktree can bite you.
  if [ -n "$(git -C "$dest" status --porcelain 2>/dev/null)" ]; then
    die "$dest has uncommitted changes; commit, stash, or remove it by hand"
  fi
  git -C "$root" worktree remove "$dest" >&2 || die "worktree remove failed"
  echo "removed $dest" >&2
}

case "${1:-}" in
  new)  shift; cmd_new "$@" ;;
  ls)   shift; cmd_ls "$@" ;;
  rm)   shift; cmd_rm "$@" ;;
  path) shift; cmd_path "$@" ;;
  ""|-h|--help)
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command '$1' (try: new, ls, rm, path)" ;;
esac
