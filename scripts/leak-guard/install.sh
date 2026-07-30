#!/usr/bin/env bash
# install.sh — set up the leak-guard.
#
# Usage:
#   install.sh <REPO_PATH>     install hooks into one repo (preserves existing hooks)
#   install.sh --global        set core.hooksPath so EVERY repo uses the guard hooks
#   install.sh --wrapper-only  only (re)install the shell wrapper into ~/.zshrc
#
# The shell wrapper (intercepts commit/push incl. --no-verify) is installed in
# all modes. Hooks are defense-in-depth for non-interactive git and GUI clients.
set -euo pipefail

GUARD="$HOME/.claude/scripts/leak-guard"
HOOKS_SRC="$GUARD/hooks"
ZRC="$HOME/.zshrc"
MARK_BEGIN="# >>> leak-guard wrapper >>>"
MARK_END="# <<< leak-guard wrapper <<<"

chmod +x "$GUARD"/*.sh "$GUARD"/pii_secrets_scan.py "$HOOKS_SRC"/pre-commit "$HOOKS_SRC"/pre-push "$HOOKS_SRC"/commit-msg 2>/dev/null || true

install_wrapper() {
  if [[ -f "$ZRC" ]] && grep -qF "$MARK_BEGIN" "$ZRC"; then
    echo "wrapper: already present in $ZRC (idempotent, left as-is)."
    return
  fi
  {
    echo ""
    echo "$MARK_BEGIN"
    echo "[ -f \"$GUARD/git-wrapper.sh\" ] && source \"$GUARD/git-wrapper.sh\""
    echo "$MARK_END"
  } >> "$ZRC"
  echo "wrapper: appended to $ZRC (open a new shell or 'source $ZRC' to activate)."
}

install_repo_hooks() {
  local repo="$1"
  local hooks_dir
  hooks_dir="$(git -C "$repo" rev-parse --git-path hooks 2>/dev/null || true)"
  [[ -z "$hooks_dir" ]] && { echo "ERROR: not a git repo: $repo" >&2; exit 1; }
  # git-path may be relative to the repo
  [[ "$hooks_dir" != /* ]] && hooks_dir="$repo/$hooks_dir"
  mkdir -p "$hooks_dir"
  for h in pre-commit pre-push commit-msg; do
    local dst="$hooks_dir/$h"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      # Preserve a real, non-leak-guard prior hook for chaining.
      if ! grep -q "leak-guard" "$dst" 2>/dev/null; then
        mv "$dst" "$hooks_dir/$h.leakguard-orig"
        chmod +x "$hooks_dir/$h.leakguard-orig" 2>/dev/null || true
        echo "  preserved prior $h -> $h.leakguard-orig (will be chained)"
      fi
    fi
    ln -sf "$HOOKS_SRC/$h" "$dst"
    echo "  installed $h -> $dst"
  done
  if git -C "$repo" config --local --get core.hooksPath >/dev/null 2>&1; then
    echo "  WARNING: this repo sets core.hooksPath (likely Husky) — .git/hooks is bypassed."
    echo "           The shell WRAPPER still covers it; hooks alone would not."
  fi
}

install_global() {
  git config --global core.hooksPath "$HOOKS_SRC"
  echo "global: core.hooksPath -> $HOOKS_SRC (applies to every repo without its own hooksPath)."
  echo "        NOTE: repos with their own core.hooksPath (Husky) override this — the wrapper covers them."
}

case "${1:-}" in
  --global)       install_global; install_wrapper ;;
  --wrapper-only) install_wrapper ;;
  "" )            echo "usage: install.sh <REPO_PATH> | --global | --wrapper-only" >&2; exit 2 ;;
  * )             install_repo_hooks "$1"; install_wrapper ;;
esac

# Sanity: warn loudly if the denylist (fail-closed dependency) is absent.
DENY="$HOME/.claude/local/quarterdeck-denylist.txt"
[[ -r "$DENY" ]] || echo "WARNING: denylist absent ($DENY) — scans will FAIL-CLOSED (block) until restored."
echo "leak-guard: install done."
