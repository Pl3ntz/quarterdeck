#!/bin/bash
# Test Gate — PreToolUse Hook on Bash
# Blocks git commit if no test execution detected in the session transcript
#
# Strategy: When command is "git commit", check transcript for test execution
# If no tests found, BLOCK with message to run tests first
#
# I/O Contract (PreToolUse):
# - Input: JSON via stdin (tool_name, tool_input)
# - Output: JSON with permissionDecision deny to block, {} to allow
# - Exit 0 always

. "$HOME/.claude/hooks/lib/hook-common.sh"

input=$(cat)

# Fast path: extract command
command=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$command" ]; then
  echo '{}'
  exit 0
fi

# Only gate git commit commands (suporta `cd <dir> && ... && git commit`)
if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit\b'; then
  echo '{}'
  exit 0
fi

# Detect working dir from command (cd <path> &&) ou fallback PWD.
# hook_work_dir expands a literal ~ / $HOME: without that, `cd ~/repo` yielded the
# directory "~/repo", every -f test below failed, and this gate silently ALLOWED the
# commit. Confirmed failing open on 2026-07-24; fixed via the shared helper so the same
# defect cannot reappear in a fourth hook.
work_dir=$(hook_work_dir "$command")

# Projeto containerizado: testes rodam dentro do container, nao localmente.
# Conflita com CRITICAL RULE "NEVER run build/test commands locally".
# Libera commit — gate de teste deve estar no CI/CD ou no docker-compose.
if [ -f "$work_dir/docker-compose.yml" ] || [ -f "$work_dir/docker-compose.yaml" ] || [ -f "$work_dir/Dockerfile" ] || [ -f "$work_dir/compose.yml" ] || [ -f "$work_dir/compose.yaml" ]; then
  echo '{}'
  exit 0
fi

# Detect if project has a test framework configured
has_test_framework=false

# JS / TS — vitest, jest, mocha, playwright, testing-library
if [ -f "$work_dir/package.json" ]; then
  if grep -qE '"(vitest|jest|mocha|@playwright/test|@testing-library/[^"]+)"\s*:' "$work_dir/package.json" 2>/dev/null; then
    has_test_framework=true
  fi
fi

# Python
[ -f "$work_dir/pytest.ini" ] && has_test_framework=true
[ -f "$work_dir/conftest.py" ] && has_test_framework=true
if [ -f "$work_dir/pyproject.toml" ] && grep -qE 'pytest|\[tool\.pytest' "$work_dir/pyproject.toml" 2>/dev/null; then
  has_test_framework=true
fi

# Rust / Go (test são built-in nesses ecossistemas)
[ -f "$work_dir/Cargo.toml" ] && has_test_framework=true
[ -f "$work_dir/go.mod" ] && has_test_framework=true

# Elixir / Ruby
[ -f "$work_dir/mix.exs" ] && has_test_framework=true
[ -f "$work_dir/Gemfile" ] && grep -qiE 'rspec|minitest' "$work_dir/Gemfile" 2>/dev/null && has_test_framework=true

# Sem framework — não há o que rodar, libera
if [ "$has_test_framework" = false ]; then
  echo '{}'
  exit 0
fi

