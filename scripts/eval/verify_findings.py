#!/usr/bin/env python3
"""
verify_findings.py — adversarial finding verifier (Peça B)

A Quality-Gate agent (code/security/ux reviewer) emits findings; some are false
positives. This runs an INDEPENDENT skeptical pass per finding: given the real
file and one claimed issue, a judge tries to REFUTE it and keeps only what
genuinely holds. The point is to cut false positives before findings reach a
human — the adversarial-verify pattern.

Like the stability harness, it shells out to the `claude` CLI (headless), so it
runs on the Claude Code subscription — no API key, no per-call billing.

Two modes:
  - VERIFY: given --file and --claims (jsonl of {id,text}), print keep/refute per claim.
  - TEST:   if claims carry a "label" (real|fake), also score the verifier —
            does it KEEP the real ones and REFUTE the fake ones? This is the
            regression check for the verifier itself.

Usage:
    python scripts/eval/verify_findings.py --file tests/_verify/target.py \
        --claims tests/_verify/claims.jsonl --runs 1
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

QD_ROOT = Path(__file__).resolve().parents[2]


def cli_model(alias: str | None) -> str:
    return (alias or "sonnet").replace("[1m]", "").strip()


def numbered(path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    return "\n".join(f"{i}\t{ln}" for i, ln in enumerate(raw.splitlines(), 1))


def run_once(model: str, system: str, user: str, timeout: int = 300) -> str:
    cmd = ["claude", "-p", user, "--system-prompt", system,
           "--model", model, "--output-format", "json"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(f"claude -p exit {proc.returncode}: {(proc.stderr or '').strip()[:300]}")
    data = json.loads(proc.stdout)
    if data.get("is_error"):
        raise RuntimeError(f"claude -p error: {str(data.get('result',''))[:300]}")
    return data.get("result", "") or ""


VERDICT_SYSTEM = (
    "You are a skeptical code-review VERIFIER. Your job is to REFUTE claimed issues, "
    "not to agree. You are given a source FILE (line-numbered) and ONE claimed issue. "
    "Decide whether the claim is REAL (the described problem genuinely exists in this "
    "file, at roughly the cited place, and the reasoning is correct) or a FALSE POSITIVE "
    "(the thing described is not actually in the file, or the reasoning is wrong). "
    "Default to refuted when the claimed construct is not present in the file. "
    'Output ONLY JSON: {"verdict":"real"|"refuted","reason":"<=15 words"}'
)


def verify_claim(file_text: str, claim: str, model: str) -> tuple[str, str]:
    user = f"=== FILE ===\n{file_text}\n\n=== CLAIMED ISSUE ===\n{claim}\n"
    raw = run_once(model, VERDICT_SYSTEM, user)
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        return "error", raw[:80]
    try:
        d = json.loads(m.group())
    except json.JSONDecodeError:
        return "error", raw[:80]
    v = str(d.get("verdict", "")).strip().lower()
    return ("real" if v == "real" else "refuted"), str(d.get("reason", ""))[:80]


def majority(verdicts: list[str]) -> str:
    real = verdicts.count("real")
    return "real" if real > len(verdicts) / 2 else "refuted"


def main() -> int:
    ap = argparse.ArgumentParser(description="Adversarial finding verifier")
    ap.add_argument("--file", required=True, help="source file the claims are about")
    ap.add_argument("--claims", required=True, help="jsonl of {id,text[,label]}")
    ap.add_argument("--model", default="sonnet", help="judge model alias (default sonnet)")
    ap.add_argument("--runs", type=int, default=1, help="votes per claim (majority); default 1")
    args = ap.parse_args()

    if not shutil.which("claude"):
        print("ERROR: `claude` CLI not found on PATH.", file=sys.stderr)
        return 1

    file_text = numbered(Path(args.file))
    claims = [json.loads(l) for l in Path(args.claims).read_text(encoding="utf-8").splitlines() if l.strip()]
    model = cli_model(args.model)

    rows, labeled, correct = [], 0, 0
    for c in claims:
        verdicts = []
        for _ in range(args.runs):
            v, _reason = verify_claim(file_text, c["text"], model)
            verdicts.append(v)
        final = majority(verdicts)
        row = {"id": c.get("id", "?"), "verdict": final, "votes": verdicts}
        if "label" in c:
            expected = "real" if c["label"] == "real" else "refuted"
            row["label"] = c["label"]
            row["ok"] = (final == expected)
            labeled += 1
            correct += int(row["ok"])
        rows.append(row)

    print(f"# Adversarial verify — {Path(args.file).name} (model={model}, runs={args.runs})\n")
    print("| claim | label | verdict | ok |")
    print("|---|---|---|---|")
    for r in rows:
        print(f"| {r['id']} | {r.get('label','—')} | {r['verdict']} | "
              f"{'✅' if r.get('ok') else ('❌' if 'ok' in r else '—')} |")
    if labeled:
        print(f"\n**Verifier accuracy: {correct}/{labeled} ({correct/labeled:.0%})** "
              f"— keeps real findings, refutes false positives.")
    kept = [r["id"] for r in rows if r["verdict"] == "real"]
    print(f"\nKept (survive verification): {kept or '(none)'}")
    return 0 if (not labeled or correct == labeled) else 2


if __name__ == "__main__":
    sys.exit(main())
