#!/usr/bin/env python3
"""Bridge recurring error events into rule-promotion candidates.

This is the A->B connector the learning system was missing: pipeline A
(detect-errors.sh -> error-events.jsonl -> error-index.md) recorded recurring
errors but nothing ever turned them into rule candidates. pipeline B
(rule_promoter.py) only ever read MEMORY.md. This script reads the error
stream, finds patterns that recur above a threshold across DISTINCT sessions
(approximated by distinct timestamps), and APPENDS sanitized candidates to
~/.claude/learning/rule-candidates.md for MANUAL Owner review.

It NEVER auto-promotes and NEVER writes to MEMORY.md, rules/, CLAUDE.md, or
error-index.md. Final promotion stays a human decision (memory-poisoning
defense, per PE rule Section 18).

Reuses sanitize_rule_text + MAX_RULE_LENGTH from rule_promoter.py so the
hardening logic stays single-sourced.

Usage:
    python error_to_rule_bridge.py            # append new candidates
    python error_to_rule_bridge.py --dry-run  # print, do not write
    python error_to_rule_bridge.py --list     # show qualifying patterns only
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

# --- Reuse hardening from the sibling promoter (single source of truth). -----
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from rule_promoter import sanitize_rule_text, MAX_RULE_LENGTH
except Exception:  # pragma: no cover - fallback if import path breaks
    MAX_RULE_LENGTH = 200

    def sanitize_rule_text(text):
        """Minimal fallback: only enforce length if rule_promoter is missing."""
        violations = []
        if len(text) > MAX_RULE_LENGTH:
            violations.append(f"exceeds {MAX_RULE_LENGTH} chars (len={len(text)})")
        return text, violations


# --- Config (tune here). -----------------------------------------------------
HOME = Path.home()
EVENTS_PATH = HOME / ".claude" / "logs" / "error-events.jsonl"
CANDIDATES_PATH = HOME / ".claude" / "learning" / "rule-candidates.md"

# A pattern qualifies only if it recurs across at least this many DISTINCT
# timestamps (proxy for distinct sessions). Mirrors Section 18 (3+ recurrence).
MIN_DISTINCT_OCCURRENCES = 3

# Categories that are noise, not preventable engineering errors. The error
# detector logs MCP chatter, user rejections, and write-before-read misuse;
# none of those should ever become an enforced rule.
SKIP_CATEGORIES = frozenset({
    "mcp_error",
    "user_rejection",
    "tool_misuse",
    "unknown",
})

# matched_pattern substrings that are pure noise even inside kept categories.
SKIP_PATTERN_SUBSTRINGS = (
    "rejected by user",
    "ran on page and returned",
    "screenshot of the current page",
    "reloaded the page",
)

MARKER = "error-index bridge"  # so Owner can grep candidates by origin


def load_events(path):
    """Read error-events.jsonl into a list of dicts, skipping bad lines."""
    events = []
    if not path.exists():
        return events
    try:
        with path.open(encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue  # tolerate partial/corrupt lines
    except OSError as exc:
        print(f"warn: could not read {path}: {exc}", file=sys.stderr)
    return events


def is_noise(category, pattern):
    """True if this event should not seed a rule candidate."""
    if category in SKIP_CATEGORIES:
        return True
    low = (pattern or "").lower()
    return any(sub in low for sub in SKIP_PATTERN_SUBSTRINGS)


def aggregate_patterns(events):
    """Group events by (category, matched_pattern).

    Returns a dict keyed by (category, pattern) -> {
        distinct_timestamps, total, last_seen, example_command, example_snippet
    }. Recurrence counts DISTINCT timestamps, not raw rows, so a single noisy
    session firing 50 times does not inflate the score.
    """
    groups = defaultdict(lambda: {
        "timestamps": set(),
        "total": 0,
        "last_seen": "",
        "example_command": "",
        "example_snippet": "",
    })
    for ev in events:
        category = ev.get("category", "unknown")
        pattern = ev.get("matched_pattern", "")
        if is_noise(category, pattern):
            continue
        ts = ev.get("timestamp", "")
        key = (category, pattern)
        g = groups[key]
        if ts:
            g["timestamps"].add(ts)
            if ts > g["last_seen"]:
                g["last_seen"] = ts
        g["total"] += 1
        cmd = (ev.get("command") or "").strip()
        if cmd and not g["example_command"]:
            g["example_command"] = cmd
        snip = (ev.get("error_snippet") or "").strip()
        if snip and not g["example_snippet"]:
            g["example_snippet"] = snip
    return groups


def qualified_patterns(groups):
    """Return qualifying patterns sorted by distinct-occurrence count desc."""
    out = []
    for (category, pattern), g in groups.items():
        distinct = len(g["timestamps"])
        if distinct < MIN_DISTINCT_OCCURRENCES:
            continue
        out.append({
            "category": category,
            "pattern": pattern,
            "distinct": distinct,
            "total": g["total"],
            "last_seen": g["last_seen"],
            "example_command": g["example_command"],
            "example_snippet": g["example_snippet"],
        })
    out.sort(key=lambda c: (-c["distinct"], -c["total"]))
    return out


def dedupe_key(candidate):
    """Stable key used both to dedupe in-file and to identify a pattern."""
    return f"{candidate['category']}::{candidate['pattern']}"


def build_rule_text(candidate):
    """Compose a short, sanitized rule-candidate line (<= MAX_RULE_LENGTH).

    Returns (text, violations). Defensive: error snippets come from arbitrary
    command output, so they MUST pass the shared sanitizer before being
    written anywhere.
    """
    pattern = (candidate["pattern"] or "unknown").replace("\n", " ").strip()
    category = candidate["category"]
    # Keep it factual: describe the recurring failure, prompt human framing.
    text = (
        f"Recurring [{category}] error ({candidate['distinct']}x): "
        f"\"{pattern}\". Investigate root cause and add a preventive rule."
    )
    if len(text) > MAX_RULE_LENGTH:
        budget = MAX_RULE_LENGTH - (len(text) - len(pattern)) - 3
        if budget > 0:
            pattern = pattern[:budget] + "..."
        text = (
            f"Recurring [{category}] error ({candidate['distinct']}x): "
            f"\"{pattern}\". Investigate root cause and add a preventive rule."
        )
        text = text[:MAX_RULE_LENGTH]
    return sanitize_rule_text(text)


def read_existing_keys(path):
    """Scan the candidates file for already-recorded bridge dedupe keys."""
    keys = set()
    if not path.exists():
        return keys
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            marker = "<!-- bridge-key:"
            if marker in line:
                start = line.index(marker) + len(marker)
                end = line.find("-->", start)
                if end != -1:
                    keys.add(line[start:end].strip())
    except OSError as exc:
        print(f"warn: could not read {path}: {exc}", file=sys.stderr)
    return keys


def bootstrap_header():
    """Same header rule_promoter.py uses, so the file format stays uniform."""
    return (
        "# Rule Candidates (pending CTO review)\n\n"
        "Each entry below is a sanitized, validated promotion candidate.\n"
        "The CTO promotes manually via PR after review. Auto-promotion is disabled.\n\n"
    )


def render_candidate_block(candidate, rule_text, now):
    """Render one Markdown block matching the promoter's `## DATE -- from` style."""
    key = dedupe_key(candidate)
    pattern = (candidate["pattern"] or "unknown")[:80]
    cmd = (candidate["example_command"] or "").replace("\n", " ").strip()
    if len(cmd) > 200:
        cmd = cmd[:200] + "..."
    lines = [
        f"\n## {now} -- from `{pattern}` ({MARKER}) <!-- bridge-key:{key} -->",
        rule_text,
        f"- origin: {MARKER}",
        f"- recurrence: {candidate['distinct']} distinct timestamps "
        f"({candidate['total']} total events)",
        f"- last seen: {candidate['last_seen'] or 'unknown'}",
    ]
    if cmd:
        lines.append(f"- example command: `{cmd}`")
    lines.append("")
    return "\n".join(lines)


