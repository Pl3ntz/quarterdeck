#!/usr/bin/env python3
"""
routing_runner — measure PE routing against the frozen golden set, for a given ruleset.

The routing eval has had a golden set and a deterministic scorer since it was written, and
had never been run: `evals/routing/` holds no baseline. So when the PE rule's routing tables
were moved out of the always-on context on 2026-07-25, there was no way to say whether that
cost anything. This produces the number.

Each question is routed by a fresh headless session that reads the ruleset and emits only
`{route, gates}`. Scoring is `routing-score.py`, which is deterministic: no judge, no model
in the loop after the simulator, so two runs of the same ruleset differ only by the model's
own variance.

Usage:
  routing_runner.py --rules ~/.claude/rules --label current
  routing_runner.py --rules /tmp/pre-cut     --label pre-cut --jobs 6

  # A/B: run both, then compare the two JSON results
  routing_runner.py --compare results-pre-cut.json results-current.json

Results land in ~/.claude/evals/routing/results-<label>.json.
"""
import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import threading
from pathlib import Path

EVAL_DIR = Path.home() / ".claude" / "evals" / "routing"
SCORER = Path.home() / ".claude" / "scripts" / "routing-score.py"

PROMPT = """You are a ROUTER SIMULATOR for a Principal Engineer (PE) orchestration system.
You are NOT executing the request. You only decide how it would be routed.

Step 1 - read these two files in full, and only these:
  {rules}/principal-engineer-always-on.md
  {rules}/production-gate-mandatory.md

Do not read any eval, golden-set or rubric file. Do not search the filesystem for the answer.
Do not execute, edit or inspect any project code.

Step 2 - apply what you read to the request below and emit the routing decision as JSON:

{{"route": {{"agents": [...], "mode": "solo|single|chain|parallel|ask-first|scope-split",
            "wave": "none|wave-based"}},
  "gates": {{"triage": "Trivial|Médio|Complexo", "specify": bool, "plan": bool, "tasks": bool,
            "interviewMe": bool, "productionGate": "none|mode-1|mode-2|read-only-then-mode-1",
            "scopeSplit": bool, "workflowOptIn": "n/a|launch|propose-ask"}}}}

route.agents is the specialist agents the PE would delegate to, in order. An empty array
means the PE handles it alone. Be faithful to the rules as written, including where they say
NOT to open a gate: over-gating a trivial request is as wrong as skipping a required one.

Output ONLY the JSON object. No prose, no explanation, no code fence.

## Owner request to route
{question}
"""


