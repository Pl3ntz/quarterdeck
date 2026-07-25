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

# Detect working dir from command (cd <path> &&) ou fallback PWD
work_dir=$(echo "$command" | grep -oE 'cd[[:space:]]+[^&;]+' | head -1 | sed -E 's/^cd[[:space:]]+//' | xargs)
[ -z "$work_dir" ] && work_dir="$PWD"

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

# Check session transcript for test execution
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
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"TEST GATE: Nenhuma execucao de testes detectada nesta sessao. Rode os testes antes de commitar. Use: npm test, pytest, vitest run, bun test, etc."}'
exit 0
