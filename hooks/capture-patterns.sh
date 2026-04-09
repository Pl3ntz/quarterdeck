#!/bin/bash
# capture-patterns.sh — Continuous Learning Capture (wrapper)
#
# Hook: UserPromptSubmit
# Safety: NEVER blocks. Always exits 0. Kill switch via .disabled file.
#
# Real logic: ~/.claude/scripts/capture_patterns.py

KILL_SWITCH="$HOME/.claude/learning/.disabled"
[[ -f "$KILL_SWITCH" ]] && exit 0

SCRIPT="$HOME/.claude/scripts/capture_patterns.py"
[[ -f "$SCRIPT" ]] || exit 0

python3 "$SCRIPT" 2>/dev/null || true
exit 0
