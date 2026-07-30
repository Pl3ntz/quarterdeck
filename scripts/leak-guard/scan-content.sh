#!/usr/bin/env bash
# scan-content.sh — read text on stdin, run every leak-guard layer, aggregate.
#
# Layers:
#   1. custom  pii_secrets_scan.py  (pt-BR PII validated + known-prefix secrets)  [fail-closed]
#   2. gitleaks stdin                (generic/entropy secrets)                     [optional]
#   3. denylist quarterdeck leak-scan.sh (real infra/company/project identifiers)  [fail-closed]
#
# Exit 0 = clean.
# Exit 1 = HARD: a credential or validated PII, or a mandatory layer could not run.
# Exit 2 = DENYLIST ONLY: a private-identifier pattern matched, nothing else.
#
# The two are separated because callers treat them differently. A repo may be configured to
# only ADVISE on denylist hits -- project names and hosts produce false positives by design, and
# blocking them froze real work. A credential is never a false positive of that kind, so exit 1
# is not downgradable by anyone. Collapsing both into 1, which is what this returned until
# 2026-07-30, meant that turning off the noisy layer turned off the sharp one with it: an AWS
# key committed clean to ten public repos.
#
# FAIL-CLOSED: if a mandatory layer's script is missing, this returns 1, not 2.
#
# Usage:  <text> | scan-content.sh [LABEL]
set -uo pipefail

GUARD_DIR="$HOME/.claude/scripts/leak-guard"
PII="$GUARD_DIR/pii_secrets_scan.py"
DENY_SCAN="$HOME/.claude/scripts/quarterdeck-guard/leak-scan.sh"
LABEL="${1:-}"

input="$(cat)"
[[ -z "$input" ]] && exit 0

hard_rc=0   # credential / validated PII / a mandatory layer that could not run
deny_rc=0   # private-identifier patterns only

# ── Layer 1: custom PII + known-prefix secrets (MANDATORY, fail-closed) ──────
if [[ -r "$PII" ]]; then
  printf '%s\n' "$input" | python3 "$PII" --source "$LABEL" || hard_rc=1
else
  echo "leak-guard: FATAL custom scanner missing: $PII — BLOCKING (fail-closed)" >&2
  hard_rc=1
fi

# ── Layer 2: gitleaks (OPTIONAL — warn if absent, do not block on absence) ───
if command -v gitleaks >/dev/null 2>&1; then
  gl_out="$(printf '%s\n' "$input" | gitleaks stdin --redact --no-banner 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "  [BLOCK] gitleaks flagged secret(s):" >&2
    printf '%s\n' "$gl_out" | grep -iE "Finding|RuleID|Secret|Line" | sed 's/^/    /' | head -24 >&2
    hard_rc=1
  fi
else
  echo "leak-guard: NOTE gitleaks not installed — custom+denylist only (brew install gitleaks)" >&2
fi

# ── Layer 3: denylist of real identifiers (MANDATORY, fail-closed inside) ────
if [[ -x "$DENY_SCAN" ]]; then
  printf '%s\n' "$input" | "$DENY_SCAN" || deny_rc=1
else
  echo "leak-guard: FATAL denylist scanner missing: $DENY_SCAN — BLOCKING (fail-closed)" >&2
  hard_rc=1
fi

# Hard wins: a caller that downgrades denylist hits must still see the credential.
[ "$hard_rc" -ne 0 ] && exit 1
[ "$deny_rc" -ne 0 ] && exit 2
exit 0
