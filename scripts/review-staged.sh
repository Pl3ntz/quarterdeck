#!/usr/bin/env bash
# review-staged — run code-reviewer and security-reviewer over the staged diff and record
# the result, keyed by the hash of that exact diff.
#
# This is the half that costs LLM calls. It runs when you choose, not on commit, which is
# why review-gate.sh can afford to be a deterministic instant check: the gate never reviews
# anything, it only verifies that this diff was reviewed.
#
# The two agents run headlessly via `claude -p --agent <name>`, so the main thread IS the
# reviewer -- no subagent spawn, no orchestration, and the agent's own frontmatter model
# applies (security-reviewer stays on Opus, which measured 5/5 on injection where Sonnet
# flickered at 1/3).
#
# Usage: review-staged.sh [repo]        defaults to the current repo
#
# Report: ~/.claude/reviews/<repo>/<diff-hash>.md

set -uo pipefail

REVIEW_HOME="${REVIEW_HOME:-$HOME/.claude/reviews}"
CODE_RE='\.(py|ts|tsx|js|jsx|go|rs|rb|java|kt|swift|c|h|cpp|cs|php|sh|bash|sql|tf|ex|exs)$'

root=$(git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null) || {
  echo "review-staged: not a git repo" >&2; exit 2; }
name=$(basename "$root")

staged=$(git -C "$root" diff --cached --name-only | grep -E "$CODE_RE")
if [ -z "$staged" ]; then
  echo "review-staged: no staged code files -- nothing to review" >&2
  exit 0
fi

diff_text=$(git -C "$root" diff --cached -- $(echo "$staged" | tr '\n' ' '))
hash=$(printf '%s' "$diff_text" | shasum -a 256 | cut -c1-16)
out_dir="$REVIEW_HOME/$name"
out="$out_dir/$hash.md"
mkdir -p "$out_dir"

if [ -f "$out" ]; then
  echo "review-staged: this exact diff was already reviewed -> $out" >&2
  exit 0
fi

echo "review-staged: reviewing $(echo "$staged" | wc -l | tr -d ' ') file(s), diff $hash" >&2

prompt="Review the staged diff below. Report only what is wrong, with severity tags.
Do not restate the diff. If nothing is wrong at your severity threshold, say so in one line.

--- staged diff ---
$diff_text"

run_agent() {
  # A reviewer that errors must not read as a clean review, so failures are recorded
  # as text in the report and the gate treats a missing section as unreviewed.
  local agent="$1"
  if ! claude -p --agent "$agent" "$prompt" < /dev/null 2>/dev/null; then
    echo "[review-staged] agent '$agent' failed to produce output"
  fi
}

{
  echo "# Review — $name"
  echo
  echo "- **Diff:** \`$hash\`"
  echo "- **Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- **Files:**"
  echo "$staged" | sed 's/^/  - /'
  echo
  echo "## security-reviewer"
  echo
  run_agent security-reviewer
  echo
  echo "## code-reviewer"
  echo
  run_agent code-reviewer
} > "$out"

echo "review-staged: written to $out" >&2
grep -oE '\[(CRITICAL|HIGH|MEDIUM|LOW)\]' "$out" | sort | uniq -c | sed 's/^/  /' >&2 || true
