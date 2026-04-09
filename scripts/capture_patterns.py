#!/usr/bin/env python3
"""
capture_patterns.py — Continuous Learning Capture Layer

Reads JSON from stdin (Claude Code UserPromptSubmit hook input) and detects
explicit corrections, preferences, anti-patterns. Appends matches to
patterns.jsonl for distillation.

Safety: NEVER blocks the user. Always exits 0. All errors logged silently.
"""

import sys
import json
import os
import re
import signal
from datetime import datetime, timezone
from pathlib import Path

LEARNING_BASE = Path.home() / ".claude" / "learning"
ERROR_LOG = LEARNING_BASE / "errors.log"


def log_error(msg: str) -> None:
    try:
        LEARNING_BASE.mkdir(parents=True, exist_ok=True)
        with ERROR_LOG.open("a") as f:
            ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            f.write(f"[{ts}] capture: {msg}\n")
    except Exception:
        pass  # Never fail on logging


def timeout_handler(signum, frame):
    log_error("timeout 2s")
    sys.exit(0)


# Internal timeout (works on Unix only — macOS, Linux)
try:
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(2)
except (AttributeError, ValueError):
    pass  # Windows fallback — skip timeout


def detect_signal(prompt_lower: str) -> str | None:
    """Returns signal type or None."""
    if re.search(
        r'\b(nunca|never|stop|para de|pare de|n[aã]o (faça|crie|use|fique|adicione))\b',
        prompt_lower,
    ):
        return "anti_pattern"
    if re.search(
        r'\b(prefiro|prefer[oae]?|sempre use?|always use|gosto de|i like|quero que (sempre|toda vez))\b',
        prompt_lower,
    ):
        return "preference"
    if re.search(
        r'\b(n[aã]o (era|foi|é) (isso|assim)|errado|incorreto|wrong|incorrect|n[aã]o gostei|isso n[aã]o|that.s not)\b',
        prompt_lower,
    ):
        return "correction"
    if re.search(
        r'\b(lembre|lembra|remember|n[aã]o esque[çc]a|don.t forget|grave isso|save this)\b',
        prompt_lower,
    ):
        return "memory"
    if re.search(
        r'\b(seja (mais|menos)|be (more|less)|mais (curto|conciso|direto|detalhado)|shorter|longer|brief|concise)\b',
        prompt_lower,
    ):
        return "style"
    return None


def main() -> int:
    try:
        raw = sys.stdin.read()
    except Exception as e:
        log_error(f"stdin read: {type(e).__name__}")
        return 0

    if not raw.strip():
        return 0

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        log_error(f"json decode: {e}")
        return 0
    except Exception as e:
        log_error(f"parse: {type(e).__name__}")
        return 0

    if not isinstance(data, dict):
        return 0

    prompt = data.get("prompt", "") or ""
    session_id = data.get("session_id", "") or ""
    cwd = data.get("cwd", "") or ""

    if not prompt or prompt.startswith("/"):
        return 0

    # Memory poisoning defense (CRITICAL):
    # Reject any prompt containing system-level XML tags or that starts with
    # "<" (likely tool output, task notification, or hook injection — not
    # user input). Without this, subagent outputs and injected content get
    # captured as "user preferences" and persist via inject_personality.
    stripped = prompt.lstrip()
    if stripped.startswith("<"):
        log_error("rejected: starts with XML tag")
        return 0
    poison_markers = (
        "<task-notification",
        "<system-reminder",
        "<command-name",
        "<command-message",
        "<tool-use-id",
        "<user-prompt-submit-hook",
        "<local-command-",
        "<function_calls",
        "<",
    )
    prompt_lower_quick = prompt.lower()
    for marker in poison_markers:
        if marker in prompt_lower_quick:
            log_error(f"rejected: contains marker {marker!r}")
            return 0

    prompt_lower = prompt.lower()
    signal_type = detect_signal(prompt_lower)

    if not signal_type:
        return 0

    # Determine scope
    scope = "global"
    target_dir = LEARNING_BASE
    project_learning = (
        Path.home() / ".claude" / "projects" / ("-" + str(Path.cwd()).replace("/", "-").lstrip("-")) / "learning"
    )
    if cwd and project_learning.exists():
        if signal_type in ("anti_pattern", "preference") and re.search(
            r'\b(stack|framework|library|database|deploy|test|build|linter|formatter)\b',
            prompt_lower,
        ):
            target_dir = project_learning
            scope = "project"

    try:
        target_dir.mkdir(parents=True, exist_ok=True)
        patterns_file = target_dir / "patterns.jsonl"
        entry = {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "signal": signal_type,
            "scope": scope,
            "session_id": session_id,
            "cwd": cwd,
            "prompt": prompt[:500],
        }
        with patterns_file.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as e:
        log_error(f"write: {type(e).__name__}: {e}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:
        log_error(f"unexpected: {type(e).__name__}: {e}")
        sys.exit(0)
