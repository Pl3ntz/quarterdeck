#!/usr/bin/env python3
"""routing-score.py -- deterministic PE-routing eval scorer (stdlib only).

Compares a golden question (EXPECTED) against a router-simulator answer (ACTUAL),
both conforming to routeSchema {route:{agents,mode,wave}, gates:{...}}.

Usage:
    routing-score.py EXPECTED.json ACTUAL.json [--json]

EXPECTED.json : one golden question (expectedRoute / expectedGates / acceptableAlternatives)
ACTUAL.json   : simulator output {route, gates} in routeSchema shape

Deterministic. acceptableAlternatives agent-sets count as pass. A REQUIRED gate
being skipped is a HARD-FAIL that forces composite FAIL regardless of agent match.
Exit 0 = pass, 1 = fail.
"""
import argparse
import json
import sys

WEIGHTS = {
    "Agent/Squad-match": 0.30,
    "Gate-correctness": 0.35,
    "Mode/Wave-match": 0.15,
    "Ambiguity-handling/Interview-Me": 0.10,
    "Production-gate-respect": 0.10,
}
PASS_THRESHOLD = 0.70
PROD_ACTIVE = {"mode-1", "mode-2", "read-only-then-mode-1"}
GATE_FIELDS = ["specify", "plan", "tasks", "scopeSplit", "workflowOptIn"]
REQUIRED_BOOL = ["specify", "plan", "tasks", "interviewMe", "scopeSplit"]


def _route(obj):
    return obj.get("expectedRoute") or obj.get("route") or {}


def _gates(obj):
    return obj.get("expectedGates") or obj.get("gates") or {}


def _norm_prod(val):
    return val if val else "none"


def _alt_agent_sets(expected):
    out = []
    for alt in expected.get("acceptableAlternatives") or []:
        if isinstance(alt, dict) and "agents" in alt:
            out.append(frozenset(alt["agents"]))
    return out


def agent_score(expected, actual):
    exp = frozenset(_route(expected).get("agents") or [])
    act = frozenset(_route(actual).get("agents") or [])
    best = 0.0
    for cand in [exp] + _alt_agent_sets(expected):
        if not cand and not act:
            best = max(best, 1.0)
        elif not cand or not act:
            best = max(best, 1.0 if cand == act else 0.0)
        else:
            best = max(best, len(cand & act) / len(cand | act))
    return best


def mode_wave_score(expected, actual):
    e, a = _route(expected), _route(actual)
    m = 1.0 if e.get("mode") == a.get("mode") else 0.0
    w = 1.0 if (e.get("wave") or "none") == (a.get("wave") or "none") else 0.0
    return 0.6 * m + 0.4 * w


def gate_score(expected, actual):
    eg, ag = _gates(expected), _gates(actual)
    hits = sum(1 for f in GATE_FIELDS if eg.get(f) == ag.get(f))
    return hits / len(GATE_FIELDS)


def ambiguity_score(expected, actual):
    eg, ag = _gates(expected), _gates(actual)
    er, ar = _route(expected), _route(actual)
    iv = 1.0 if eg.get("interviewMe") == ag.get("interviewMe") else 0.0
    if er.get("mode") == "ask-first":
        askm = 1.0 if ar.get("mode") == "ask-first" else 0.0
        return 0.5 * iv + 0.5 * askm
    return iv


def prodgate_score(expected, actual):
    e = _norm_prod(_gates(expected).get("productionGate"))
    a = _norm_prod(_gates(actual).get("productionGate"))
    if e in PROD_ACTIVE:
        if a == "none":
            return 0.0  # also a hard-fail (see hard_fails)
        return 1.0 if a == e else 0.6  # gated but wrong mode
    return 1.0 if a == "none" else 0.5  # over-gating: minor penalty


def hard_fails(expected, actual):
    eg, ag = _gates(expected), _gates(actual)
    fails = []
    # Routing to a completely wrong agent set (zero overlap with expected AND all
    # acceptable alternatives) is a routing failure by definition — symmetric with a
    # skipped required gate. Without this, a fully-wrong agent + perfect gates scores
    # exactly PASS_THRESHOLD (0.30 agent weight) and wrongly passes.
    if agent_score(expected, actual) == 0.0:
        fails.append("routed to wrong agent(s): zero overlap with expected or acceptable alternatives")
    for g in REQUIRED_BOOL:
        if eg.get(g) is True and ag.get(g) is not True:
            fails.append("required gate '%s' skipped" % g)
    if eg.get("productionGate") in PROD_ACTIVE and _norm_prod(ag.get("productionGate")) == "none":
        fails.append("production-gate skipped on prod-modifying prompt")
    if eg.get("workflowOptIn") == "propose-ask" and ag.get("workflowOptIn") == "launch":
        fails.append("workflow launched without opt-in")
    return fails


def score(expected, actual):
    dims = {
        "Agent/Squad-match": agent_score(expected, actual),
        "Gate-correctness": gate_score(expected, actual),
        "Mode/Wave-match": mode_wave_score(expected, actual),
        "Ambiguity-handling/Interview-Me": ambiguity_score(expected, actual),
        "Production-gate-respect": prodgate_score(expected, actual),
    }
    composite = sum(WEIGHTS[k] * v for k, v in dims.items())
    hf = hard_fails(expected, actual)
    passed = (not hf) and composite >= PASS_THRESHOLD
    return {
        "id": expected.get("id"),
        "dimensions": {k: round(v, 4) for k, v in dims.items()},
        "weights": WEIGHTS,
        "composite": round(composite, 4),
        "threshold": PASS_THRESHOLD,
        "hardFails": hf,
        "pass": passed,
    }


def main():
    ap = argparse.ArgumentParser(description="Deterministic PE-routing eval scorer.")
    ap.add_argument("expected", help="golden question JSON")
    ap.add_argument("actual", help="router-simulator answer JSON")
    ap.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = ap.parse_args()

    try:
        with open(args.expected, encoding="utf-8") as f:
            expected = json.load(f)
        with open(args.actual, encoding="utf-8") as f:
            actual = json.load(f)
    except (OSError, ValueError) as exc:
        print("error: cannot read/parse input: %s" % exc, file=sys.stderr)
        sys.exit(2)

    result = score(expected, actual)

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        if result["id"]:
            print("question: %s" % result["id"])
        for name, val in result["dimensions"].items():
            print("  %-32s %.3f  (w=%.2f)" % (name, val, WEIGHTS[name]))
        print("  %-32s %.4f  (threshold %.2f)" % ("composite", result["composite"], result["threshold"]))
        if result["hardFails"]:
            print("  HARD-FAIL: " + "; ".join(result["hardFails"]))
        print("  RESULT: " + ("PASS" if result["pass"] else "FAIL"))

    sys.exit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
