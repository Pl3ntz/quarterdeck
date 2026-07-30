#!/usr/bin/env bash
# mode.sh — how far may the leak-guard go in this repository?
#
# Sourced by the pre-commit / pre-push / commit-msg hooks and by the shell wrapper.
#
# Three states, read from .git/leakguard-mode (written by install-public-repo-guard.sh):
#
#   meta     BLOCK.     A public mirror of the operator's own config or tooling. This is where
#                       the guard came from and where a leaked identifier has no upside at all.
#   project  ADVISE.    A public repo that ships something he built. It runs, it prints every
#                       finding, and it never changes the exit code. The finding reaches him;
#                       the decision stays his.
#   (absent) SKIP.      The installer classifies every public repo it finds, so no file means
#                       the repo is private. A private repo legitimately carries its own
#                       project name, its own hosts, its own identifiers -- all of which are on
#                       the denylist by design. Scanning there produced a block on literally
#                       every commit and every push: committing to a project whose name is on
#                       the list matches the list. That is not protection, it is a repo that
#                       cannot be worked in.
#
# 2026-07-30. The previous default was the opposite -- absent read as "meta" -- and the shell
# wrapper applies to EVERY repo, private included, where --no-verify cannot escape it. The net
# effect was that private development stopped. The wrapper's own README already said private
# repos should be skipped "because the whole-blob scan only false-positives there"; the skip
# list just never grew past one entry, and a list nobody maintains is a default in disguise.
#
# LEAKGUARD_FORCE_BLOCK=1 forces the strict reading anywhere, for testing.

# leakguard_mode -> meta | project | skip
leakguard_mode() {
  [ -n "${LEAKGUARD_FORCE_BLOCK:-}" ] && { echo meta; return; }
  local gd mode
  # --git-common-dir, not --absolute-git-dir: inside a linked worktree the latter returns
  # <main>/.git/worktrees/<name>, where no policy file exists, so the worktree read "skip" while
  # its own main checkout read "meta". The rules mandate worktrees for parallel write-agents, so
  # that was agent commits in a public repo running unguarded. Verified 2026-07-30.
  gd="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { echo skip; return; }
  [ -n "$gd" ] || { echo skip; return; }
  [ -r "$gd/leakguard-mode" ] || { echo skip; return; }
  mode="$(grep -vE '^[[:space:]]*(#|$)' "$gd/leakguard-mode" | head -1 | tr -d '[:space:]')"
  case "$mode" in
    project) echo project ;;
    *)       echo meta ;;   # anything unrecognised in a file that EXISTS reads as strict
  esac
}

# True when this repo should be scanned at all.
leakguard_enabled() { [ "$(leakguard_mode)" != "skip" ]; }

# True when a finding should stop the operation.
leakguard_blocking() { [ "$(leakguard_mode)" = "meta" ]; }

# leakguard_advisory_notice <what>
# Printed when findings exist but this repo does not block on them.
leakguard_advisory_notice() {
  echo "" >&2
  echo "──────────────────────────────────────────────────────────────────────" >&2
  echo "leak-guard: AVISO, nada foi bloqueado. Os achados acima estao no ${1}." >&2
  echo "Como proceder: se for identificador real seu (IP, alias de servidor,"   >&2
  echo "credencial, nome de projeto privado), tire antes de publicar. Se for"   >&2
  echo "falso-positivo ou intencional, siga em frente."                         >&2
  echo "Voltar a bloquear neste repo:"                                          >&2
  echo "  echo meta > \"\$(git rev-parse --git-dir)/leakguard-mode\""           >&2
  echo "Silenciar de vez neste repo:"                                           >&2
  echo "  rm -f \"\$(git rev-parse --git-dir)/leakguard-mode\""                 >&2
  echo "──────────────────────────────────────────────────────────────────────" >&2
}
