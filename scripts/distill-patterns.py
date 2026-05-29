#!/usr/bin/env python3
"""
distill-patterns.py — Continuous Learning Distillation Layer

Reads patterns.jsonl, applies confidence threshold (3+ occurrences) and
decay (30 days), and regenerates profile.md with the distilled patterns.

Usage:
    distill-patterns.py [--scope global|project|all] [--dry-run]
    distill-patterns.py --confidence 5 --decay 60

Default behavior:
    - Scope: all (both global and per-project)
    - Confidence threshold: 3 occurrences
    - Decay: 30 days
    - Updates profile.md in-place (preserves manual edits in unmanaged sections)
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Default config
# Hard minimum: 3 occurrences to promote a pattern.
# Memory poisoning defense (CRITICAL): a single poisoned entry must NEVER
# be enough to become a global injected rule. Lower thresholds are rejected.
MIN_CONFIDENCE = 3
DEFAULT_CONFIDENCE = 3
DEFAULT_DECAY_DAYS = 30
GLOBAL_LEARNING_DIR = Path.home() / ".claude" / "learning"
PROJECT_LEARNING_DIRS = [
    Path.home() / ".claude" / "projects" / "-Users-user-dev" / "learning",
]


def parse_args():
    p = argparse.ArgumentParser(description="Distill patterns into profile.md")
    p.add_argument("--scope", choices=["global", "project", "all"], default="all")
    p.add_argument("--confidence", type=int, default=DEFAULT_CONFIDENCE)
    p.add_argument("--decay", type=int, default=DEFAULT_DECAY_DAYS)
    p.add_argument("--dry-run", action="store_true", help="Show what would change without writing")
    args = p.parse_args()
    # Memory poisoning defense: enforce hard minimum confidence.
    if args.confidence < MIN_CONFIDENCE:
        print(
            f"ERROR: --confidence must be >= {MIN_CONFIDENCE} (memory poisoning defense). "
            f"Got: {args.confidence}",
            file=sys.stderr,
        )
        sys.exit(2)
    return args


# Memory poisoning defense (distill side):
# Markers that indicate a captured "prompt" is actually tool output, a subagent
# response, an injected context preamble, or pasted markup — NOT a genuine user
# preference. Kept in sync with capture_patterns.py. A line whose prompt trips
# any of these is quarantined granularly (the bad line is isolated; clean lines
# are preserved). This replaces the old destructive behavior that renamed the
# WHOLE file to patterns.jsonl.poisoned-* and wiped all learning.
POISON_SUBSTRINGS = (
    "<task-notification",
    "<system-reminder",
    "</system-reminder",
    "<command-name",
    "<command-message",
    "<command-args",
    "<tool-use-id",
    "<tool_use",
    "<tool_result",
    "<user-prompt-submit-hook",
    "<local-command-",
    "<function_calls",
    "<function_results",
    "<invoke",
    "<parameter",
    "antml:",
    "---context---",
    "---end-context---",
    "---agent-memory---",
    "co-authored-by:",
    "generated with [claude",
    "🤖 generated",
    "tool_result",
    "tool_use_id",
    "[system-reminder]",
)


def is_poisoned_prompt(prompt: str) -> bool:
    """True if a captured prompt looks like non-user content (poison)."""
    if not isinstance(prompt, str) or not prompt.strip():
        return False
    if prompt.lstrip().startswith("<"):
        return True
    low = prompt.lower()
    if any(m in low for m in POISON_SUBSTRINGS):
        return True
    if prompt.count("```") >= 2:
        return True
    return False


def load_patterns(jsonl_path: Path) -> list[dict]:
    """Load patterns from jsonl, quarantining poisoned/malformed lines.

    Granular quarantine (memory poisoning defense): malformed lines and valid
    entries whose prompt is non-user content are appended to a quarantine file
    and dropped from patterns.jsonl. Clean entries are always preserved — a
    single bad line never destroys the rest of the learning corpus.

    Idempotent and fail-safe: any IO/parse error leaves patterns.jsonl
    untouched and returns whatever clean entries were parsed.
    """
    if not jsonl_path.exists():
        return []

    clean: list[dict] = []
    clean_lines: list[str] = []
    quarantined: list[str] = []

    try:
        with jsonl_path.open(encoding="utf-8") as f:
            raw_lines = f.readlines()
    except Exception as e:
        print(f"  [warn] could not read {jsonl_path}: {type(e).__name__}", file=sys.stderr)
        return []

    for raw in raw_lines:
        stripped = raw.strip()
        if not stripped:
            continue
        try:
            entry = json.loads(stripped)
        except json.JSONDecodeError:
            quarantined.append(stripped)  # malformed JSON
            continue
        if not isinstance(entry, dict) or is_poisoned_prompt(entry.get("prompt", "")):
            quarantined.append(stripped)  # valid JSON but non-user content
            continue
        clean.append(entry)
        clean_lines.append(stripped)

    # Nothing poisoned → leave the file untouched (idempotent fast path).
    if not quarantined:
        return clean

    try:
        quarantine_file = jsonl_path.with_suffix(jsonl_path.suffix + ".quarantine")
        with quarantine_file.open("a", encoding="utf-8") as qf:
            for bad in quarantined:
                qf.write(bad + "\n")
        # Atomic-ish rewrite of the clean corpus.
        tmp_file = jsonl_path.with_suffix(jsonl_path.suffix + ".tmp")
        with tmp_file.open("w", encoding="utf-8") as cf:
            for good in clean_lines:
                cf.write(good + "\n")
        os.replace(tmp_file, jsonl_path)
        print(
            f"  [quarantine] isolated {len(quarantined)} poisoned line(s) → "
            f"{quarantine_file.name}; kept {len(clean)} clean entries"
        )
    except Exception as e:
        # On any failure, do NOT corrupt the source — just proceed with the
        # clean entries we already parsed in memory.
        print(
            f"  [warn] quarantine write failed ({type(e).__name__}); "
            f"patterns.jsonl left intact",
            file=sys.stderr,
        )

    return clean


def apply_decay(patterns: list[dict], decay_days: int) -> list[dict]:
    """Filter out patterns older than decay_days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=decay_days)
    fresh = []
    for p in patterns:
        try:
            ts = datetime.fromisoformat(p["timestamp"].replace("Z", "+00:00"))
            if ts >= cutoff:
                fresh.append(p)
        except (KeyError, ValueError):
            continue
    return fresh


