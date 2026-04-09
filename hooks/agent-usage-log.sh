#!/bin/bash
# agent-usage-log.sh — Agent Observability Layer (wrapper)
#
# Hook: PostToolUse (matcher: Task)
# Safety: NEVER blocks. Always exits 0. Kill switch via .disabled file.
#
# Real logic: ~/.claude/scripts/agent_usage_log.py

KILL_SWITCH="$HOME/.claude/learning/.disabled"
[[ -f "$KILL_SWITCH" ]] && exit 0

SCRIPT="$HOME/.claude/scripts/agent_usage_log.py"
[[ -f "$SCRIPT" ]] || exit 0

python3 "$SCRIPT" 2>/dev/null || true
exit 0
