#!/usr/bin/env bash
# install-public-repo-guard.sh — put the leak guard on every PUBLIC repository.
#
# Why this exists: on 2026-07-26 four private project names were pushed to a public repo. The
# guard was installed on exactly one repository, and the terms were in the WARN list rather
# than the blocking one, so nothing stopped it. Both are fixed; this closes the third gap,
# which is that every other public repo had no guard at all.
#
# PUBLIC ONLY, and deliberately so. A private repo about a project must be able to name that
# project. Installing this globally would make several repos uncommittable.
#
# Self-exemption: each repo may name ITSELF. The installer writes .git/leakguard-self with the
# repo's own terms and leak-scan.sh drops matches that are only that. A line carrying a
# DIFFERENT project's identifier still blocks -- cross-contamination is the risk being closed.
#
# Tier: the installer also writes .git/leakguard-mode (project | meta). See META_REPOS below.
# Per-repo exemptions are NOT the fix for a whole class of false positive -- if a term is being
# exempted repo after repo, it is classified wrong. Move it, do not paper over it.
#
# Usage:
#   install-public-repo-guard.sh --scan          list public repos and their guard status
#   install-public-repo-guard.sh --all           install on every public repo found
#   install-public-repo-guard.sh <path> [...]    install on specific repos
#
# Requires: gh (to read visibility). A repo whose visibility cannot be determined is SKIPPED,
# never assumed public and never assumed private.

set -uo pipefail

LEAKGUARD_HOOKS="$HOME/.claude/scripts/leak-guard/hooks"
SEARCH_DIRS=("$HOME/dev" "$HOME/dev/personal")

# META repos are public mirrors of the operator's own config, dotfiles or tooling. They get the
# identity tier on top of the hard denylist, because nothing in a config mirror needs to say who
# he is -- that was the instruction this guard was built for. Everything else is a "project"
# repo: it exists to publish something he made, so it must be able to carry its own GPL
# copyright, AUTHORS file, site domain and store contact address. Getting this backwards froze
# six public repos over data their own remotes were already serving.
#
# Match is on the repo's directory/slug name, case-insensitive, exact.
META_REPOS=(quarterdeck claude-dotfiles claude-code-config)

visibility() {
  local repo="$1" url slug
  url="$(git -C "$repo" remote get-url origin 2>/dev/null)" || { echo "NO_REMOTE"; return; }
  case "$url" in *github.com*) ;; *) echo "NOT_GITHUB"; return ;; esac
  slug="$(printf '%s' "$url" | sed -E 's|.*github.com[:/]||; s|\.git$||')"
  gh repo view "$slug" --json visibility --jq .visibility 2>/dev/null || echo "UNKNOWN"
}

installed() {
  [ -e "$1/.git/hooks/pre-commit" ] && grep -q "leak-guard" "$1/.git/hooks/pre-commit" 2>/dev/null
}

write_self() {
  # The repo's own name, plus the GitHub slug's repo part. Nothing else is ever exempted.
  local repo="$1" name slug
  name="$(basename "$repo")"
  slug="$(git -C "$repo" remote get-url origin 2>/dev/null | sed -E 's|.*/||; s|\.git$||')"
  {
    echo "# Terms this repository is allowed to name. Written by install-public-repo-guard.sh."
    echo "# Anything NOT listed here still blocks, including other projects of yours."
    printf '\\b%s\\b\n' "$name"
    [ -n "$slug" ] && [ "$slug" != "$name" ] && printf '\\b%s\\b\n' "$slug"
  } > "$repo/.git/leakguard-self"
}

repo_mode() {
  local name lower m
  name="$(basename "$1")"
  lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  for m in "${META_REPOS[@]}"; do
    [ "$lower" = "$(printf '%s' "$m" | tr '[:upper:]' '[:lower:]')" ] && { echo meta; return; }
  done
  echo project
}

write_mode() {
  local repo="$1" mode="$2"
  {
    echo "# leak-guard tier for this repo. Written by install-public-repo-guard.sh."
    echo "#   project = hard denylist only (repo may name its own author, domain, contact)"
    echo "#   meta    = hard denylist + identity tier (config/dotfiles mirror)"
    echo "# Absent file is read as \"meta\" -- the stricter tier, on purpose."
    echo "$mode"
  } > "$repo/.git/leakguard-mode"
}

install_one() {
  local repo="$1" vis
  vis="$(visibility "$repo")"
  if [ "$vis" != "PUBLIC" ]; then
    printf '  SKIP     %-24s (%s)\n' "$(basename "$repo")" "$vis"
    return
  fi
  if [ ! -d "$LEAKGUARD_HOOKS" ]; then
    echo "  ERROR    leak-guard hooks not found at $LEAKGUARD_HOOKS" >&2
    return 1
  fi
  local h
  for h in pre-commit pre-push commit-msg; do
    [ -f "$LEAKGUARD_HOOKS/$h" ] || continue
    if [ -e "$repo/.git/hooks/$h" ] && [ ! -L "$repo/.git/hooks/$h" ]; then
      mv "$repo/.git/hooks/$h" "$repo/.git/hooks/$h.leakguard-orig"
    fi
    ln -sf "$LEAKGUARD_HOOKS/$h" "$repo/.git/hooks/$h"
  done
  write_self "$repo"
  local mode
  mode="$(repo_mode "$repo")"
  write_mode "$repo" "$mode"
  printf '  OK       %-24s guard installed, mode=%s, self-exempt: %s\n' \
    "$(basename "$repo")" "$mode" "$(basename "$repo")"
}

scan() {
  printf '%-26s %-10s %-10s %s\n' "REPO" "VISIBILITY" "GUARD" "MODE"
  local r vis mode
  for d in "${SEARCH_DIRS[@]}"; do
   for r in "$d"/*/; do
    [ -d "$r/.git" ] || continue
    vis="$(visibility "$r")"
    [ "$vis" = "PUBLIC" ] || continue
    # Report the mode the SCANNER will read, not the one the installer would pick, so a stale
    # or missing file is visible here instead of surfacing as a mystery block later.
    if [ -r "$r/.git/leakguard-mode" ]; then
      mode="$(grep -vE '^[[:space:]]*(#|$)' "$r/.git/leakguard-mode" | head -1 | tr -d '[:space:]')"
      [ "$mode" = "project" ] || mode="meta"
    else
      mode="meta (no file)"
    fi
    printf '%-26s %-10s %-10s %s\n' "$(basename "$r")" "$vis" \
      "$(installed "$r" && echo "installed" || echo "MISSING")" "$mode"
   done
  done
}

case "${1:-}" in
  --scan) scan ;;
  --all)
    for d in "${SEARCH_DIRS[@]}"; do
      for r in "$d"/*/; do
        [ -d "$r/.git" ] || continue
        install_one "${r%/}"
      done
    done
    ;;
  "")
    echo "usage: $(basename "$0") --scan | --all | <repo-path> [...]" >&2
    exit 2
    ;;
  *)
    for r in "$@"; do install_one "${r%/}"; done
    ;;
esac