def normalize_prompt(prompt: str) -> str:
    """Reduce prompt to a comparable signature."""
    prompt = prompt.lower().strip()
    # Remove punctuation
    prompt = re.sub(r'[^\w\sáéíóúâêîôûãõç]', ' ', prompt)
    # Collapse whitespace
    prompt = re.sub(r'\s+', ' ', prompt)
    return prompt[:100]


def cluster_by_signal(patterns: list[dict]) -> dict[str, list[dict]]:
    """Group patterns by signal type."""
    clusters = defaultdict(list)
    for p in patterns:
        signal = p.get("signal", "unknown")
        clusters[signal].append(p)
    return clusters


def find_recurring(patterns: list[dict], confidence: int) -> list[dict]:
    """Find patterns that appear >= confidence times (similar prompts)."""
    by_signature = defaultdict(list)
    for p in patterns:
        sig = normalize_prompt(p.get("prompt", ""))
        if len(sig) > 5:  # Skip very short prompts
            by_signature[sig].append(p)

    recurring = []
    for sig, occurrences in by_signature.items():
        if len(occurrences) >= confidence:
            # Take the most recent occurrence as representative
            latest = max(occurrences, key=lambda x: x.get("timestamp", ""))
            latest["_count"] = len(occurrences)
            recurring.append(latest)
    return sorted(recurring, key=lambda x: x.get("_count", 0), reverse=True)


