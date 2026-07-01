#!/usr/bin/env python3
"""
rubric_runner.py — Quarterdeck rubric stability harness (Peça C)

Stability harness for GENERATIVE/prose agents (planner, architect, editor-chefe,
fact-checker) whose output is a document, not a findings list — so the
finding-based `stability_runner.py` doesn't fit. Instead of "did it detect issue
X", the question is "does its output satisfy criterion X" (has ordered phases,
names trade-offs, gives a next step, doesn't write code, ...).

Runs the agent K times on a fixed SCENARIO, then an independent judge scores each
run against a RUBRIC of yes/no criteria. Reuses the same classification as the
finding harness: a criterion is ESTAVEL (met K/K), FLUTUANTE (some), or CEGO (0).

Shells out to the `claude` CLI (headless) — Claude Code subscription, no API key.

Fixture per agent under tests/<name>/:
  - scenario.md — the task prompt fed to the agent
  - rubric.md   — a table: | id | criterion | difficulty |  (criterion = yes/no)

Usage:
    python scripts/eval/rubric_runner.py --agent planner --runs 5
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

QD_ROOT = Path(__file__).resolve().parents[2]

AGENTS_WITH_RUBRICS = ["planner", "architect", "editor-chefe", "fact-checker"]


def cli_model(alias: str | None) -> str:
    return (alias or "sonnet").replace("[1m]", "").strip()


def load_agent(name: str) -> tuple[str, str]:
    text = (QD_ROOT / "agents" / f"{name}.md").read_text(encoding="utf-8")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError(f"{name}: no YAML frontmatter")
    frontmatter, body = parts[1], parts[2]
    alias = None
    for line in frontmatter.splitlines():
        m = re.match(r"\s*model:\s*(.+?)\s*$", line)
        if m:
            alias = m.group(1)
            break
    return cli_model(alias), body.strip()


def load_rubric(name: str) -> list[dict]:
    """Parse rubric.md — a markdown table | id | criterion | difficulty |."""
    path = QD_ROOT / "tests" / name / "rubric.md"
    rows, header = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if set("".join(cells)) <= set("-: ") and "".join(cells):
            continue  # separator
        low = [c.lower() for c in cells]
        if "criterion" in low or "criterio" in low or "critério" in low:
            header = low
            continue
        if header is None:
            continue
        row = {header[i]: cells[i] for i in range(min(len(header), len(cells)))}
        crit = row.get("criterion") or row.get("criterio") or row.get("critério") or ""
        cid = row.get("id") or row.get("#") or ""
        if crit and cid:
            rows.append({"id": cid, "criterion": crit,
                         "difficulty": (row.get("difficulty", "") or "").lower()})
    return rows


def run_once(model: str, system: str, user: str, cwd: str, timeout: int = 600,
             attempts: int = 3) -> str:
    """Run `claude -p` once, retrying transient CLI failures (exit!=0, non-JSON).
    Prose agents occasionally return a bare exit 1; a retry usually clears it, so
    one flaky call doesn't nuke a whole K-run baseline."""
    cmd = ["claude", "-p", user, "--system-prompt", system,
           "--model", model, "--output-format", "json"]
    last = ""
    for _ in range(max(1, attempts)):
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
        if proc.returncode != 0:
            last = f"claude -p exit {proc.returncode}: {(proc.stderr or '').strip()[:200]}"
            continue
        try:
            data = json.loads(proc.stdout)
        except json.JSONDecodeError:
            last = f"non-JSON output: {proc.stdout[:120]!r}"
            continue
        if data.get("is_error"):
            last = f"claude -p error: {str(data.get('result',''))[:200]}"
            continue
        return data.get("result", "") or ""
    raise RuntimeError(f"claude -p failed after {attempts} attempts: {last}")


JUDGE_SYSTEM = (
    "You grade whether an agent's OUTPUT satisfies each rubric CRITERION. Judge on "
    "SUBSTANCE, never on wording or language (output may be pt-BR or EN). A criterion "
    "is satisfied only if the output genuinely does what it describes. Output ONLY a "
    'JSON object {"<id>": true, "<id>": false, ...}, one key per criterion, no prose.'
)


