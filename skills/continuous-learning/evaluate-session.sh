#!/bin/bash
# Continuous Learning - Session Evaluator
# Reviews error-events.jsonl for unresolved errors and reports stats
#
# Called by the PE during /learn or at session end to check
# if there are unresolved errors that should be captured.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/.claude/logs"
ERROR_EVENTS="${LOG_DIR}/error-events.jsonl"
ERROR_INDEX="${LOG_DIR}/error-index.md"

# Check if error events file exists
if [ ! -f "$ERROR_EVENTS" ]; then
  echo "No error events logged yet."
  exit 0
fi

# Count errors by status
python3 -c "
import json, sys
from collections import Counter

events_file = '${ERROR_EVENTS}'
index_file = '${ERROR_INDEX}'

try:
    with open(events_file, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print('No error events logged yet.')
    sys.exit(0)

if not lines:
    print('No error events logged yet.')
    sys.exit(0)

total = len(lines)
categories = Counter()
unresolved = 0

for line in lines:
    try:
        entry = json.loads(line.strip())
        categories[entry.get('category', 'unknown')] += 1
        if entry.get('status') == 'unresolved':
            unresolved += 1
    except:
        continue

# Count index entries
index_count = 0
import re
try:
    with open(index_file, 'r') as f:
        for line in f:
            if re.match(r'^\d+\.\s+\*\*', line.strip()):
                index_count += 1
except:
    pass

print(f'Error Memory Stats:')
print(f'  Total events logged: {total}')
print(f'  Unresolved: {unresolved}')
print(f'  Index entries: {index_count}')
print(f'  By category:')
for cat, count in categories.most_common():
    print(f'    {cat}: {count}')

if unresolved > 0:
    print(f'')
    print(f'Last 5 unresolved errors:')
    unresolv_entries = []
    for line in reversed(lines):
        try:
            entry = json.loads(line.strip())
            if entry.get('status') == 'unresolved':
                unresolv_entries.append(entry)
                if len(unresolv_entries) >= 5:
                    break
        except:
            continue
    for e in unresolv_entries:
        cmd = e.get('command', '')[:80]
        cat = e.get('category', '?')
        ts = e.get('timestamp', '?')[:10]
        print(f'    [{ts}] ({cat}) {cmd}')
"
