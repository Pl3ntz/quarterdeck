#!/bin/bash
# Log Rotation Hook (Stop) — keeps the learning/log JSONL files bounded.
# error-events.jsonl grows unbounded (every Bash error appends); left alone it
# reached 6.1M / 9k lines. Recurrence detection only needs a recent window, so
# we cap by line count. Async, non-blocking, passthrough — never fails the Stop.
#
# I/O Contract (Stop): echo input back (passthrough), do work in background.

input=$(cat)
echo "$input"

(
  LOG_DIR="$HOME/.claude/logs"
  # file:max_lines pairs
  for spec in \
    "error-events.jsonl:3000" \
    "error-resolutions.jsonl:2000" \
    "command-history.jsonl:3000" \
    "agent-spawns.jsonl:2000"; do
    f="$LOG_DIR/${spec%%:*}"
    max="${spec##*:}"
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    if [ "$lines" -gt "$max" ]; then
      tail -n "$max" "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f" 2>/dev/null
    fi
  done
) >/dev/null 2>&1 &

exit 0
