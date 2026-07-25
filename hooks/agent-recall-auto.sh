#!/bin/bash
# Agent Recall Auto — PreToolUse Hook on Task (Agent spawn)
# Automatically queries agent-recall before spawning any agent
# Injects past findings as systemMessage so PE includes in context
#
# I/O Contract (PreToolUse):
# - Input: JSON via stdin (tool_name, tool_input)
# - Output: JSON with systemMessage containing past findings
# - Exit 0 always

input=$(cat)

# Extract agent name from Task tool input
agent_info=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tool_input = d.get('tool_input', {})
    agent = tool_input.get('subagent_type', '')
    if not agent:
        # Try to extract from prompt/description
        desc = tool_input.get('description', '')
        agent = desc.split()[0] if desc else ''
    print(agent)
except:
    print('')
" 2>/dev/null)

if [ -z "$agent_info" ]; then
  echo '{}'
  exit 0
fi

# Query agent-recall for past findings
# Use the built plugin script if available, otherwise raw node
# Configure this path to your local-mind plugin installation
RECALL_SCRIPT="${LOCAL_MIND_PATH:-$HOME/.claude/plugins/cache/local-memory-plugins/local-mind/0.1.0}/scripts/agent-recall.cjs"

if [ ! -f "$RECALL_SCRIPT" ]; then
  echo '{}'
  exit 0
fi

recall_output=$(node "$RECALL_SCRIPT" "$agent_info" 2>/dev/null)

if [ -z "$recall_output" ] || echo "$recall_output" | grep -q "Nenhum achado"; then
  echo '{}'
  exit 0
fi

# Inject findings as systemMessage
python3 -c "
import json, sys
findings = sys.stdin.read().strip()
if findings:
    msg = '---agent-memory---\n' + findings + '\n---end-agent-memory---\nInclua este contexto historico no prompt do agente.'
    print(json.dumps({'systemMessage': msg}))
else:
    print('{}')
" <<< "$recall_output" 2>/dev/null

exit 0