def judge(output: str, rubric: list[dict], model: str, cwd: str) -> set[str]:
    items = "\n".join(f"- {c['id']}: {c['criterion']}" for c in rubric)
    user = (f"=== AGENT OUTPUT ===\n{output}\n\n=== RUBRIC (judge each id) ===\n{items}\n\n"
            'Return ONLY {"<id>": true/false, ...}.')
    raw = run_once(model, JUDGE_SYSTEM, user, cwd)
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        raise RuntimeError(f"judge returned no JSON: {raw[:120]!r}")
    data = json.loads(m.group())
    return {k for k, v in data.items() if v is True or str(v).strip().lower() == "true"}


def run_agent(name: str, runs: int, model_override: str | None, judge_model: str = "sonnet") -> int:
    model, system = load_agent(name)
    if model_override:
        model = cli_model(model_override)
    scenario = (QD_ROOT / "tests" / name / "scenario.md").read_text(encoding="utf-8")
    rubric = load_rubric(name)
    if not rubric:
        print(f"ERROR: empty rubric for {name}", file=sys.stderr)
        return 1

    runs_path = QD_ROOT / "tests" / name / ".rubric-runs.jsonl"
    met_counts = {c["id"]: 0 for c in rubric}
    with tempfile.TemporaryDirectory() as cwd, runs_path.open("w", encoding="utf-8") as fh:
        for i in range(1, runs + 1):
            print(f"[{name}] run {i}/{runs} (model={model})...", file=sys.stderr)
            output = run_once(model, system, scenario, cwd)
            met = judge(output, rubric, judge_model, cwd)
            for cid in met:
                if cid in met_counts:
                    met_counts[cid] += 1
            fh.write(json.dumps({"run": i, "agent": name, "model": model,
                                 "met": sorted(met), "output": output}, ensure_ascii=False) + "\n")

    results = []
    for c in rubric:
        hits = met_counts[c["id"]]
        cls = "ESTAVEL" if hits == runs else ("CEGO" if hits == 0 else "FLUTUANTE")
        results.append({**c, "hits": hits, "k": runs, "class": cls})

    stable = sum(1 for r in results if r["class"] == "ESTAVEL")
    total = len(results)
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        f"# Rubric Report — {name}", "",
        f"- **Model:** `{model}` · **Judge:** `{judge_model}` · **Runs (K):** {runs}",
        f"- **Generated:** {ts}", "",
        f"- **Stability** (ESTAVEL/total): **{stable/total:.0%}** ({stable}/{total})",
        f"- **Mean criteria met:** {sum(r['hits'] for r in results)/(total*runs):.0%}", "",
        "| id | criterion | diff | met | class |", "|---|---|---|---|---|",
    ]
    for r in results:
        crit = r["criterion"][:52].replace("|", "\\|")
        lines.append(f"| {r['id']} | {crit} | {r.get('difficulty') or '—'} | {r['hits']}/{r['k']} | {r['class']} |")
    report = "\n".join(lines) + "\n"
    (QD_ROOT / "tests" / name / "rubric-report.md").write_text(report, encoding="utf-8")
    print(report)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Quarterdeck rubric stability harness")
    ap.add_argument("--agent", help=f"one of: {', '.join(AGENTS_WITH_RUBRICS)}")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--model", default=None, help="override agent frontmatter model")
    args = ap.parse_args()
    if not args.all and not args.agent:
        ap.error("provide --agent <name> or --all")
    if not shutil.which("claude"):
        print("ERROR: `claude` CLI not found on PATH.", file=sys.stderr)
        return 1
    targets = AGENTS_WITH_RUBRICS if args.all else [args.agent]
    rc = 0
    for name in targets:
        if not (QD_ROOT / "tests" / name / "rubric.md").exists():
            print(f"ERROR: no rubric for '{name}' (tests/{name}/rubric.md missing)", file=sys.stderr)
            rc = 1
            continue
        rc |= run_agent(name, args.runs, args.model)
    return rc


if __name__ == "__main__":
    sys.exit(main())
