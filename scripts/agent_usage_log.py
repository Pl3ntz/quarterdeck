#!/usr/bin/env python3
"""
agent_usage_log.py — Agent Observability Layer

Hook: PostToolUse (matcher: Task)
Purpose: Log every agent invocation to ~/.claude/learning/agent-usage.jsonl
         for later analysis via /agent-stats skill.

Captures:
- Timestamp
- Agent type (subagent_type)
- Session ID
- Cwd
- Description
- Duration (if available in tool_result)
- Token usage (if available)

Enables detection of:
- Dead code agents (never invoked)
- Co-invocation patterns (which agents run together)
- Cost hotspots (high token agents invoked too often)
- Squad utilization (are all 8 squads being used?)

Safety: NEVER blocks. Always exits 0. Kill switch: touch ~/.claude/learning/.disabled
"""

import sys
import json
import os
import signal
from datetime import datetime, timezone
from pathlib import Path

LEARNING_BASE = Path.home() / ".claude" / "learning"
LOG_FILE = LEARNING_BASE / "agent-usage.jsonl"
ERROR_LOG = LEARNING_BASE / "errors.log"
KILL_SWITCH = LEARNING_BASE / ".disabled"


def log_error(msg: str) -> None:
    try:
        LEARNING_BASE.mkdir(parents=True, exist_ok=True)
        with ERROR_LOG.open("a") as f:
            ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            f.write(f"[{ts}] agent_usage: {msg}\n")
    except Exception:
        pass


def timeout_handler(signum, frame):
    log_error("timeout 2s")
    sys.exit(0)


try:
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(2)
except (AttributeError, ValueError):
    pass


def main() -> int:
    if KILL_SWITCH.exists():
        return 0

    try:
        raw = sys.stdin.read()
    except Exception as e:
        log_error(f"stdin: {type(e).__name__}")
        return 0

    if not raw.strip():
        return 0

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        log_error(f"json: {e}")
        return 0
    except Exception as e:
        log_error(f"parse: {type(e).__name__}")
        return 0

    if not isinstance(data, dict):
        return 0

    tool_name = data.get("tool_name", "")
    if tool_name != "Task":
        return 0

    tool_input = data.get("tool_input", {}) or {}
    tool_result = data.get("tool_result", {}) or {}
    session_id = data.get("session_id", "") or ""
    cwd = data.get("cwd", "") or ""

    # Extract agent metadata
    subagent_type = tool_input.get("subagent_type", "general-purpose")
    description = (tool_input.get("description", "") or "")[:200]

    # Try to extract duration/tokens from tool_result
    duration_ms = None
    total_tokens = None
    tool_uses = None

    if isinstance(tool_result, dict):
        usage = tool_result.get("usage", {})
        if isinstance(usage, dict):
            total_tokens = usage.get("total_tokens")
            tool_uses = usage.get("tool_uses")
            duration_ms = usage.get("duration_ms")

    entry = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "agent": subagent_type,
        "description": description,
        "session_id": session_id,
        "cwd": cwd,
        "duration_ms": duration_ms,
        "total_tokens": total_tokens,
        "tool_uses": tool_uses,
    }

    try:
        LEARNING_BASE.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as e:
        log_error(f"write: {type(e).__name__}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:
        log_error(f"unexpected: {type(e).__name__}: {e}")
        sys.exit(0)
