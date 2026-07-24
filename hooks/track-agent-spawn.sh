#!/bin/bash
# Agent Observability Hook (PostToolUse on Task|Agent)
#
# Records that an agent was spawned, plus the keys needed to join the spawn to real token usage.
#
# What this hook can and cannot see: the payload exposes `tool_input.model`, which is the
# per-invocation OVERRIDE and is absent on most spawns -- that is why the old `model` field was
# "inherited" in ~89% of records and was useless for measuring cost by model. The RESOLVED model
# lives in the transcript, where every assistant record carries `message.model` + `message.usage`,
# and subagent records also carry `attributionAgent`. So this hook records the join keys
# (session_id, transcript_path) and defers model/cost to agent-usage-report.py.

input=$(cat)

# PostToolUse must echo its input through unchanged.
echo "$input"

# Log asynchronously so a slow write never blocks the tool call.
echo "$input" | python3 -c "
import sys, json, os
from datetime import datetime

try:
    data = json.load(sys.stdin)
    tool = data.get('tool_name', '') or data.get('tool', '')

    # The tool was renamed Task -> Agent in Claude Code 2.x; accept both.
    if tool not in ('Task', 'Agent'):
        sys.exit(0)

    tool_input = data.get('tool_input', {}) or {}
    tool_response = data.get('tool_response', {}) or {}

    # An agent/task identifier, when the response carries one, lets a spawn be matched to its
    # own subagent transcript file. Shape is not guaranteed, so probe defensively.
    agent_ref = ''
    if isinstance(tool_response, dict):
        for key in ('agentId', 'agent_id', 'task_id', 'taskId', 'id'):
            if tool_response.get(key):
                agent_ref = str(tool_response[key])
                break

    entry = {
        'timestamp': datetime.now().isoformat(),
        'agent_name': tool_input.get('subagent_type', 'unknown'),
        'description': tool_input.get('description', ''),
        'prompt_tokens_est': len(tool_input.get('prompt', '')) // 4,
        'background': bool(tool_input.get('run_in_background', False)),
        'isolation': tool_input.get('isolation', ''),
        # Join keys -- the resolved model and token counts come from the transcript, not here.
        'session_id': data.get('session_id', ''),
        'transcript_path': data.get('transcript_path', ''),
        'cwd': data.get('cwd', ''),
        'agent_ref': agent_ref,
        # The requested override only; empty means the spawn inherited its model.
        'model_requested': tool_input.get('model', ''),
        'schema': 2,
    }

    log_dir = os.path.expanduser('~/.claude/logs')
    os.makedirs(log_dir, exist_ok=True)
    with open(os.path.join(log_dir, 'agent-spawns.jsonl'), 'a') as f:
        f.write(json.dumps(entry) + '\n')

except Exception:
    pass
" 2>/dev/null &
