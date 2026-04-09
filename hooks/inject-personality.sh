#!/bin/bash
# inject-personality.sh — Continuous Learning Injection (wrapper)
#
# Hook: UserPromptSubmit
# Safety: NEVER blocks. Always exits 0. Kill switch via .disabled file.
#
# Real logic: ~/.claude/scripts/inject_personality.py

KILL_SWITCH="$HOME/.claude/learning/.disabled"
[[ -f "$KILL_SWITCH" ]] && exit 0

SCRIPT="$HOME/.claude/scripts/inject_personality.py"
[[ -f "$SCRIPT" ]] || exit 0

python3 "$SCRIPT" 2>/dev/null || true
exit 0
