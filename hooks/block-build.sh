#!/bin/bash
# Block Build — PreToolUse hook on Bash.
#
# Blocks heavy build commands in the two places where they cause real damage:
#
#   On the server  — builds belong in CI/CD, not on a box that also serves traffic.
#                    A build competing with running services is what produced the
#                    OOM-kill incident of 2026-07-23.
#   On the host    — the CRITICAL RULE in memory is verbatim: "NEVER run build/test
#                    commands locally ... Local execution almost crashed the machine."
#                    Until 2026-07-25 this hook exempted Darwin, so the rule born from a
#                    near-crash on the Mac was enforced everywhere except the Mac. It was
#                    prose, and prose does not stop a build.
#
# Scope is deliberately BUILD only, never test runners. test-gate.sh refuses a commit when
# the session ran no tests; blocking test runners here as well would leave a
# non-containerised project unable to satisfy either gate. Heavy test suites belong in the
# project's container by policy, which is a routing decision, not something to deadlock on.
#
# Escape hatch (host only, deliberate): ALLOW_HOST_BUILD=1 <command>
#
# I/O Contract (PreToolUse): {} allows; permissionDecision deny blocks. Exit 0 always.

. "$HOME/.claude/hooks/lib/hook-common.sh"

INPUT=$(cat)
COMMAND=$(hook_command "$INPUT")
[ -z "$COMMAND" ] && hook_allow

BUILD_PATTERN='(npm run build|npx .* ?build|pnpm (run )?build|yarn (run )?build|bun (run )?build|vite build|next build|nuxt build|remix build|webpack|rollup -|esbuild |tsc --build|tsc -b |cargo build|go build)'

echo "$COMMAND" | grep -qE "$BUILD_PATTERN" || hook_allow

if [[ "$(uname)" == "Darwin" ]]; then
  # Host. Allow a deliberate override, since some repos genuinely have no container.
  hook_override_requested "$COMMAND" "ALLOW_HOST_BUILD" && hook_allow

  # Per-repo opt-out. The rule this hook enforces says "NUNCA build PESADO no host", and the
  # incident behind it was a containerised multi-service stack. The pattern above cannot tell
  # that from a two-second bundle of a browser extension, so it blocked both and froze ordinary
  # work in every small project. The marker lives in .git/, not in the tree: several of these
  # repos are public and the policy is nobody's business but this machine's.
  #   allow:  host-build-policy.sh --allow <repo>
  #   revert: host-build-policy.sh --block <repo>
  WORKDIR="$(hook_work_dir "$COMMAND")"
  GITDIR="$(git -C "$WORKDIR" rev-parse --git-dir 2>/dev/null)"
  if [ -n "$GITDIR" ]; then
    case "$GITDIR" in /*) ;; *) GITDIR="$WORKDIR/$GITDIR" ;; esac
    [ -f "$GITDIR/allow-host-build" ] && hook_allow
  fi

  hook_deny "BLOQUEADO: build pesado no host (Mac). A regra existe porque uma execucao local ja quase travou a maquina. Como proceder: se o projeto for leve (bundle de front, extensao, CLI), libere-o de vez com bash ~/.claude/scripts/host-build-policy.sh --allow . e repita o comando; se for stack containerizada, rode dentro do container; se tiver pipeline, faca push e deixe a CI construir. So desta vez: ALLOW_HOST_BUILD=1 <comando>."
fi

# Server: no override. Builds here compete with running services.
hook_deny "BLOQUEADO: build no servidor compete com os servicos que estao servindo trafego -- foi assim que veio o OOM-kill. Como proceder: faca push da branch e deixe a pipeline construir (gh run watch para acompanhar); se precisar do artefato agora, construa na sua maquina e envie o resultado, nao o build."
