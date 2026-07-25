#!/usr/bin/env python3
"""
agent-usage-report — cost and volume measurement per (agent, model) for the quarterdeck squad.

Why this exists: `track-agent-spawn.sh` records THAT an agent ran, but its `model` field is
`"inherited"` in ~89% of records because it reads the per-invocation override, which is usually
absent. The real data was already on disk and unread: every assistant record in a session
transcript carries `message.model` + `message.usage`, and subagent records additionally carry
`attributionAgent` (the agent name). This script does the join.

Two modes:

  --session PATH   Incremental. Reads only the bytes appended since the last run (byte-offset
                   cursor per file) and appends per-(agent, model) deltas to the rollup.
                   Cheap enough to run from the Stop hook. Idempotent.

  --report         Reads the rollup and prints the aggregate. `--full` rescans every transcript
                   from scratch instead (slow: ~1.6 GB) and rebuilds the rollup.

Cost is computed at Anthropic list price and is a NOTIONAL API-equivalent figure -- it is not a
subscription bill. It exists to compare model choices against each other, not to reconcile
invoices.

Stdlib only.
"""
import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta

CLAUDE_DIR = os.path.expanduser("~/.claude")
PROJECTS_DIR = os.path.join(CLAUDE_DIR, "projects")
ROLLUP = os.path.join(CLAUDE_DIR, "logs", "agent-usage.jsonl")
CURSORS = os.path.join(CLAUDE_DIR, "logs", ".usage-cursors.json")

MAIN_SESSION = "«main-session»"