# --- Evidence, strongest first --------------------------------------------------------
#
# A test-run ARTIFACT that is newer than the code being committed is real evidence: it shows
# the suite ran against this version. The transcript only shows a command was typed -- not
# that it ran, not that it passed, and not that the code has not changed since. eval-gate.sh
# migrated away from transcript-grepping for exactly this reason and its header says so.
#
# The transcript check is kept below as a weaker fallback, because removing it would deny
# every project that emits no artifact, and a gate with that much friction gets switched off.
# But the artifact path adds a case the transcript can NEVER catch: tests ran, then the code
# changed, then the commit. Today that passes.
artifact_verdict=$(WORK_DIR="$work_dir" python3 <<'PY' 2>/dev/null
import os, glob
from pathlib import Path
import subprocess

work = Path(os.environ.get('WORK_DIR', '.'))

CANDIDATES = [
    'coverage/lcov.info', 'coverage/coverage-final.json', 'coverage.xml', '.coverage',
    'junit.xml', 'test-results.xml', 'test-results/*.xml', 'reports/junit/*.xml',
    'htmlcov/index.html', 'coverage.out', '.nyc_output/processinfo/index.json',
    '.pytest_cache/CACHEDIR.TAG', 'target/nextest/default/junit.xml',
    '.claude/last-test-run',
]
newest_art = 0.0
for pat in CANDIDATES:
    for hit in glob.glob(str(work / pat)):
        try:
            newest_art = max(newest_art, os.path.getmtime(hit))
        except OSError:
            pass

if not newest_art:
    print('NO_ARTIFACT')
    raise SystemExit

try:
    out = subprocess.run(['git', '-C', str(work), 'diff', '--cached', '--name-only'],
                         capture_output=True, text=True, timeout=5)
    staged = [l for l in out.stdout.splitlines() if l.strip()]
except Exception:
    print('NO_ARTIFACT')
    raise SystemExit

newest_src = 0.0
for rel in staged:
    p = work / rel
    try:
        newest_src = max(newest_src, os.path.getmtime(p))
    except OSError:
        pass

if not newest_src:
    print('NO_ARTIFACT')
elif newest_art >= newest_src:
    print('FRESH')
else:
    print('STALE')
PY
)

if [ "$artifact_verdict" = "FRESH" ]; then
  echo '{}'
  exit 0
fi

if [ "$artifact_verdict" = "STALE" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"TEST GATE: existe resultado de suite no projeto, mas ele e MAIS ANTIGO que os arquivos no stage. A suite rodou antes desta alteracao, entao nao diz nada sobre o que voce esta commitando. Rode de novo (no container, se o projeto for containerizado). Override deliberado: TESTGATE_OFF=1"},"systemMessage":"TEST GATE: resultado de suite mais antigo que o codigo no stage."}'
  exit 0
fi

# Fallback: session transcript. Weak on purpose -- see the note above.
transcript_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null)

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  # No transcript available — allow (don't block without evidence)
  echo '{}'
  exit 0
fi

# Search transcript for test execution patterns
if grep -qiE 'npm\s+test|npx\s+vitest|npx\s+jest|pytest|python3?\s+-m\s+pytest|cargo\s+test|go\s+test|mix\s+test|bundle\s+exec\s+rspec|vitest\s+run|xcodebuild[^|]*\stest\b|swift\s+test\b|bun\s+test|bun\s+run\s+test' "$transcript_path" 2>/dev/null; then
  # Tests were run in this session
  echo '{}'
  exit 0
fi

# No test execution found — BLOCK
# CAUTION: this message must NEVER contain any literal that the grep above searches for.
#
# It used to end with "Use: npm test, pytest, vitest run, bun test, etc." -- four of the exact
# patterns line 87 looks for. Hook output is persisted into the session transcript, so the
# first deny wrote its own bypass token: every later commit in that session found "npm test"
# in the transcript and was allowed through. Proven by running the gate against a transcript
# containing nothing but this hook's own deny message: clean -> deny, self-polluted -> allow.
# The gate disarmed itself permanently after firing once, which is worse than not existing --
# it fires on the first commit, so it looks like it works.
#
# permissionDecisionReason added at the same time: without it the model receives a bare
# refusal with no explanation and routes around it.
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"TEST GATE: nenhuma execucao da suite foi detectada nesta sessao. Rode a suite do projeto antes de commitar (dentro do container, se o projeto for containerizado). Override deliberado: TESTGATE_OFF=1"},"systemMessage":"TEST GATE: nenhuma execucao da suite detectada nesta sessao. Rode a suite do projeto antes de commitar."}'
exit 0