def render_profile(
    existing: str,
    distilled: dict[str, list[dict]],
    metadata: dict,
) -> str:
    """Regenerate profile.md preserving structure."""
    lines = [
        "# Personality Profile (Global)",
        "",
        "> Auto-generated by the continuous learning system.",
        "> Edit manually only if you know what you're doing — changes will be preserved.",
        "> Reset via `/personality reset` or delete this file.",
        "",
    ]

    # Communication section (preserve manual seed if present)
    lines.append("## Communication")
    lines.append("")
    if existing and "## Communication" in existing:
        # Preserve existing communication block (manual seed)
        comm_match = re.search(
            r"## Communication\n\n?(.*?)(?=\n## |\Z)",
            existing,
            re.DOTALL,
        )
        if comm_match:
            lines.append(comm_match.group(1).strip())
    else:
        lines.append("- **Idioma**: pt-BR (sempre, exceto termos técnicos)")
        lines.append("- **Tom**: direto, sem preâmbulo, sem filler")
    lines.append("")

    # Workflow section
    lines.append("## Workflow")
    lines.append("")
    if existing and "## Workflow" in existing:
        wf_match = re.search(
            r"## Workflow\n\n?(.*?)(?=\n## |\Z)",
            existing,
            re.DOTALL,
        )
        if wf_match:
            lines.append(wf_match.group(1).strip())
    lines.append("")

    # Anti-padrões: combine manual + auto-distilled
    lines.append("## Anti-padrões (NUNCA)")
    lines.append("")
    manual_anti = []
    if existing and "## Anti-padrões" in existing:
        anti_match = re.search(
            r"## Anti-padrões.*?\n\n?(.*?)(?=\n## |\Z)",
            existing,
            re.DOTALL,
        )
        if anti_match:
            # Only preserve manual seed lines (starting with "- ").
            # Strip auto-distilled residuals (lines with "_(Nx)_" markers and
            # "**Aprendidos automaticamente:**" headers) to prevent stale
            # patterns from persisting across distill runs.
            manual_anti = [
                line for line in anti_match.group(1).split("\n")
                if line.strip().startswith("-")
                and "_(" not in line
                and "x)_" not in line
            ]
    for line in manual_anti:
        lines.append(line)

    auto_anti = distilled.get("anti_pattern", [])
    if auto_anti:
        lines.append("")
        lines.append("**Aprendidos automaticamente:**")
        for p in auto_anti[:10]:
            count = p.get("_count", 1)
            prompt = p.get("prompt", "").strip()[:120]
            lines.append(f"- _({count}x)_ {prompt}")
    lines.append("")

    # Preferências (auto-learned)
    lines.append("## Preferências Técnicas")
    lines.append("")
    prefs = distilled.get("preference", []) + distilled.get("memory", [])
    if prefs:
        for p in prefs[:10]:
            count = p.get("_count", 1)
            prompt = p.get("prompt", "").strip()[:120]
            lines.append(f"- _({count}x)_ {prompt}")
    else:
        lines.append("_Sem padrões aprendidos ainda. Use o sistema normalmente — ele aprende sozinho._")
    lines.append("")

    # Style adjustments
    lines.append("## Estilo")
    lines.append("")
    styles = distilled.get("style", [])
    if styles:
        for p in styles[:5]:
            count = p.get("_count", 1)
            prompt = p.get("prompt", "").strip()[:120]
            lines.append(f"- _({count}x)_ {prompt}")
    else:
        lines.append("_Nenhum padrão de estilo aprendido ainda._")
    lines.append("")

    # Metadata
    lines.append("---")
    lines.append("")
    lines.append("## Metadata")
    lines.append("")
    lines.append(f"- **Last distilled**: {metadata['timestamp']}")
    lines.append(f"- **Pattern count (raw)**: {metadata['raw_count']}")
    lines.append(f"- **Pattern count (after decay)**: {metadata['fresh_count']}")
    lines.append(f"- **Distilled rules**: {metadata['distilled_count']}")
    lines.append(f"- **Confidence threshold**: {metadata['confidence']}+ occurrences")
    lines.append(f"- **Decay**: {metadata['decay_days']} days")

    return "\n".join(lines) + "\n"


def distill_directory(learning_dir: Path, confidence: int, decay_days: int, dry_run: bool):
    """Distill patterns for a single learning directory."""
    patterns_file = learning_dir / "patterns.jsonl"
    profile_file = learning_dir / "profile.md"

    if not patterns_file.exists():
        print(f"[skip] {patterns_file} does not exist")
        return

    raw_patterns = load_patterns(patterns_file)
    fresh_patterns = apply_decay(raw_patterns, decay_days)

    print(f"\n[scope: {learning_dir}]")
    print(f"  Raw patterns:    {len(raw_patterns)}")
    print(f"  After decay:     {len(fresh_patterns)} (within {decay_days} days)")

    if not fresh_patterns:
        print(f"  Nothing to distill.")
        return

    by_signal = cluster_by_signal(fresh_patterns)

    distilled = {}
    total_distilled = 0
    for signal, group in by_signal.items():
        recurring = find_recurring(group, confidence)
        if recurring:
            distilled[signal] = recurring
            total_distilled += len(recurring)
            print(f"  {signal}: {len(recurring)} recurring patterns")

    # Read existing profile to preserve manual sections
    existing = ""
    if profile_file.exists():
        existing = profile_file.read_text(encoding="utf-8")

    metadata = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "raw_count": len(raw_patterns),
        "fresh_count": len(fresh_patterns),
        "distilled_count": total_distilled,
        "confidence": confidence,
        "decay_days": decay_days,
    }

    new_profile = render_profile(existing, distilled, metadata)

    if dry_run:
        print(f"\n  [dry-run] Would write {len(new_profile)} chars to {profile_file}")
        return

    profile_file.write_text(new_profile, encoding="utf-8")
    print(f"  ✓ Updated {profile_file}")


def main():
    args = parse_args()

    targets = []
    if args.scope in ("global", "all"):
        targets.append(GLOBAL_LEARNING_DIR)
    if args.scope in ("project", "all"):
        targets.extend(PROJECT_LEARNING_DIRS)

    for target in targets:
        if target.exists():
            distill_directory(target, args.confidence, args.decay, args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()
