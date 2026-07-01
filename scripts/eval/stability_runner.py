#!/usr/bin/env python3
"""
stability_runner.py — Quarterdeck judge stability harness (Peça A)

Runs a review agent K times against its fixture and measures WHERE the judge is
already stable, instead of asserting a single-run pass rate. An LLM reviewer is
non-deterministic, so the useful signal is which findings it catches EVERY time
(stable) vs SOMETIMES (fluctuating) vs NEVER (blind).

Invocation uses the `claude` CLI in headless mode (`claude -p`), so it runs on
your Claude Code subscription — no API key, no per-call billing — and exercises
the same runtime the agents actually run in.

Two fixture formats are supported, auto-detected from expected-findings.md:
  - GRAMMAR (grammar/ortografia): table with Wrong/Correct columns. A finding is
    detected if the wrong/correct text (or >=50% of its significant tokens)
    appears anywhere in the run output. Line is unreliable (off-by-one), unused.
  - CODE (code/security review): table with Type/Keywords columns. Findings are
    semantic, so a finding is detected if a finding bullet within +/-3 lines
    carries >=50% of the row's keywords.

Both matchers are DETERMINISTIC (same criterion every run), so the variance they
report is the agent's, not the matcher's.

Usage:
    python scripts/eval/stability_runner.py --agent code-reviewer --runs 5
    python scripts/eval/stability_runner.py --all --runs 5

Requires only the `claude` CLI (from your Claude Code subscription) on PATH.
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

AGENTS_WITH_FIXTURES = [
    "grammar-reviewer", "ortografia-reviewer", "code-reviewer", "security-reviewer",
    "ux-reviewer", "performance-optimizer", "database-specialist", "seo-reviewer",
]

FIXTURE_NAMES = ("test-errors.md", "test-code.py", "test-ui.tsx", "test-schema.sql",
                 "test-page.html")

_SEV = r"(CRITICAL|HIGH|MEDIUM|LOW|CRITICO|CRÍTICO|ALTO|MEDIO|MÉDIO|BAIXO)"
FINDING_RE = re.compile(r"^\s*[-*]\s*\*\*\[?\s*" + _SEV + r"\s*\]?\*\*\s*(.*)$", re.IGNORECASE)
VALID_SEV = {"CRITICAL", "HIGH", "MEDIUM", "LOW",
             "CRITICO", "CRÍTICO", "ALTO", "MEDIO", "MÉDIO", "BAIXO"}


def cli_model(alias: str | None) -> str:
    if not alias:
        return "sonnet"
    return alias.replace("[1m]", "").strip()


def load_agent(name: str) -> tuple[str, str]:
    """Return (cli_model, system_prompt) for agents/<name>.md."""
    path = QD_ROOT / "agents" / f"{name}.md"
    text = path.read_text(encoding="utf-8")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError(f"{path}: no YAML frontmatter found")
    frontmatter, body = parts[1], parts[2]
    alias = None
    for line in frontmatter.splitlines():
        m = re.match(r"\s*model:\s*(.+?)\s*$", line)
        if m:
            alias = m.group(1)
            break
    return cli_model(alias), body.strip()


def load_fixture(name: str) -> tuple[str, str]:
    """Load the fixture file (line-numbered) and return (text, filename)."""
    d = QD_ROOT / "tests" / name
    for fname in FIXTURE_NAMES:
        p = d / fname
        if p.exists():
            raw = p.read_text(encoding="utf-8")
            numbered = "\n".join(f"{i}\t{line}" for i, line in enumerate(raw.splitlines(), 1))
            return numbered, fname
    raise FileNotFoundError(f"no fixture in tests/{name}/ (expected one of {FIXTURE_NAMES})")


def _normalize_expected(row: dict) -> dict | None:
    line_raw = row.get("line") or row.get("linha") or ""
    m = re.search(r"\d+", line_raw)
    line = int(m.group()) if m else None
    severity = (row.get("severity") or row.get("severidade") or "").upper()
    if severity not in VALID_SEV:
        return None  # filters table headers and the Summary table
    ident = row.get("#") or row.get("id") or ""
    if "keywords" in row:
        kws = [k.strip() for k in re.split(r"[;,]", row.get("keywords", "")) if k.strip()]
        if not kws:
            return None
        return {"id": ident, "line": line, "severity": severity, "kind": "code",
                "keywords": kws, "label": row.get("type", "") or ident,
                "difficulty": (row.get("difficulty", "") or "").lower()}
    wrong = row.get("wrong") or row.get("errado") or ""
    if not wrong:
        return None
    return {"id": ident, "line": line, "severity": severity, "kind": "grammar",
            "wrong": wrong, "correct": row.get("correct") or row.get("correto") or "",
            "label": wrong, "difficulty": ""}


def load_expected(name: str) -> list[dict]:
    """Parse expected-findings.md, auto-detecting grammar vs code format."""
    path = QD_ROOT / "tests" / name / "expected-findings.md"
    rows: list[dict] = []
    header: list[str] | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        joined = "".join(cells)
        if joined and set(joined) <= set("-: "):
            continue  # separator
        low = [c.lower() for c in cells]
        if any(h in low for h in ("wrong", "errado", "keywords")):
            header = low  # re-detect on every table (fixtures have one per section)
            continue
        if header is None:
            continue
        row = {header[i]: cells[i] for i in range(min(len(header), len(cells)))}
        norm = _normalize_expected(row)
        if norm:
            rows.append(norm)
    return rows


def parse_findings(text: str) -> list[dict]:
    """Extract FINDINGS bullets (severity + file:line) from one agent run."""
    findings: list[dict] = []
    for line in text.splitlines():
        m = FINDING_RE.match(line)
        if not m:
            continue
        rest = m.group(2).strip()
        lm = re.search(r"`[^`]*:(\d+)`", rest) or re.search(r":(\d+)\b", rest)
        findings.append({"severity": m.group(1).upper(), "text": rest,
                         "line": int(lm.group(1)) if lm else None})
    return findings


def _norm(s: str) -> str:
    s = s.lower().strip(" \"'`.,;:!?()[]")
    return re.sub(r"\s+", " ", s)


def _sig_tokens(s: str) -> list[str]:
    return [t for t in re.findall(r"[0-9a-zà-ÿ']+", _norm(s)) if len(t) >= 4]


def _grammar_detected(exp: dict, text_norm: str) -> bool:
    w = _norm(exp["wrong"])
    if w and w in text_norm:
        return True
    c = _norm(exp["correct"])
    if c and len(c) > 4 and c in text_norm:
        return True
    toks = _sig_tokens(exp["wrong"])
    return bool(toks) and sum(1 for t in toks if t in text_norm) / len(toks) >= 0.5


def _code_match_finding(exp: dict, f: dict) -> bool:
    # Keywords are distinctive code tokens, so overlap alone is reliable. Line is
    # NOT used as a gate: agents cite the function line, not the exact bug line,
    # so a tight line window wrongly dropped findings the agent did report.
    kws = [k.lower() for k in exp["keywords"]]
    if not kws:
        return False
    ft = _norm(f["text"])
    return sum(1 for k in kws if k in ft) / len(kws) >= 0.5


def expected_detected(exp: dict, output_norm: str, findings: list[dict]) -> bool:
    if exp["kind"] == "code":
        return any(_code_match_finding(exp, f) for f in findings)
    return _grammar_detected(exp, output_norm)


def finding_is_false_positive(f: dict, expected: list[dict]) -> bool:
    ft = _norm(f["text"])
    for exp in expected:
        if exp["kind"] == "code":
            if _code_match_finding(exp, f):
                return False
        elif _grammar_detected(exp, ft):
            return False
    return True


def run_once(model: str, system: str, user_content: str, cwd: str, timeout: int = 600) -> str:
    cmd = ["claude", "-p", user_content, "--system-prompt", system,
           "--model", model, "--output-format", "json"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
    if proc.returncode != 0:
        raise RuntimeError(f"claude -p exit {proc.returncode}: {(proc.stderr or '').strip()[:400]}")
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"claude -p: non-JSON output: {e}; head={proc.stdout[:200]!r}")
    if data.get("is_error"):
        raise RuntimeError(f"claude -p reported error: {str(data.get('result',''))[:400]}")
    return data.get("result", "") or ""


def llm_judge(output: str, expected: list[dict], cwd: str,
              judge_model: str = "sonnet") -> tuple[set[str], int]:
    """LLM-as-judge: decide, per checklist id, whether the review flagged it (on
    substance, regardless of wording/language/grouping). Returns (detected_ids,
    extra_count). Far more faithful than keyword matching for semantic findings."""
    items = "\n".join(
        f"- {e['id']}: {e['label']} (around line {e['line']}, {e['severity']})" for e in expected
    )
    system = ("You are a precise grading assistant for code-review output. You judge on "
              "substance, never on wording. You output ONLY a JSON object, no prose.")
    user = (
        "A reviewer produced the REVIEW OUTPUT below. The CHECKLIST lists the known issues in the "
        "file that was reviewed. For each checklist id, decide whether the review flagged that "
        "issue — the reviewer may reword it, write in English or Portuguese, group several issues "
        "into one bullet, or cite a nearby line. Then count how many DISTINCT real issues the "
        "review reported that are NOT on the checklist.\n\n"
        'Return ONLY a JSON object of the form: {"<id>": true, "<id>": false, ..., "_extra": <int>}\n\n'
        f"=== REVIEW OUTPUT ===\n{output}\n\n=== CHECKLIST ===\n{items}\n"
    )
    raw = run_once(judge_model, system, user, cwd)
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        raise RuntimeError(f"judge returned no JSON: {raw[:200]!r}")
    data = json.loads(m.group())
    extra = int(data.get("_extra", 0) or 0)
    detected = {k for k, v in data.items()
                if k != "_extra" and (v is True or str(v).strip().lower() == "true")}
    return detected, extra


def aggregate(expected: list[dict], runs: list[dict]) -> tuple[list[dict], list[int]]:
    """runs: list of {"output", "findings", and optionally "judged_ids"/"extra"}."""
    k = len(runs)
    norm_outputs = [_norm(r["output"]) for r in runs]
    use_judge = bool(runs) and all(r.get("judged_ids") is not None for r in runs)
    results: list[dict] = []
    for exp in expected:
        if use_judge and exp["kind"] == "code":
            hits = sum(1 for r in runs if exp["id"] in r["judged_ids"])
        else:
            hits = sum(1 for i, r in enumerate(runs)
                       if expected_detected(exp, norm_outputs[i], r["findings"]))
        cls = "ESTAVEL" if hits == k else ("CEGO" if hits == 0 else "FLUTUANTE")
        results.append({**exp, "hits": hits, "k": k, "rate": hits / k if k else 0.0, "class": cls})
    if use_judge:
        false_positives = [int(r.get("extra", 0)) for r in runs]
    else:
        false_positives = [sum(1 for f in r["findings"] if finding_is_false_positive(f, expected))
                           for r in runs]
    return results, false_positives


def _trunc(s: str, n: int) -> str:
    s = s.replace("|", "\\|").replace("\n", " ").strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def write_report(name: str, model: str, runs: int,
                 results: list[dict], false_positives: list[int]) -> Path:
    total = len(results)
    stable = sum(1 for r in results if r["class"] == "ESTAVEL")
    fluctuating = [r for r in results if r["class"] == "FLUTUANTE"]
    blind = [r for r in results if r["class"] == "CEGO"]
    stability = stable / total if total else 0.0
    detection = sum(r["rate"] for r in results) / total if total else 0.0
    avg_fp = sum(false_positives) / len(false_positives) if false_positives else 0.0
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    has_diff = any(r.get("difficulty") for r in results)

    lines = [
        f"# Stability Report — {name}", "",
        f"- **Model:** `{model}` (via `claude -p`)",
        f"- **Runs (K):** {runs}",
        f"- **Generated:** {ts}", "",
        "## Summary", "",
        f"- **Stability score** (ESTAVEL / total): **{stability:.0%}** ({stable}/{total})",
        f"- **Detection score** (mean hit rate): **{detection:.0%}**",
        f"- **Fluctuating:** {len(fluctuating)} · **Blind:** {len(blind)}",
        f"- **False positives / run:** {avg_fp:.1f} (per-run: {false_positives})",
    ]
    if has_diff:
        for diff in ("obvious", "subtle"):
            grp = [r for r in results if r.get("difficulty") == diff]
            if grp:
                st = sum(1 for r in grp if r["class"] == "ESTAVEL")
                lines.append(f"- **{diff.capitalize()}:** {st}/{len(grp)} stable")
    lines += [
        "", "> Stable findings are the judge's trustworthy floor. Fluctuating findings",
        "> are where the judge is non-deterministic — the signal worth acting on.", "",
        "## Per-finding", "",
        "| # | Line | Finding | Diff | Hit rate | Class |",
        "|---|---|---|---|---|---|",
    ]
    for r in results:
        lines.append(f"| {_trunc(str(r['id']), 28)} | {r['line']} | {_trunc(r['label'], 34)} | "
                     f"{r.get('difficulty') or '—'} | {r['hits']}/{r['k']} | {r['class']} |")
    if fluctuating:
        lines += ["", "## ⚠ Fluctuating (non-deterministic detection)", ""]
        for r in fluctuating:
            lines.append(f"- `{r['hits']}/{r['k']}` **{_trunc(r['label'], 50)}** "
                         f"({r.get('difficulty') or '—'}, {r['severity']})")
    if blind:
        lines += ["", "## ✗ Blind (never detected)", ""]
        for r in blind:
            lines.append(f"- **{_trunc(r['label'], 50)}** "
                         f"({r.get('difficulty') or '—'}, {r['severity']})")
    lines.append("")
    report = "\n".join(lines)
    out = QD_ROOT / "tests" / name / "stability-report.md"
    out.write_text(report, encoding="utf-8")
    print(report)
    return out


def run_agent(name: str, runs: int, model_override: str | None) -> None:
    model, system = load_agent(name)
    if model_override:
        model = cli_model(model_override)
    fixture, fixture_file = load_fixture(name)
    expected = load_expected(name)
    is_code = bool(expected) and expected[0]["kind"] == "code"
    user_content = (
        f"Review this file for issues and report your findings using your standard "
        f"output format. Each line is prefixed with its line number.\n\n"
        f"File: tests/{name}/{fixture_file}\n\n{fixture}"
    )

    runs_path = QD_ROOT / "tests" / name / ".stability-runs.jsonl"
    run_records: list[dict] = []
    with tempfile.TemporaryDirectory() as cwd, runs_path.open("w", encoding="utf-8") as fh:
        for i in range(1, runs + 1):
            print(f"[{name}] run {i}/{runs} (model={model})...", file=sys.stderr)
            output = run_once(model, system, user_content, cwd)
            findings = parse_findings(output)
            rec = {"output": output, "findings": findings}
            jrow = {"run": i, "agent": name, "model": model,
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "n_findings": len(findings), "output": output}
            if is_code:  # semantic findings -> LLM-as-judge instead of keyword match
                detected, extra = llm_judge(output, expected, cwd)
                rec["judged_ids"], rec["extra"] = detected, extra
                jrow["judged_ids"], jrow["extra"] = sorted(detected), extra
            run_records.append(rec)
            fh.write(json.dumps(jrow, ensure_ascii=False) + "\n")

    results, false_positives = aggregate(expected, run_records)
    write_report(name, model, runs, results, false_positives)
    print(f"\n[{name}] raw runs → {runs_path.relative_to(QD_ROOT)}", file=sys.stderr)


def rejudge_agent(name: str, judge_model: str = "sonnet") -> None:
    """Re-score already-captured runs with the LLM judge — no reviewer re-runs."""
    expected = load_expected(name)
    runs_path = QD_ROOT / "tests" / name / ".stability-runs.jsonl"
    recs = [json.loads(l) for l in runs_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    if not recs:
        print(f"ERROR: no captured runs in {runs_path}", file=sys.stderr)
        return
    run_records: list[dict] = []
    with tempfile.TemporaryDirectory() as cwd:
        for r in recs:
            print(f"[{name}] re-judging run {r['run']}/{len(recs)}...", file=sys.stderr)
            detected, extra = llm_judge(r["output"], expected, cwd, judge_model)
            run_records.append({"output": r["output"], "findings": parse_findings(r["output"]),
                                "judged_ids": detected, "extra": extra})
    model = recs[0].get("model", "?")
    results, false_positives = aggregate(expected, run_records)
    write_report(name, model, len(run_records), results, false_positives)


def main() -> int:
    ap = argparse.ArgumentParser(description="Quarterdeck judge stability harness")
    ap.add_argument("--agent", help="agent name (e.g. code-reviewer)")
    ap.add_argument("--all", action="store_true",
                    help=f"run all agents with fixtures ({', '.join(AGENTS_WITH_FIXTURES)})")
    ap.add_argument("--runs", type=int, default=5, help="number of runs K (default 5)")
    ap.add_argument("--model", default=None, help="override the agent's frontmatter model")
    ap.add_argument("--rejudge", action="store_true",
                    help="re-score already-captured runs with the LLM judge (no reviewer re-runs)")
    args = ap.parse_args()

    if not args.all and not args.agent:
        ap.error("provide --agent <name> or --all")

    if not shutil.which("claude"):
        print("ERROR: `claude` CLI not found on PATH (needs the Claude Code subscription CLI).",
              file=sys.stderr)
        return 1

    targets = AGENTS_WITH_FIXTURES if args.all else [args.agent]
    for name in targets:
        if not (QD_ROOT / "tests" / name / "expected-findings.md").exists():
            print(f"ERROR: no fixture for '{name}' (tests/{name}/expected-findings.md missing)",
                  file=sys.stderr)
            return 1
        if args.rejudge:
            rejudge_agent(name)
        else:
            run_agent(name, args.runs, args.model)

    return 0


if __name__ == "__main__":
    sys.exit(main())
