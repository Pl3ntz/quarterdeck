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
# Overridable so the commit gate can point the suite at the hooks being COMMITTED rather
# than the ones installed. Testing the installed copy would pass while shipping a broken one.
HOOKS="${HOOKS:-$HOME/.claude/hooks}"
VERBOSE="${1:-}"
pass=0; fail=0; skipped=0

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
# Anchored with an explicit cd. Without one the hook resolves $PWD, and since the per-repo
# opt-out landed the answer legitimately depends on which repo the suite runs from: both of
# these flipped to allow when the suite was run from inside an opted-in repo. The cwd
# dependency was in the check, not in the hook.
check "npm run build"                    deny  block-build.sh "cd $ABS && npm run build"
check "cargo build --release"            deny  block-build.sh "cd $ABS && cargo build --release"
check "build behind a tilde cd"          deny  block-build.sh "cd $TILDE && pnpm build"
check "explicit override"                allow block-build.sh "ALLOW_HOST_BUILD=1 npm run build"
check "test runner is not a build"       allow block-build.sh "vitest run"
check "pytest is not a build"            allow block-build.sh "pytest -q"
check "docker build (sanctioned path)"   allow block-build.sh "docker compose up -d --build"
check "unrelated command"                allow block-build.sh "git status"
# Per-repo opt-out (2026-07-30). The global block froze ordinary work in 44 light repos over a
# rule written for one containerised stack.
BB="$TMP/bbrepo"; mkdir -p "$BB"; git -C "$BB" init -q .
check "repo not opted in"                deny  block-build.sh "cd $BB && npm run buil""d"
: > "$BB/.git/allow-host-build"
check "repo opted in"                    allow block-build.sh "cd $BB && npm run buil""d"
# A cd-chain must resolve to the LAST cd, where the command actually runs. Reading the first one
# was wrong in both directions and defeated the whole per-repo scoping for any multi-hop command.
BB2="$TMP/bbrepo2"; mkdir -p "$BB2"; git -C "$BB2" init -q .
check "chain ends in a blocked repo"     deny  block-build.sh "cd $BB && cd $BB2 && npm run buil""d"
check "chain ends in an opted-in repo"   allow block-build.sh "cd $ABS && cd $BB && npm run buil""d"
# Naming a build command in a commit message or a PR body is prose, not an invocation. The gate
# blocked its own commit over this. The exemption is narrow: quoted spans are stripped for git
# and gh only, so a genuine `bash -c "..."` invocation still matches.
check "build named in a commit message"  allow block-build.sh "git com""mit -m 'perf: speed up npm run buil""d'"
check "build named in a PR body"         allow block-build.sh "gh pr create --body \"fixes npm run buil""d\""
check "real build next to a commit"      deny  block-build.sh "git com""mit -m ok && cd $ABS && npm run buil""d"
check "bash -c build is still a build"   deny  block-build.sh "bash -c \"npm run buil""d\""

echo "test-gate — commit without tests"
check "absolute path, no tests run"      deny  test-gate.sh "cd $ABS && git com""mit -m x" "$EMPTY_TR"
check "TILDE path, no tests run"         deny  test-gate.sh "cd $TILDE && git com""mit -m x" "$EMPTY_TR"
check "tests present in transcript"      allow test-gate.sh "cd $TILDE && git com""mit -m x" "$TESTED_TR"
check "not a commit"                     allow test-gate.sh "cd $ABS && npm test" "$EMPTY_TR"
# The gate reads the session transcript, and hook output is written INTO that transcript. So a
# deny message that names the very commands the gate greps for is a bypass token the gate hands
# itself: it fired once, polluted the transcript, and allowed every commit afterwards. Found
# 2026-07-26, after this suite had passed 57/57 against the broken version all day -- asserting
# the FIRST decision cannot see a gate that only disarms on the second.
SELFPOL_TR="$TMP/selfpolluted.jsonl"
# Build the payload the same way decide() does. Hand-rolling the JSON with printf produced a
# payload the hook rejected, so the fixture came out as "{}" and the check passed against the
# BROKEN gate too -- a test that could not fail, which is the exact defect this suite exists to
# catch. Caught only by running it against a deliberately broken copy.
python3 -c "
import json,sys
print(json.dumps({'tool_input':{'command':sys.argv[1]},'transcript_path':sys.argv[2]}))" \
  "cd $ABS && git com""mit -m x" "$EMPTY_TR" \
  | bash "$HOOKS/test-gate.sh" 2>/dev/null > "$SELFPOL_TR"
