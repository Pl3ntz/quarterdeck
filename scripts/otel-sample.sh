#!/bin/bash
# otel-sample — run a headless Claude Code prompt with OpenTelemetry console export and
# summarize what was emitted.
#
# Why headless only: the console exporter writes to STDOUT. In an interactive session that
# corrupts the TUI, and in `claude -p` it buries the actual answer inside ~60 KB of metric
# dumps per prompt. Console export is a SAMPLING tool for inspecting the telemetry shape --
# it is not a mode you leave switched on. For continuous capture use
# OTEL_METRICS_EXPORTER=otlp pointed at a collector.
#
# Usage:
#   otel-sample.sh "your prompt"            # defaults to haiku to keep the sample cheap
#   otel-sample.sh "your prompt" sonnet
#
# Raw output is kept so the shape can be re-inspected without paying for another run.

set -uo pipefail

PROMPT="${1:-responda apenas: ok}"
MODEL="${2:-haiku}"
OUT_DIR="$HOME/.claude/logs/otel-samples"
STAMP=$(date +%Y%m%d-%H%M%S)
RAW="$OUT_DIR/sample-$STAMP.out"

mkdir -p "$OUT_DIR"

echo "running headless sample (model=$MODEL) ..." >&2

env CLAUDE_CODE_ENABLE_TELEMETRY=1 \
    OTEL_METRICS_EXPORTER=console \
    OTEL_LOGS_EXPORTER=console \
    OTEL_METRIC_EXPORT_INTERVAL=1000 \
    claude -p "$PROMPT" --model "$MODEL" > "$RAW" 2>/dev/null

status=$?
if [ $status -ne 0 ]; then
  echo "claude exited $status -- see $RAW" >&2
  exit $status
fi

python3 - "$RAW" <<'PY'
import re, sys, collections

path = sys.argv[1]
try:
    text = open(path, errors="ignore").read()
except OSError as exc:
    sys.exit(f"cannot read sample: {exc}")

metrics = collections.Counter(re.findall(r'name: "(claude_code\.[a-z_.]+)"', text))
events = collections.Counter(re.findall(r'body: "(claude_code\.[a-z_.]+)"', text))

# Each datapoint block ends with `value: N`; accumulate the attributes that precede it so token
# counts group the same way agent-usage-report.py groups them. Parsed line by line on purpose --
# a single re.S regex over a multi-megabyte sample backtracks badly.
KEYS = ("model", "query_source", "agent.name", "effort", "type")
ATTR_RE = re.compile(r'^\s*"?([\w.]+)"?:\s*"([^"]*)"')
VALUE_RE = re.compile(r"^\s*value:\s*(\d+)")

rows = collections.defaultdict(int)
current = {}
for line in text.splitlines():
    m = ATTR_RE.match(line)
    if m:
        current[m.group(1)] = m.group(2)
        continue
    m = VALUE_RE.match(line)
    if m:
        if "model" in current:
            rows[tuple(current.get(k, "-") for k in KEYS)] += int(m.group(1))
        current = {}

print(f"\nraw sample: {path}  ({len(text)//1024} KB)\n")
print("metrics emitted:")
for name, n in metrics.most_common():
    print(f"  {n:>3}x {name}")
print("\nevents emitted:")
for name, n in events.most_common(12):
    print(f"  {n:>3}x {name}")

if rows:
    print(f"\n{'model':<28}{'source':<10}{'agent':<16}{'effort':<8}{'type':<15}{'tokens':>10}")
    print("-" * 87)
    for (model, source, agent, effort, kind), total in sorted(rows.items(), key=lambda x: -x[1]):
        print(f"{model:<28}{source:<10}{agent:<16}{effort:<8}{kind:<15}{total:>10}")

print("\nNOTE: every datapoint carries user.email / organization.id / user.account_id.")
print("Strip or hash these before exporting to any third-party backend.\n")
PY
