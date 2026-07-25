#!/usr/bin/env bash
# test-guardrails — regression suite for the PreToolUse Bash hooks.
#
# Why: two guardrails (eval-gate, test-gate) silently failed OPEN for months because a
# literal `~` in `cd ~/repo` was never expanded, so every path test inside them missed.
# Nothing caught it because nothing tested them. A guardrail without a test is a claim,
# not a control.
#
# Each case asserts the DECISION for a crafted payload: deny or allow. Both path forms
# (absolute and tilde) are exercised wherever a hook resolves a working directory, since
# that is precisely where the rot was.
#
# Usage: test-guardrails.sh [-v]      exit 0 = all pass, 1 = at least one regression

set -uo pipefail
HOOKS="$HOME/.claude/hooks"
VERBOSE="${1:-}"
pass=0; fail=0

decide() {
  # decide <hook> <command> [transcript_path]
  local hook="$1" cmd="$2" tr="${3:-}"
  python3 -c "
import json,sys
print(json.dumps({'tool_input':{'command':sys.argv[1]},'transcript_path':sys.argv[2]}))" "$cmd" "$tr" \
  | bash "$HOOKS/$hook" 2>/dev/null \
  | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('MALFORMED'); raise SystemExit
print(d.get('hookSpecificOutput',{}).get('permissionDecision','allow'))"
}

check() {
  # check <label> <expected> <hook> <command> [transcript]
  local label="$1" expected="$2" hook="$3" cmd="$4" tr="${5:-}"
  local got; got=$(decide "$hook" "$cmd" "$tr")
  if [ "$got" = "$expected" ]; then
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "$label" "$got"
  else
    fail=$((fail+1)); printf '  FAIL  %-56s expected=%s got=%s\n' "$label" "$expected" "$got"
  fi
}

# --- fixtures -------------------------------------------------------------------------
TMP="$HOME/.claude/tmp/guardrail-test"
rm -rf "$TMP"; mkdir -p "$TMP"
printf '{"devDependencies":{"vitest":"^1.0.0"}}\n' > "$TMP/package.json"
EMPTY_TR="$TMP/empty.jsonl"; : > "$EMPTY_TR"
TESTED_TR="$TMP/tested.jsonl"; echo "npm test" > "$TESTED_TR"
ABS="$TMP"
TILDE="~/.claude/tmp/guardrail-test"

echo "block-build — heavy build on the host"
check "npm run build"                    deny  block-build.sh "npm run build"
check "cargo build --release"            deny  block-build.sh "cargo build --release"
check "build behind a tilde cd"          deny  block-build.sh "cd $TILDE && pnpm build"
check "explicit override"                allow block-build.sh "ALLOW_HOST_BUILD=1 npm run build"
check "test runner is not a build"       allow block-build.sh "vitest run"
check "pytest is not a build"            allow block-build.sh "pytest -q"
check "docker build (sanctioned path)"   allow block-build.sh "docker compose up -d --build"
check "unrelated command"                allow block-build.sh "git status"

echo "test-gate — commit without tests"
check "absolute path, no tests run"      deny  test-gate.sh "cd $ABS && git com""mit -m x" "$EMPTY_TR"
check "TILDE path, no tests run"         deny  test-gate.sh "cd $TILDE && git com""mit -m x" "$EMPTY_TR"
check "tests present in transcript"      allow test-gate.sh "cd $TILDE && git com""mit -m x" "$TESTED_TR"
check "not a commit"                     allow test-gate.sh "cd $ABS && npm test" "$EMPTY_TR"

echo "eval-gate — agent edited without a fresh eval"
check "not a quarterdeck repo"           allow eval-gate.sh "cd $ABS && git com""mit -m x" "$EMPTY_TR"
check "explicit override"                allow eval-gate.sh "EVALGATE_OFF=1 git com""mit -m x" "$EMPTY_TR"
check "unrelated command"                allow eval-gate.sh "ls -la" "$EMPTY_TR"

echo "production-gate — destructive local commands"
check "rm -rf on \$HOME"                  ask   production-gate.sh "rm -rf ~/something"
check "git reset --hard"                 ask   production-gate.sh "git reset --hard origin/main"
check "read-only command"                allow production-gate.sh "git status"

# Host aliases are read from the local conf, never hardcoded: this script is mirrored to a
# public repo and the aliases are infrastructure identifiers.
#
# Every alias in PROD_ALIASES gets the same treatment. Until 2026-07-25 the personal VPS
# was missing from that list, so `systemctl stop postgresql`, `docker compose down` and
# overwriting nginx.conf all passed ungated there while being blocked on the other host.
# The list is the whole control surface, so the suite walks all of it.
CONF="$HOME/.claude/hooks/production-gate.conf"
if [ -f "$CONF" ]; then
  ALIASES=$(grep -m1 '^PROD_ALIASES=' "$CONF" | cut -d= -f2- | tr '|' '\n' | grep -vE '\\\.' | tr -d ' ')
  for host in $ALIASES; do
    [ -n "$host" ] || continue
    echo "production-gate — SSH to a production host (${host})"
    check "  stop a service"               ask   production-gate.sh "ssh $host 'systemctl stop postgresql'"
    check "  compose down"                 ask   production-gate.sh "ssh $host 'docker compose down'"
    check "  overwrite a config"           ask   production-gate.sh "ssh $host 'echo x > /etc/nginx/nginx.conf'"
    check "  interactive shell"            ask   production-gate.sh "ssh $host"
    check "  read-only: docker ps"         allow production-gate.sh "ssh $host 'docker ps'"
    check "  read-only: service status"    allow production-gate.sh "ssh $host 'systemctl status caddy'"
    check "  read-only: disk"              allow production-gate.sh "ssh $host 'df -h'"
  done
fi

rm -rf "$TMP"

echo
if [ "$fail" -eq 0 ]; then
  echo "guardrails: ${pass} passed"
  exit 0
fi
echo "guardrails: ${pass} passed, ${fail} FAILED"
exit 1