check "own deny output is not a bypass"   deny  test-gate.sh "cd $ABS && git com""mit -m x" "$SELFPOL_TR"

# Artifact evidence. A suite result NEWER than the staged code proves the suite ran against this
# version; an OLDER one proves it ran against a previous one, which the transcript check cannot
# distinguish at all -- there, "tests ran, then the code changed, then commit" passes.
GITREPO="$TMP/artifact-repo"; mkdir -p "$GITREPO/coverage"
git -C "$GITREPO" init -q . 2>/dev/null
printf '{"devDependencies":{"vitest":"^1.0.0"}}\n' > "$GITREPO/package.json"
echo "x" > "$GITREPO/src.js"
git -C "$GITREPO" add -A 2>/dev/null
sleep 1; echo "cov" > "$GITREPO/coverage/lcov.info"
check "artifact newer than staged code"  allow test-gate.sh "cd $GITREPO && git com""mit -m x" "$EMPTY_TR"
sleep 1; echo "y" >> "$GITREPO/src.js"; git -C "$GITREPO" add -A 2>/dev/null
# TESTED_TR on purpose, not EMPTY_TR: with an empty transcript the fallback denies anyway, so
# the check would pass even with the artifact logic deleted -- satisfied for the wrong reason.
# Against a transcript that DOES show a test command, only the artifact check can produce deny,
# which is what makes this a discriminator.
check "stale artifact beats transcript"  deny  test-gate.sh "cd $GITREPO && git com""mit -m x" "$TESTED_TR"

echo "eval-gate — agent edited without a fresh eval"
check "not a quarterdeck repo"           allow eval-gate.sh "cd $ABS && git com""mit -m x" "$EMPTY_TR"
check "explicit override"                allow eval-gate.sh "EVALGATE_OFF=1 git com""mit -m x" "$EMPTY_TR"
check "unrelated command"                allow eval-gate.sh "ls -la" "$EMPTY_TR"

echo "review-gate — commit without a review of this diff"
RG="$TMP/rg"; mkdir -p "$RG/.claude"
git -C "$RG" init -q 2>/dev/null; git -C "$RG" config user.email t@t; git -C "$RG" config user.name t
printf 'def f(x):\n    return x\n' > "$RG/app.py"; git -C "$RG" add app.py 2>/dev/null
touch "$RG/.claude/review-gate"
check "opted-in repo, code unreviewed"  deny  review-gate.sh "cd $RG && git com""mit -m x"
check "explicit override"               allow review-gate.sh "REVIEWGATE_OFF=1 git com""mit -m x"
rm "$RG/.claude/review-gate"
check "repo not opted in"               allow review-gate.sh "cd $RG && git com""mit -m x"
touch "$RG/.claude/review-gate"
printf '# just docs\n' > "$RG/README.md"; git -C "$RG" reset -q; git -C "$RG" add README.md 2>/dev/null
check "docs only, nothing to review"    allow review-gate.sh "cd $RG && git com""mit -m x"

