#!/bin/bash
# Eval Gate — PreToolUse Hook on Bash
# WARNS (never blocks) on `git commit` when a staged agents/*.md changed, that
# agent ships an eval fixture, and no eval run was detected in this session.
#
# Rationale: running the stability harness fires K LLM calls (minutes + cost), so
# it must NOT run inline on commit. This gate is the cheap reminder layer — it
# nudges you to run `stability_runner.py` before committing a prompt/model change,
# mirroring the console.log warn pattern. The real measurement stays manual.
#
# I/O Contract (PreToolUse):
# - Input: JSON via stdin (tool_input.command, transcript_path)
# - Output: JSON on stdout. {} = allow silently; {"systemMessage": "..."} = warn+allow.
# - NEVER emits permissionDecision:deny — this gate only warns.
# - Exit 0 always.

input=$(cat)

command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[ -z "$command" ] && { echo '{}'; exit 0; }

# Only gate git commit (supports `cd <dir> && ... && git commit`)
if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit\b'; then
  echo '{}'
  exit 0
fi

# Working dir from `cd <path> &&`, else PWD
work_dir=$(echo "$command" | grep -oE 'cd[[:space:]]+[^&;]+' | head -1 | sed -E 's/^cd[[:space:]]+//' | xargs)
[ -z "$work_dir" ] && work_dir="$PWD"

# Only act on a Quarterdeck-shaped repo (has the eval harness + agents dir).
# Any other repo commits normally — this hook is installed globally.
[ -f "$work_dir/scripts/eval/stability_runner.py" ] && [ -d "$work_dir/agents" ] || { echo '{}'; exit 0; }

# Staged agent definitions in this commit
changed=$(git -C "$work_dir" diff --cached --name-only 2>/dev/null | grep -E '^agents/[^/]+\.md$')
[ -z "$changed" ] && { echo '{}'; exit 0; }

transcript_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

# For each changed agent WITH a fixture, was its eval run this session?
need_eval=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  name=$(basename "$f" .md)
  if [ -f "$work_dir/tests/$name/expected-findings.md" ] || [ -d "$work_dir/evals/$name" ]; then
    ran=""
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
      grep -qE "stability_runner\.py[^\"']*(--agent[= ]+$name|--all)|evals/$name" "$transcript_path" 2>/dev/null && ran=1
    fi
    [ -z "$ran" ] && need_eval="$need_eval $name"
  fi
done <<< "$changed"

[ -z "$need_eval" ] && { echo '{}'; exit 0; }

# WARN (allow — no deny). Surface on stderr AND as systemMessage.
msg="EVAL GATE (aviso): agent(s) alterados com fixture e sem eval nesta sessao:${need_eval}. Rode antes de commitar: python scripts/eval/stability_runner.py --agent <name> --runs 5"
echo "[Hook] $msg" >&2
python3 -c "import json,sys; print(json.dumps({'systemMessage': sys.argv[1]}))" "$msg"
exit 0
