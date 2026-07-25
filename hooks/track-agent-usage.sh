#!/bin/bash
# Agent Usage Rollup Hook (Stop) — incremental cost/token measurement per (agent, model).
#
# Reads only the bytes appended to this session's transcript since the last run (byte-offset
# cursor), aggregates usage by attributionAgent + model, and appends to ~/.claude/logs/agent-usage.jsonl.
# A full rescan of ~/.claude/projects is ~1.6 GB and must never run on Stop; this pass is bounded
# by one session's growth.
#
# I/O Contract (Stop): echo input back (passthrough), do work in background, never fail the Stop.

input=$(cat)
echo "$input"

(
  transcript_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0
  python3 "$HOME/.claude/scripts/agent-usage-report.py" --session "$transcript_path" >/dev/null 2>&1
) &

exit 0