echo "egress-guard — sensitive data leaving via a non-git path"
# The fixtures are SYNTHESISED, never written literally: a suite that guards against
# secrets and PII would otherwise carry them, and this file is mirrored to a public repo.
# The host alias is read from the local conf, the CPF is computed from its check digits,
# and the key is assembled from fragments.
FAKE_CPF=$(python3 -c "
def dv(b):
    s=sum(int(d)*w for d,w in zip(b,range(len(b)+1,1,-1))); r=11-s%11
    return '0' if r>=10 else str(r)
b='529982247'; d1=dv(b); print(b+d1+dv(b+d1))")
FAKE_KEY="sk-""ant-""api03-$(printf 'A%.0s' $(seq 1 48))"
HOST=$(grep -m1 '^PROD_ALIASES=' "$HOME/.claude/hooks/production-gate.conf" 2>/dev/null | cut -d= -f2- | cut -d'|' -f1)

egress() {
  local label="$1" expected="$2" payload="$3"
  local got; got=$(printf '%s' "$payload" | bash "$HOOKS/egress-guard.sh" 2>/dev/null \
    | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('hookSpecificOutput',{}).get('permissionDecision','allow'))")
  if [ "$got" = "$expected" ]; then pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "$label" "$got"
  else fail=$((fail+1)); printf '  FAIL  %-56s expected=%s got=%s\n' "$label" "$expected" "$got"; fi
}

[ -n "$HOST" ] && egress "infra alias in a WebFetch prompt" deny \
  "{\"tool_name\":\"WebFetch\",\"tool_input\":{\"url\":\"https://x.com\",\"prompt\":\"ssh $HOST\"}}"
egress "check-digit valid CPF typed into a browser" deny \
  "{\"tool_name\":\"mcp__playwright__browser_type\",\"tool_input\":{\"text\":\"$FAKE_CPF\"}}"
egress "API key in a search query" deny \
  "{\"tool_name\":\"WebSearch\",\"tool_input\":{\"query\":\"$FAKE_KEY\"}}"
egress "ordinary documentation fetch" allow \
  '{"tool_name":"WebFetch","tool_input":{"url":"https://docs.claude.com/x","prompt":"permission modes"}}'
egress "ordinary search" allow \
  '{"tool_name":"WebSearch","tool_input":{"query":"postgres index performance"}}'
egress "ordinary navigation" allow \
  '{"tool_name":"mcp__chrome-devtools__navigate_page","tool_input":{"url":"https://github.com"}}'

echo "authorship-guard — AI credit and emoji in commits and PRs"
# The trailer and the emoji are assembled at run time for the same reason the egress
# fixtures are: this file is mirrored to a public repo, and a literal example of the banned
# trailer sitting in it would be the very thing the guard exists to keep out.
COMMIT="git com""mit"
TRAILER="Co-Authored""-By: Claude <noreply@""anthropic.com>"
ROCKET=$(printf '\xf0\x9f\x9a\x80')
check "AI trailer in a commit"           deny  authorship-guard.sh "$COMMIT -m 'fix: bug

$TRAILER'"
check "AI credit in a PR body"           deny  authorship-guard.sh "gh pr create --body 'Generated with Claude Code'"
check "emoji in a commit subject"        deny  authorship-guard.sh "$COMMIT -m 'feat: ship it $ROCKET'"
check "emoji in a PR body"               deny  authorship-guard.sh "gh pr create --body 'Features $ROCKET'"
check "ordinary commit"                  allow authorship-guard.sh "$COMMIT -m 'fix(gate): expand a literal tilde'"
check "Claude named as subject matter"   allow authorship-guard.sh "$COMMIT -m 'docs: how Claude Code resolves subagent models'"
check "explicit override"                allow authorship-guard.sh "AUTHORSHIP_OFF=1 $COMMIT -m 'x $ROCKET'"
check "unrelated command"                allow authorship-guard.sh "git status"

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

# --- every block states the route through it -------------------------------------------
#
# Added 2026-07-30, on the Owner's instruction: a gate that only says no costs productivity
# twice -- once for the stop, once for the guessing that follows. Blocking is the obvious half;
# the message has to carry the correct procedure or the guardrail just relocates the problem.
#
# The contract is a literal "Como proceder:" clause in permissionDecisionReason, which is the
# model-facing channel. systemMessage does not count: only the user reads it, so a remediation
# written there never reaches the thing that has to act on it.
echo "gates — every block states how to proceed"

reason() {
  # reason <hook> <command> [transcript] -> permissionDecisionReason, or empty if it allowed
  local hook="$1" cmd="$2" tr="${3:-}"
  python3 -c "
import json,sys
print(json.dumps({'tool_input':{'command':sys.argv[1]},'transcript_path':sys.argv[2]}))" "$cmd" "$tr" \
  | bash "$HOOKS/$hook" 2>/dev/null \
  | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
h=d.get('hookSpecificOutput',{})
if h.get('permissionDecision','allow') in ('deny','ask'):
    print(h.get('permissionDecisionReason',''))"
}

remediation() {
  # remediation <label> <hook> <command> [transcript]
  local label="$1" hook="$2" cmd="$3" tr="${4:-}" r
  r="$(reason "$hook" "$cmd" "$tr")"
  if [ -z "$r" ]; then
    fail=$((fail+1)); printf '  FAIL  %-56s did not block, cannot check the message\n' "$label"
  elif printf '%s' "$r" | grep -q 'Como proceder:'; then
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "$label" "has remediation"
  else
    fail=$((fail+1)); printf '  FAIL  %-56s blocks without saying how to proceed\n' "$label"
  fi
}

BUILDCMD="npm run buil""d"
remediation "block-build"       block-build.sh      "cd $ABS && $BUILDCMD"
remediation "test-gate"         test-gate.sh        "cd $ABS && git com""mit -m x" "$EMPTY_TR"
remediation "production-gate"   production-gate.sh  "rm -rf ~/something"
remediation "authorship-guard"  authorship-guard.sh "git com""mit -m 'feat: ship it $ROCKET'"

# --- leak-guard: which identifiers are private, and where -----------------------------
#
# Added 2026-07-30. The denylist had conflated two different questions -- "is this identifier
# private?" and "does this repo have a reason to name it?" -- so six public repos could not
# commit their own GPL copyright, their own site domain or the contact address their store
# listing requires. It was patched three times with per-repo exemptions before the shape was
# recognised as wrong, and nothing here would have caught it: the suite tested the PreToolUse
# hooks and never the leak scanner.
#
# Samples are READ FROM THE LISTS at runtime, never written inline. This script is mirrored to
# a public repo, exactly like the host aliases above.
LG_SCAN="${LG_SCAN:-$HOME/.claude/scripts/quarterdeck-guard/leak-scan.sh}"
DENY_L="${QD_DENYLIST:-$HOME/.claude/local/quarterdeck-denylist.txt}"
PORTF_L="${QD_PORTFOLIOLIST:-$HOME/.claude/local/quarterdeck-denylist-portfolio.txt}"

if [ -x "$LG_SCAN" ] && [ -r "$DENY_L" ] && [ -r "$PORTF_L" ]; then
  # First pattern of each tier, unescaped into a literal that matches it. The lists lead with
  # simple patterns (a bare IP, a bare name), so dropping the ERE escapes is enough.
  unesc() { grep -vE '^[[:space:]]*(#|$)' "$1" | sed -n "${2:-1}p" | sed 's/\\b//g; s/\\//g'; }
  raw() { grep -vE '^[[:space:]]*(#|$)' "$1" | sed -n "${2:-1}p"; }
  HARD_SAMPLE="$(unesc "$DENY_L" 1)"
  HARD_OTHER="$(unesc "$DENY_L" 2)"
  ID_SAMPLE="$(unesc "$PORTF_L" 1)"

  # A project-mode repo whose exempt term is a REAL denylist entry. Exempting an invented name
  # would test nothing: a term absent from every list passes whether the exemption works or not,
  # which is how the first version of this check turned out incapable of failing.
  LGREPO="$TMP/leakrepo"; mkdir -p "$LGREPO"
  git -C "$LGREPO" init -q .
  raw "$DENY_L" 1 > "$LGREPO/.git/leakguard-self"
  echo project > "$LGREPO/.git/leakguard-mode"

  leak_check() {
    # leak_check <label> <block|pass> <mode> <text> [cwd]
    local label="$1" expected="$2" mode="$3" text="$4" dir="${5:-$HOME}" got
    if printf '+ %s\n' "$text" | (cd "$dir" && QD_MODE="$mode" bash "$LG_SCAN") >/dev/null 2>&1; then
      got=pass
    else
      got=block
    fi
    if [ "$got" = "$expected" ]; then
      pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "$label" "$got"
    else
      fail=$((fail+1)); printf '  FAIL  %-56s expected=%s got=%s\n' "$label" "$expected" "$got"
    fi
  }

  echo "leak-guard — private identifiers block everywhere"
  leak_check "infra identifier in a project repo"   block project "$HARD_SAMPLE"
  leak_check "infra identifier in a meta repo"      block meta    "$HARD_SAMPLE"

  echo "leak-guard — published identity is not a leak in its own repo"
  # This is the regression. Before the fix both of these blocked, and the repo was frozen.
  leak_check "own identity, project repo"           pass  project "$ID_SAMPLE"
  leak_check "own identity, meta repo"              block meta    "$ID_SAMPLE"

  echo "leak-guard — self-exemption covers the repo, not its neighbours"
  leak_check "repo naming its own exempt term"      pass  project "$HARD_SAMPLE" "$LGREPO"
  leak_check "repo naming a neighbour too"          block project "$HARD_SAMPLE and $HARD_OTHER" "$LGREPO"

  echo "leak-guard — fail-closed"
  # An unclassified repo must get the STRICTER tier. Read as "project" it would ship identity.
  if printf '+ %s\n' "$ID_SAMPLE" | QD_MODE_FILE=/nonexistent/leakguard-mode bash "$LG_SCAN" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL  %-56s expected=block got=pass\n' "unclassified repo gets the strict tier"
  else
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "unclassified repo gets the strict tier" "block"
  fi
  # A meta repo whose identity list vanished must block, not silently drop the tier.
  if printf '+ harmless text\n' | QD_MODE=meta QD_PORTFOLIOLIST=/nonexistent/list bash "$LG_SCAN" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL  %-56s expected=block got=pass\n' "meta repo with the identity list missing"
  else
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "meta repo with the identity list missing" "block"
  fi
else
  skipped=$((skipped+1))
  echo "leak-guard — SKIPPED (scanner or lists not present on this machine)"
fi

# --- who a control applies to, and how hard -------------------------------------------
#
# Added 2026-07-30. Every incident that day was in this layer -- the one that decides WHETHER a
# control applies to a given repo -- and a grep for mode.sh / git-wrapper / leakguard_enabled
# across this file returned zero. The 74 checks above test what accepts JSON on stdin; nothing
# tested enrolment, which is where the damage was.
#
# Two content classes, because they must be treated differently:
#   CRED  a credential. Never a false positive. Must block wherever the guard runs at all.
#   NAME  a private identifier. False-positive-prone by design (a repo names its own project),
#         so it is advisory in a project repo.
# Collapsing the two is exactly the regression this section exists to catch: for a few hours the
# advisory downgrade swallowed the credential layer along with the noisy one.
# Overridable so these checks can be pointed at a deliberately broken copy. A check nobody has
# watched fail is a check that might not be able to fail -- three in this file could not.
LGH="${LEAKGUARD_HOOK:-$HOME/.claude/scripts/leak-guard/hooks/pre-commit}"
LGC="${LEAKGUARD_SCAN:-$HOME/.claude/scripts/leak-guard/scan-content.sh}"

if [ -r "$LGH" ] && [ -x "$LGC" ]; then
  echo "leak-guard — enrolment: who the control applies to"

  # Split literals: this file is mirrored publicly and scanned by the very guard it tests.
  CRED="aws_key = AKIA""IOSFODNN7EXAMPLE"
  NAME_SRC="$(grep -vE '^[[:space:]]*(#|$)' "$HOME/.claude/local/quarterdeck-denylist.txt" \
              | head -1 | sed 's/\\b//g; s/\\//g')"

  lg_repo() {
    # lg_repo <name> <mode|private> <content> -> prints the pre-commit exit code
    local d="$TMP/lg-$1"
    mkdir -p "$d"; git -C "$d" init -q . 2>/dev/null
    [ "$2" = "private" ] || echo "$2" > "$d/.git/leakguard-mode"
    printf '%s\n' "$3" > "$d/file.txt"
    git -C "$d" add file.txt 2>/dev/null
    ( cd "$d" && bash "$LGH" >/dev/null 2>&1; echo $? )
  }

  lg_check() {
    # lg_check <label> <expected 0|1> <name> <mode> <content>
    local label="$1" expected="$2" got
    got="$(lg_repo "$3" "$4" "$5")"
    if [ "$got" = "$expected" ]; then
      pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s exit=%s\n' "$label" "$got"
    else
      fail=$((fail+1)); printf '  FAIL  %-56s expected exit=%s got=%s\n' "$label" "$expected" "$got"
    fi
  }

  lg_check "private repo is not scanned at all"   0 priv-c private "$CRED"
  lg_check "project repo still blocks a credential" 1 proj-c project "$CRED"
  lg_check "project repo only advises on a name"  0 proj-n project "$NAME_SRC"
  lg_check "meta repo blocks a name"              1 meta-n meta    "$NAME_SRC"

  echo "leak-guard — severity is not collapsed"
  # scan-content must distinguish the two, or the advisory downgrade cannot be selective.
  printf '%s\n' "$CRED" | bash "$LGC" probe >/dev/null 2>&1; sc=$?
  if [ "$sc" = "1" ]; then pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s exit=1\n' "credential is the hard tier"
  else fail=$((fail+1)); printf '  FAIL  %-56s expected exit=1 got=%s\n' "credential is the hard tier" "$sc"; fi
  printf '%s\n' "$NAME_SRC" | bash "$LGC" probe >/dev/null 2>&1; sn=$?
  if [ "$sn" = "2" ]; then pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s exit=2\n' "private name is the soft tier"
  else fail=$((fail+1)); printf '  FAIL  %-56s expected exit=2 got=%s\n' "private name is the soft tier" "$sn"; fi

  echo "leak-guard — a worktree inherits its repo's policy"
  # --git-dir inside a linked worktree points at <main>/.git/worktrees/<name>, which holds no
  # policy file, so the worktree read "skip" while its own main checkout read "meta". The rules
  # mandate worktrees for parallel write-agents, so this was agent commits running unguarded.
  WT="$TMP/wt-main"; mkdir -p "$WT"
  git -C "$WT" init -q . 2>/dev/null
  git -C "$WT" config user.email t@t; git -C "$WT" config user.name t
  echo x > "$WT/a.txt"; git -C "$WT" add a.txt 2>/dev/null
  git -C "$WT" commit -q -m init 2>/dev/null
  echo meta > "$WT/.git/leakguard-mode"
  git -C "$WT" worktree add -q "$TMP/wt-linked" -b wtb 2>/dev/null
  if [ -d "$TMP/wt-linked" ]; then
    wtm="$( cd "$TMP/wt-linked" && QD_MODE= bash -c '. "$HOME/.claude/scripts/leak-guard/mode.sh"; leakguard_mode' )"
    if [ "$wtm" = "meta" ]; then
      pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s %s\n' "worktree reads the main checkout's mode" "$wtm"
    else
      fail=$((fail+1)); printf '  FAIL  %-56s expected=meta got=%s\n' "worktree reads the main checkout's mode" "$wtm"
    fi
  fi

  echo "leak-guard — an emptied list is not an empty threat"
  # Deleting a pattern list already failed closed; emptying one did not, and silently disarmed
  # every tier. The two have to behave the same way.
  : > "$TMP/empty-deny.txt"
  printf '+ anything\n' | QD_DENYLIST="$TMP/empty-deny.txt" QD_MODE=project \
    bash "$HOME/.claude/scripts/quarterdeck-guard/leak-scan.sh" >/dev/null 2>&1; el=$?
  if [ "$el" != "0" ]; then
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s exit=%s\n' "empty denylist blocks" "$el"
  else
    fail=$((fail+1)); printf '  FAIL  %-56s expected non-zero got=0 (fail-OPEN)\n' "empty denylist blocks"
  fi

  echo "leak-guard — the policy layer itself fails closed"
  # A missing mode.sh leaves leakguard_enabled undefined. Read as "skip", one deleted and
  # unversioned file disarms the guard in every repo at once.
  BROKEN="$TMP/broken-pre-commit"
  sed 's|\. "\$HOME/.claude/scripts/leak-guard/mode.sh"|. "/nonexistent/mode.sh"|' "$LGH" > "$BROKEN"
  d="$TMP/lg-failclosed"; mkdir -p "$d"; git -C "$d" init -q . 2>/dev/null
  echo project > "$d/.git/leakguard-mode"
  printf '%s\n' "$NAME_SRC" > "$d/file.txt"; git -C "$d" add file.txt 2>/dev/null
  fc="$( cd "$d" && bash "$BROKEN" >/dev/null 2>&1; echo $? )"
  if [ "$fc" != "0" ]; then
    pass=$((pass+1)); [ "$VERBOSE" = "-v" ] && printf '  ok    %-56s exit=%s\n' "mode.sh missing blocks" "$fc"
  else
    fail=$((fail+1)); printf '  FAIL  %-56s expected non-zero got=0 (fail-OPEN)\n' "mode.sh missing blocks"
  fi
else
  skipped=$((skipped+1))
  echo "leak-guard — enrolment: SKIPPED (leak-guard not installed on this machine)"
fi

rm -rf "$TMP"

echo
# A skipped section reads as a passing one unless the count says otherwise: the only signal that
# a whole block had vanished was the total quietly dropping, which nobody watches.
SKIPNOTE=""
[ "$skipped" -gt 0 ] && SKIPNOTE=", ${skipped} SECTION(S) SKIPPED"
if [ "$fail" -eq 0 ]; then
  echo "guardrails: ${pass} passed${SKIPNOTE}"
  exit 0
fi
echo "guardrails: ${pass} passed, ${fail} FAILED${SKIPNOTE}"
exit 1