def run_one(q, rules, timeout):
    """Route one question in a fresh headless session. Returns (id, parsed-or-None)."""
    try:
        proc = subprocess.run(
            ["claude", "-p", PROMPT.format(rules=rules, question=q["prompt"])],
            capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        return q["id"], None
    out = proc.stdout.strip()
    # The model occasionally wraps the object in a fence despite the instruction.
    if "```" in out:
        parts = [p for p in out.split("```") if "{" in p]
        out = parts[0] if parts else out
        out = out.replace("json", "", 1).strip()
    start, end = out.find("{"), out.rfind("}")
    if start < 0 or end < 0:
        return q["id"], None
    try:
        return q["id"], json.loads(out[start:end + 1])
    except json.JSONDecodeError:
        return q["id"], None


def score(question, actual):
    """Deterministic score for one answer. Returns (passed, composite)."""
    if actual is None:
        return False, 0.0
    # Unique per call. The runner scores in the main loop, so these never collided here -- but
    # a fixed name is a trap for anyone who calls score() from a thread pool, and someone did:
    # two identical answers came back 0.00 and 1.00 in the same batch because the scorer read
    # a sibling's file. Cheap to make impossible.
    tag = f"{os.getpid()}-{threading.get_ident()}"
    with_exp = EVAL_DIR / f".tmp-expected-{tag}.json"
    with_act = EVAL_DIR / f".tmp-actual-{tag}.json"
    with_exp.write_text(json.dumps(question))
    with_act.write_text(json.dumps(actual))
    try:
        proc = subprocess.run(
            [sys.executable, str(SCORER), str(with_exp), str(with_act), "--json"],
            capture_output=True, text=True,
        )
        passed = proc.returncode == 0
        composite = 0.0
        try:
            composite = json.loads(proc.stdout).get("composite", 0.0)
        except (json.JSONDecodeError, AttributeError):
            pass
        return passed, composite
    finally:
        with_exp.unlink(missing_ok=True)
        with_act.unlink(missing_ok=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rules", help="directory holding the two rule files to route against")
    ap.add_argument("--label", help="name for this run, used in the result filename")
    ap.add_argument("--jobs", type=int, default=5, help="concurrent sessions (default 5)")
    ap.add_argument("--runs", type=int, default=1,
                    help="repeats per question (default 1). A single run cannot separate a "
                         "real change from the model's variance: measured across six "
                         "rulesets, 11 of the 26 questions swung by 0.20 or more, which is "
                         "wider than any per-round delta this eval has produced. Use 3 or "
                         "more before calling a delta an improvement.")
    ap.add_argument("--limit", type=int, help="run only the first N questions")
    ap.add_argument("--timeout", type=int, default=300, help="seconds per question")
    ap.add_argument("--compare", nargs=2, metavar=("A", "B"), help="compare two result files")
    args = ap.parse_args()

    if args.compare:
        return compare(*args.compare)
    if not args.rules or not args.label:
        ap.error("--rules and --label are required unless --compare is used")

    golden = json.loads((EVAL_DIR / "golden-set.json").read_text())
    questions = golden["questions"][: args.limit] if args.limit else golden["questions"]
    rules = os.path.expanduser(args.rules)

    print(f"routing eval: {len(questions)} questions against {rules} "
          f"({args.jobs} concurrent)", file=sys.stderr)

    import statistics
    raw = {q["id"]: [] for q in questions}
    jobs = [(q, k) for k in range(args.runs) for q in questions]
    total = len(jobs)
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, q, rules, args.timeout): q for q, _ in jobs}
        for n, fut in enumerate(cf.as_completed(futures), 1):
            qid, actual = fut.result()
            q = next(x for x in questions if x["id"] == qid)
            passed, composite = score(q, actual)
            raw[qid].append({"passed": passed, "composite": composite,
                             "parsed": actual is not None})
            print(f"  [{n:>3}/{total}] {composite:.2f}  {qid}", file=sys.stderr)

    # The median is the reported value: one bad sample should not decide a question, and one
    # lucky sample should not either.
    results = {}
    for qid, samples in raw.items():
        comps = [s["composite"] for s in samples]
        med = statistics.median(comps)
        results[qid] = {"composite": round(med, 4), "passed": med >= 0.70,
                        "min": round(min(comps), 4), "max": round(max(comps), 4),
                        "spread": round(max(comps) - min(comps), 4),
                        "runs": len(comps),
                        "parsed": all(s["parsed"] for s in samples)}

    passed = sum(1 for r in results.values() if r["passed"])
    unparsed = sum(1 for r in results.values() if not r["parsed"])
    mean = sum(r["composite"] for r in results.values()) / len(results) if results else 0.0
    spreads = [r["spread"] for r in results.values()]
    noise = round(statistics.mean(spreads), 4) if spreads else 0.0
    if args.runs > 1:
        print(f"\n  mean spread within a question: {noise:.3f} "
              f"-- a round-over-round delta smaller than this is not evidence.",
              file=sys.stderr)
    summary = {"label": args.label, "rules": rules, "questions": len(results),
               "runs_per_question": args.runs, "passed": passed, "unparsed": unparsed,
               "mean_composite": round(mean, 4), "mean_spread": noise, "results": results}
    out = EVAL_DIR / f"results-{args.label}.json"
    out.write_text(json.dumps(summary, indent=1, ensure_ascii=False))
    print(f"\n{args.label}: {passed}/{len(results)} passed, mean composite {mean:.3f}"
          f"{f', {unparsed} unparsed' if unparsed else ''}\n-> {out}", file=sys.stderr)


def compare(path_a, path_b):
    a = json.loads(Path(path_a).read_text())
    b = json.loads(Path(path_b).read_text())
    print(f"\n{'question':<34}{a['label']:>12}{b['label']:>12}   delta")
    print("-" * 72)
    moved = []
    for qid in sorted(set(a["results"]) | set(b["results"])):
        ra, rb = a["results"].get(qid, {}), b["results"].get(qid, {})
        ca, cb = ra.get("composite", 0.0), rb.get("composite", 0.0)
        d = cb - ca
        flag = "" if abs(d) < 0.01 else ("  +" if d > 0 else "  -")
        if abs(d) >= 0.01:
            moved.append((qid, ca, cb))
        print(f"{qid:<34}{ca:>12.2f}{cb:>12.2f}{flag}")
    print("-" * 72)
    print(f"{'passed':<34}{a['passed']:>12}{b['passed']:>12}")
    print(f"{'mean composite':<34}{a['mean_composite']:>12.3f}{b['mean_composite']:>12.3f}"
          f"   {b['mean_composite'] - a['mean_composite']:+.3f}")
    print(f"\n{len(moved)} question(s) moved. A single run carries the model's own variance, "
          f"so treat a delta under a few points as noise unless it repeats.")


if __name__ == "__main__":
    sys.exit(main())