# $/MTok (input, output) at list price. Source: platform.claude.com/docs/en/about-claude/models/overview
PRICES = {
    "claude-fable-5": (10.0, 50.0),
    "claude-mythos-5": (10.0, 50.0),
    "claude-opus-5": (5.0, 25.0),
    "claude-opus-4-8": (5.0, 25.0),
    "claude-opus-4-7": (5.0, 25.0),
    "claude-opus-4-6": (5.0, 25.0),
    "claude-opus-4-5": (5.0, 25.0),
    "claude-sonnet-5": (3.0, 15.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-sonnet-4-5": (3.0, 15.0),
    "claude-haiku-4-5": (1.0, 5.0),
}
# Sonnet 5 introductory pricing applies through this date (docs footnote 4).
SONNET5_INTRO = (2.0, 10.0)
SONNET5_INTRO_UNTIL = "2026-08-31"

# Cache multipliers relative to the base input price.
CACHE_READ_MULT = 0.1
CACHE_WRITE_5M_MULT = 1.25
CACHE_WRITE_1H_MULT = 2.0


def price_for(model, day):
    """Return (input, output) $/MTok for a model on a given YYYY-MM-DD, or None if unknown."""
    if model.startswith("claude-sonnet-5") and day and day <= SONNET5_INTRO_UNTIL:
        return SONNET5_INTRO
    for prefix, pair in PRICES.items():
        if model.startswith(prefix):
            return pair
    return None


def cost_of(rec):
    """Notional USD for one aggregated bucket."""
    pair = price_for(rec["model"], rec.get("day"))
    if not pair:
        return 0.0
    pin, pout = pair
    return (
        rec["input"] * pin
        + rec["output"] * pout
        + rec["cache_read"] * pin * CACHE_READ_MULT
        + rec["cache_write_5m"] * pin * CACHE_WRITE_5M_MULT
        + rec["cache_write_1h"] * pin * CACHE_WRITE_1H_MULT
    ) / 1_000_000


def load_cursors():
    try:
        with open(CURSORS) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save_cursors(cursors):
    tmp = CURSORS + ".tmp"
    try:
        os.makedirs(os.path.dirname(CURSORS), exist_ok=True)
        with open(tmp, "w") as fh:
            json.dump(cursors, fh)
        os.replace(tmp, CURSORS)
    except OSError as exc:
        print(f"agent-usage-report: could not persist cursors: {exc}", file=sys.stderr)


def scan_file(path, start_offset=0):
    """Yield (agent, model, day, usage_dict) for every usage-bearing record after start_offset.

    Returns the new byte offset alongside, so the caller can persist a cursor. Transcripts are
    append-only, which is what makes the offset safe to reuse.
    """
    buckets = defaultdict(lambda: {
        "input": 0, "output": 0, "cache_read": 0,
        "cache_write_5m": 0, "cache_write_1h": 0, "requests": 0,
    })
    offset = start_offset
    try:
        size = os.path.getsize(path)
        if size < start_offset:
            # File shrank or was rotated -- the cursor is stale, so start over.
            offset = 0
        with open(path, "r", errors="ignore") as fh:
            fh.seek(offset)
            for line in fh:
                offset += len(line.encode("utf-8", errors="ignore"))
                if '"usage"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                msg = rec.get("message")
                if not isinstance(msg, dict):
                    continue
                usage, model = msg.get("usage"), msg.get("model")
                if not usage or not model:
                    continue
                agent = rec.get("attributionAgent") or MAIN_SESSION
                day = (rec.get("timestamp") or "")[:10]
                cc = usage.get("cache_creation") or {}
                key = (agent, model, day)
                b = buckets[key]
                b["requests"] += 1
                b["input"] += usage.get("input_tokens", 0) or 0
                b["output"] += usage.get("output_tokens", 0) or 0
                b["cache_read"] += usage.get("cache_read_input_tokens", 0) or 0
                b["cache_write_5m"] += cc.get("ephemeral_5m_input_tokens", 0) or 0
                b["cache_write_1h"] += cc.get("ephemeral_1h_input_tokens", 0) or 0
    except OSError as exc:
        print(f"agent-usage-report: cannot read {path}: {exc}", file=sys.stderr)
        return {}, start_offset
    return buckets, offset


def append_rollup(buckets):
    if not buckets:
        return 0
    try:
        os.makedirs(os.path.dirname(ROLLUP), exist_ok=True)
        with open(ROLLUP, "a") as fh:
            for (agent, model, day), b in buckets.items():
                fh.write(json.dumps({"agent": agent, "model": model, "day": day, **b}) + "\n")
    except OSError as exc:
        print(f"agent-usage-report: cannot write rollup: {exc}", file=sys.stderr)
        return 0
    return len(buckets)


def cmd_session(path):
    """Incremental pass over one transcript. Safe to call repeatedly."""
    if not path or not os.path.exists(path):
        return 0
    cursors = load_cursors()
    buckets, new_offset = scan_file(path, cursors.get(path, 0))
    written = append_rollup(buckets)
    cursors[path] = new_offset
    save_cursors(cursors)
    return written


def cmd_full_rescan():
    """Rebuild the rollup from every transcript on disk. Slow by design; use sparingly."""
    if os.path.exists(ROLLUP):
        os.replace(ROLLUP, ROLLUP + ".bak")
    cursors, total = {}, 0
    for root, _dirs, files in os.walk(PROJECTS_DIR):
        for name in files:
            if not name.endswith(".jsonl"):
                continue
            path = os.path.join(root, name)
            buckets, offset = scan_file(path, 0)
            total += append_rollup(buckets)
            cursors[path] = offset
    save_cursors(cursors)
    return total


def read_rollup(days):
    cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    agg = defaultdict(lambda: {
        "input": 0, "output": 0, "cache_read": 0,
        "cache_write_5m": 0, "cache_write_1h": 0, "requests": 0,
    })
    try:
        with open(ROLLUP) as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                if r.get("day", "") < cutoff:
                    continue
                b = agg[(r["agent"], r["model"])]
                for k in ("input", "output", "cache_read", "cache_write_5m", "cache_write_1h", "requests"):
                    b[k] += r.get(k, 0)
    except OSError:
        return {}
    return agg


def cmd_report(days, as_json, include_main):
    agg = read_rollup(days)
    if not agg:
        print(f"No rollup data. Build it first:\n  {sys.argv[0]} --full-rescan", file=sys.stderr)
        return 1

    rows = []
    for (agent, model), b in agg.items():
        if not include_main and agent == MAIN_SESSION:
            continue
        rec = {"model": model, "day": None, **b}
        rows.append({
            "agent": agent, "model": model, "requests": b["requests"],
            "output_tokens": b["output"],
            "cache_read_tokens": b["cache_read"],
            "usd_notional": round(cost_of(rec), 2),
        })
    rows.sort(key=lambda r: -r["usd_notional"])

    if as_json:
        print(json.dumps({"days": days, "rows": rows}, indent=1))
        return 0

    total = sum(r["usd_notional"] for r in rows)
    print(f"\nAgent usage -- last {days} days (notional USD at list price, not a bill)\n")
    print(f"{'agent':<24}{'model':<26}{'req':>8}{'out MTok':>11}{'~USD':>10}{'share':>8}")
    print("-" * 87)
    for r in rows:
        share = (100 * r["usd_notional"] / total) if total else 0
        print(f"{r['agent']:<24}{r['model']:<26}{r['requests']:>8}"
              f"{r['output_tokens'] / 1e6:>11.2f}{r['usd_notional']:>10.2f}{share:>7.1f}%")
    print("-" * 87)
    print(f"{'TOTAL':<58}{total:>10.2f}\n")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--session", metavar="PATH", help="incremental scan of one transcript (Stop hook)")
    g.add_argument("--report", action="store_true", help="print the aggregate from the rollup")
    g.add_argument("--full-rescan", action="store_true", help="rebuild the rollup from all transcripts")
    ap.add_argument("--days", type=int, default=30, help="report window (default 30)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    ap.add_argument("--include-main", action="store_true", help="include main-session (non-agent) usage")
    args = ap.parse_args()

    if args.session:
        cmd_session(args.session)
        return 0
    if args.full_rescan:
        n = cmd_full_rescan()
        print(f"rollup rebuilt: {n} buckets -> {ROLLUP}")
        return 0
    return cmd_report(args.days, args.json, args.include_main)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
