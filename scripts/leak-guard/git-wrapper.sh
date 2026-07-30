# leak-guard git wrapper — source this from ~/.zshrc.
#
# Wraps `git` so `git commit` / `git push` are scanned for sensitive data BEFORE
# git runs. Because the scan is in the shell function (not a git hook), --no-verify
# CANNOT skip it. It reads real blob bytes, so binary/gitattributes evasion is
# covered too. Non commit/push commands pass straight through.
#
# LIMITS (be honest): only protects `git` invoked as this shell function in this
# shell. Calling /usr/bin/git directly, GUI clients, or other shells bypass it —
# that is why the hooks exist too, and why server-side push-protection is the real
# backstop (see README). Escape hatch (audited): LEAKGUARD_OFF=1 git commit ...

git() {
  local sub="${1:-}"
  case "$sub" in
    commit|push) ;;
    *) command git "$@"; return $? ;;
  esac

  if [[ "${LEAKGUARD_OFF:-0}" == "1" ]]; then
    echo "leak-guard: OFF for this command (LEAKGUARD_OFF=1) — scan skipped." >&2
    command git "$@"; return $?
  fi

  local GUARD="$HOME/.claude/scripts/leak-guard"
  local SCAN="$GUARD/scan-content.sh"

  if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    command git "$@"; return $?
  fi
  # Private repos where real identifiers legitimately live (already upstream) are
  # allow-listed — the whole-blob scan only false-positives there. See repo-skip.sh.
  if bash "$GUARD/repo-skip.sh"; then
    echo "leak-guard: repo allow-listed (private) — scan skipped for git $sub." >&2
    command git "$@"; return $?
  fi
  # Same reading, but derived from the repo instead of from a hand-maintained list. That list
  # had exactly one entry, so every other private repo was being scanned in full — and a private
  # repo's own project name is ON the denylist, which meant every commit there matched. See
  # mode.sh: no .git/leakguard-mode means the installer never classified it, i.e. not public.
  . "$GUARD/mode.sh"
  # Fail-closed on the policy layer: a missing mode.sh leaves leakguard_enabled undefined,
  # and `if ! leakguard_enabled` then reads command-not-found as "not enabled" and runs git
  # unscanned. One deleted unversioned file would disarm the wrapper in every repo.
  if ! command -v leakguard_enabled >/dev/null 2>&1; then
    echo "leak-guard: mode.sh ausente — recusando git $sub (fail-closed)." >&2
    echo "Como proceder: restaure ~/.claude/scripts/leak-guard/mode.sh e repita." >&2
    return 1
  fi
  if ! leakguard_enabled; then
    command git "$@"; return $?
  fi
  if [[ ! -x "$GUARD/scan-staged.sh" || ! -x "$GUARD/scan-range.sh" ]]; then
    echo "leak-guard: scanner missing — refusing git $sub (fail-closed)." >&2
    return 1
  fi

  local rc=0 s=0
  # 1 (credential/PII) must never be masked by a later 2 (denylist only).
  merge() { if [ "$1" -eq 1 ]; then rc=1; elif [ "$1" -eq 2 ] && [ "$rc" -ne 1 ]; then rc=2; fi; }
  if [[ "$sub" == "commit" ]]; then
    s=0; bash "$GUARD/scan-staged.sh" || s=$?; merge "$s"
    # inline message (-m "..."): the args carry it; scan them (covers --no-verify).
    # Only the MESSAGE values, never the whole argv. Scanning "$*" meant scanning flags and file
    # paths: `git commit -F /Users/<name>/tmp/msg.txt` was blocked because the PATH matched the
    # identity tier, and a long temp path tripped the high-entropy rule. Neither was content
    # going anywhere. A message passed via -F is covered by the commit-msg hook, which reads the
    # file itself.
    # A take-next flag rather than indexing $@: array indexing is 1-based in zsh and 0-based in
    # bash, and this file is sourced by the first and tested under the second.
    local -a msgs=()
    local a take=0
    for a in "$@"; do
      if [ "$take" = "1" ]; then msgs+=("$a"); take=0; continue; fi
      case "$a" in
        --message=*) msgs+=("${a#--message=}") ;;
        -m|--message)  take=1 ;;
      esac
    done
    if [ ${#msgs[@]} -gt 0 ]; then
      s=0; printf '%s\n' "${msgs[@]}" | "$SCAN" "commit-message" || s=$?; merge "$s"
    fi
  else  # push — scan commits ahead of upstream (covers --no-verify push)
    local base sha
    sha="$(command git rev-parse HEAD 2>/dev/null || true)"
    base="$(command git rev-parse '@{u}' 2>/dev/null || echo 4b825dc642cb6eb9a060e54bf8d69288fbee4904)"
    if [[ -n "$sha" ]]; then s=0; bash "$GUARD/scan-range.sh" "$base" "$sha" || s=$?; merge "$s"; fi
  fi

  if [[ $rc -eq 2 ]] && ! leakguard_blocking; then
    leakguard_advisory_notice "que 'git $sub' ia enviar"
    rc=0
  fi

  if [[ $rc -ne 0 ]]; then
    echo "" >&2
    echo "leak-guard: BLOCKED 'git $sub' — sensitive data detected (see above)." >&2
    echo "This block also applies to --no-verify. Como proceder: remova o identificador" >&2
    echo "do conteudo e repita o comando; se ja estiver em commit anterior, use" >&2
    echo "git rebase -i ou git filter-repo antes de publicar. Se voce ja verificou" >&2
    echo "manualmente e e falso-positivo: LEAKGUARD_OFF=1 git $sub ..." >&2
    return 1
  fi

  command git "$@"
}
