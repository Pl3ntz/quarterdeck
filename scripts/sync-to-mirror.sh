#!/usr/bin/env bash
# sync-to-mirror — copy a file from the live ~/.claude config into the public quarterdeck
# mirror, but refuse when the copy would carry a real infrastructure identifier.
#
# Why this exists: the mirror keeps scrubbed variants of some lines (`ssh your-server`
# where the live rule says the actual host). A plain `cp` silently reintroduces the real
# identifier, and it only gets caught later by the pre-commit leak guard -- twice on
# 2026-07-24 in the same file. This makes the check happen at copy time, where the fix is
# cheap, instead of at commit time, where the file has already been overwritten.
#
# Usage:
#   sync-to-mirror.sh rules/performance.md
#   sync-to-mirror.sh rules/performance.md agents/code-reviewer.md
#
# Paths are relative to both ~/.claude/ and the mirror root. Exit 1 if any file was
# rejected; nothing is written for a rejected file, so the mirror's scrubbed version
# survives.

set -uo pipefail

SRC_ROOT="$HOME/.claude"
MIRROR_ROOT="${QUARTERDECK_ROOT:-$HOME/dev/quarterdeck}"
SCAN="$HOME/.claude/scripts/leak-guard/scan-content.sh"
DIVERGENT="${MIRROR_DIVERGENT_LIST:-$HOME/.claude/local/mirror-divergent.txt}"

[ $# -gt 0 ] || { echo "usage: $(basename "$0") <path-relative-to-.claude> [...]" >&2; exit 2; }
[ -d "$MIRROR_ROOT" ] || { echo "mirror not found: $MIRROR_ROOT" >&2; exit 2; }
[ -x "$SCAN" ] || { echo "leak scanner missing: $SCAN" >&2; exit 2; }

failed=0

for rel in "$@"; do
  src="$SRC_ROOT/$rel"
  dst="$MIRROR_ROOT/$rel"

  if [ ! -f "$src" ]; then
    echo "SKIP  $rel (not in $SRC_ROOT)" >&2
    failed=1
    continue
  fi

  # Some mirror files are deliberately NOT copies: translated, or scrubbed of identifiers
  # and figures that only belong in the private config. Copying over them destroys that
  # work silently, which is how the sanitized English performance.md was clobbered once.
  if [ -f "$DIVERGENT" ] && grep -qxF "$rel" "$DIVERGENT" 2>/dev/null; then
    echo "BLOCK $rel -- the mirror copy is deliberately divergent (see $DIVERGENT)." >&2
    echo "      Edit $MIRROR_ROOT/$rel directly; do not copy over it." >&2
    failed=1
    continue
  fi

  # Scan the SOURCE before writing. A rejected file leaves the mirror untouched.
  if ! scan_out=$(bash "$SCAN" "$rel" < "$src" 2>&1); then
    echo "BLOCK $rel -- would leak a real identifier into the public mirror:" >&2
    printf '%s\n' "$scan_out" | sed 's/^/      /' >&2
    if [ -f "$dst" ]; then
      echo "      mirror copy left as-is; reconcile by hand (it likely holds a scrubbed variant)" >&2
    fi
    failed=1
    continue
  fi

  mkdir -p "$(dirname "$dst")"
  if cp "$src" "$dst"; then
    echo "OK    $rel"
  else
    echo "FAIL  $rel (copy failed)" >&2
    failed=1
  fi
done

exit $failed
