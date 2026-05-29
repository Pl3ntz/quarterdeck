#!/bin/bash
# capture-patterns.sh — Continuous Learning Capture (wrapper)
#
# Hook: UserPromptSubmit
# Safety: NEVER blocks. Always exits 0. Kill switch via .disabled file.
#
# Input contract: Claude Code delivers the UserPromptSubmit payload as JSON on
# stdin. Only the `.prompt` field (the user's typed turn) is the genuine user
# text — it does NOT include the transcript, tool results, or subagent output.
# We pass stdin verbatim; capture_patterns.py reads ONLY data["prompt"] and
# applies the poisoning defenses (it never reads transcript/tool fields).
#
# Real logic: ~/.claude/scripts/capture_patterns.py

KILL_SWITCH="$HOME/.claude/learning/.disabled"
[[ -f "$KILL_SWITCH" ]] && exit 0

SCRIPT="$HOME/.claude/scripts/capture_patterns.py"
[[ -f "$SCRIPT" ]] || exit 0

python3 "$SCRIPT" 2>/dev/null || true
exit 0
