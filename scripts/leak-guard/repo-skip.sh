#!/usr/bin/env bash
# repo-skip.sh — exit 0 if the current git repo is on the leak-guard skip list.
#
# The skip list (~/.claude/local/leak-guard-skip-repos.txt) holds path PREFIXES of
# PRIVATE repos where real infra/company/project identifiers legitimately live and
# are ALREADY committed upstream. The whole-blob scan would only produce false-
# positive blocks on those pre-existing names, so the guard skips such repos.
# Public repos are NEVER on this list.
#
# Exit 0 = skip (repo allow-listed). Exit 1 = do NOT skip (scan normally).
# Missing/unreadable list => exit 1 (fail-safe: keep scanning).
set -uo pipefail

SKIP="${LEAKGUARD_SKIP_REPOS:-$HOME/.claude/local/leak-guard-skip-repos.txt}"
[[ -r "$SKIP" ]] || exit 1

top="$(command git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$top" ]] || exit 1

while IFS= read -r line; do
  line="${line%%#*}"                       # strip trailing comment
  line="${line#"${line%%[![:space:]]*}"}"  # ltrim
  line="${line%"${line##*[![:space:]]}"}"  # rtrim
  [[ -z "$line" ]] && continue
  line="${line%/}"                         # normalize trailing slash
  if [[ "$top" == "$line" || "$top" == "$line"/* ]]; then
    exit 0
  fi
done < "$SKIP"

exit 1