def append_candidates(path, blocks, dry_run):
    """Append rendered blocks to the candidates file (or print if dry-run)."""
    payload = "".join(blocks)
    if dry_run:
        print("--- DRY RUN (nothing written) ---")
        print(payload, end="")
        return
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        existing = path.read_text(encoding="utf-8") if path.exists() else bootstrap_header()
        path.write_text(existing + payload, encoding="utf-8")
    except OSError as exc:
        print(f"error: could not write {path}: {exc}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Bridge recurring error events into rule-promotion candidates.",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be appended; write nothing.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List qualifying recurring patterns and exit (no writes).",
    )
    parser.add_argument(
        "--events", default=str(EVENTS_PATH),
        help=f"Path to error-events.jsonl (default: {EVENTS_PATH}).",
    )
    parser.add_argument(
        "--candidates", default=str(CANDIDATES_PATH),
        help=f"Path to rule-candidates.md (default: {CANDIDATES_PATH}).",
    )
    args = parser.parse_args()

    # Single-flight: o gatilho event-driven (detect-errors.sh) pode disparar
    # várias instâncias em paralelo. Um lock fcntl não-bloqueante garante que
    # só uma rode por vez — as demais saem sem corromper rule-candidates.md.
    # Modos read-only (--dry-run/--list) não precisam do lock.
    _lock_handle = None
    if not args.dry_run and not args.list:
        try:
            import fcntl
            lock_path = Path.home() / ".claude" / "logs" / "bridge.lock"
            lock_path.parent.mkdir(parents=True, exist_ok=True)
            _lock_handle = open(lock_path, "w")  # noqa: SIM115 — segurado pelo processo
            fcntl.flock(_lock_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (OSError, BlockingIOError):
            # outra instância já roda — sai limpo; ela cobre os eventos atuais
            sys.exit(0)

    events_path = Path(args.events)
    candidates_path = Path(args.candidates)

    try:
        events = load_events(events_path)
        groups = aggregate_patterns(events)
        qualifying = qualified_patterns(groups)
    except Exception as exc:  # never crash the caller (Stop hook / cron)
        print(f"error: aggregation failed: {exc}", file=sys.stderr)
        sys.exit(0)

    if args.list:
        if not qualifying:
            print("No recurring patterns above threshold "
                  f"({MIN_DISTINCT_OCCURRENCES} distinct).")
            sys.exit(0)
        print(f"Qualifying patterns (>= {MIN_DISTINCT_OCCURRENCES} distinct):")
        for c in qualifying:
            print(f"  {c['distinct']:3d}x [{c['category']}] "
                  f"{c['pattern'][:60]}")
        sys.exit(0)

    existing_keys = read_existing_keys(candidates_path)
    now = datetime.now().strftime("%Y-%m-%d")

    blocks = []
    skipped_dupes = 0
    skipped_unsafe = 0
    for c in qualifying:
        key = dedupe_key(c)
        if key in existing_keys:
            skipped_dupes += 1
            continue
        rule_text, violations = build_rule_text(c)
        if violations:
            skipped_unsafe += 1
            print(f"skip (sanitizer): [{c['category']}] "
                  f"{c['pattern'][:40]} -> {'; '.join(violations)}",
                  file=sys.stderr)
            continue
        blocks.append(render_candidate_block(c, rule_text, now))
        existing_keys.add(key)  # guard against intra-run dupes too

    if not blocks:
        print(f"No new candidates. (qualifying={len(qualifying)}, "
              f"dupes={skipped_dupes}, unsafe={skipped_unsafe})")
        sys.exit(0)

    append_candidates(candidates_path, blocks, args.dry_run)
    action = "would append" if args.dry_run else "appended"
    print(f"{action} {len(blocks)} candidate(s) to {candidates_path} "
          f"(skipped {skipped_dupes} dupes, {skipped_unsafe} unsafe).")
    sys.exit(0)


if __name__ == "__main__":
    main()
