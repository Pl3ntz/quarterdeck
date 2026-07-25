#!/bin/bash
# Egress Guard — PreToolUse hook on the tools that send data OUT.
#
# The leak guard protects one egress path: git. Everything else was open. WebFetch carries
# a URL and a prompt to a third party, WebSearch carries a query, and an MCP browser tool
# carries whatever gets typed into a form or passed to evaluate(). Nothing inspected any of
# it before it left, and the only hook on WebFetch runs PostToolUse, which can flag hostile
# content coming back but cannot stop anything going out.
#
# This runs the SAME scanner the commit path uses (pt-BR PII, known-prefix secrets, and the
# infrastructure denylist) over the outbound payload, and denies on a hard BLOCK. WARN-tier
# matches pass: the ambiguous-codename list produces false positives on ordinary Portuguese
# words, and a guard that cries wolf gets overridden reflexively.
#
# Deliberately scans the whole tool_input rather than named fields. MCP tools each shape
# their arguments differently, so an allowlist of field names would silently miss the next
# server added.
#
# Escape hatch: EGRESS_OFF=1 in the environment.
#
# I/O Contract (PreToolUse): {} allows; permissionDecision deny blocks. Exit 0 always.

. "$HOME/.claude/hooks/lib/hook-common.sh"

SCAN="$HOME/.claude/scripts/leak-guard/scan-content.sh"

input=$(cat)

[ "${EGRESS_OFF:-}" = "1" ] && hook_allow
[ -x "$SCAN" ] || hook_allow   # scanner absent: this hook is advisory, not the last line

payload=$(printf '%s' "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); raise SystemExit
ti = d.get('tool_input') or {}
name = d.get('tool_name', '')
# Read-only navigation to a URL is not egress of Owner data; the risk is what we SEND.
# Serialise every value so a new MCP server's argument shape is covered without a rule.
def walk(v, out):
    if isinstance(v, dict):
        for k, x in v.items():
            walk(x, out)
    elif isinstance(v, list):
        for x in v:
            walk(x, out)
    elif isinstance(v, str):
        out.append(v)
out = []
walk(ti, out)
print(name + '\n' + '\n'.join(out))
" 2>/dev/null)

[ -z "$payload" ] && hook_allow

if printf '%s' "$payload" | bash "$SCAN" egress >/tmp/egress-scan.$$ 2>&1; then
  rm -f /tmp/egress-scan.$$
  hook_allow
fi

detail=$(grep -m2 -E '^\s*\[BLOCK\]|BLOCKED' /tmp/egress-scan.$$ 2>/dev/null | tr '\n' ' ' | cut -c1-200)
rm -f /tmp/egress-scan.$$
hook_deny "EGRESS GUARD: o payload desta chamada carrega dado sensivel e sairia da maquina. ${detail}. Remova o dado, ou se for falso-positivo: EGRESS_OFF=1. Este guard usa o mesmo scanner do commit."
