#!/bin/bash
# Authorship Guard — PreToolUse hook on Bash.
#
# Refuses a commit, PR or issue whose text credits an AI tool, or carries emoji.
#
# Both are standing conventions here, and both had been enforced by nothing. A convention
# that lives only in a rules file gets followed until the moment someone is moving fast,
# which is exactly when it matters: the repo already carried a commit removing em dashes from
# prose, and they came back the same week.
#
# Covers what a git hook cannot see. The leak-guard commit-msg hook reads the message file,
# so it catches `git commit` regardless of how the message was written, but a pull request
# body never touches git at all -- it goes straight to the API through `gh`. This reads the
# command as composed, which catches -m, -F with a heredoc, and every gh subcommand that
# takes a body.
#
# What it does NOT catch: `git commit` with no message flag, where the text is typed into an
# editor afterwards. The commit-msg hook covers that case.
#
# Escape hatch: AUTHORSHIP_OFF=1
#
# I/O Contract (PreToolUse): {} allows; permissionDecision deny blocks. Exit 0 always.

. "$HOME/.claude/hooks/lib/hook-common.sh"

input=$(cat)
command=$(hook_command "$input")
[ -z "$command" ] && hook_allow

echo "$command" | grep -qE '(^|&&|;|\|)\s*(git\s+commit|gh\s+(pr|issue)\s+(create|edit|comment)|gh\s+release\s+create)\b' || hook_allow
hook_override_requested "$command" "AUTHORSHIP_OFF" && hook_allow

verdict=$(COMMAND="$command" python3 <<'PY'
import os, re, sys

cmd = os.environ.get("COMMAND", "")

# Attribution to the tool. Deliberately narrow: the words themselves are legitimate subject
# matter in this repo, so only credit-shaped phrasing counts.
attribution = [
    (r"co-authored-by:\s*claude", "Co-Authored-By: Claude"),
    (r"generated\s+with\s+\[?claude", "Generated with Claude"),
    (r"(?:written|created|authored|made|built)\s+(?:with|by)\s+claude\b", "authored with Claude"),
    (r"noreply@anthropic\.com", "anthropic noreply address"),
    (r"🤖\s*generated", "robot + Generated"),
    (r"\bclaude\s+code\s+(?:wrote|generated|authored)\b", "Claude Code wrote"),
]
for rx, label in attribution:
    if re.search(rx, cmd, re.I):
        print("ATTRIB\t" + label)
        raise SystemExit

# Emoji. Pictographs, dingbats, symbols and flags -- not accented Latin, not box drawing,
# and not the middle dot or arrows used in ordinary technical prose.
EMOJI = re.compile(
    "[\U0001F300-\U0001FAFF"   # pictographs, symbols, supplemental
    "\U0001F1E6-\U0001F1FF"    # regional indicators (flags)
    "☀-➿"            # misc symbols and dingbats
    "️⭐⭕]"      # variation selector, star, circle
)
found = EMOJI.findall(cmd)
if found:
    print("EMOJI\t" + " ".join(sorted(set(found))[:6]))
PY
)

case "$verdict" in
  ATTRIB*)
    hook_deny "AUTHORSHIP GUARD: o texto credita a ferramenta ($(printf '%s' "$verdict" | cut -f2)). Commits e PRs aqui nao levam atribuicao de IA. Remova a linha. Override: AUTHORSHIP_OFF=1"
    ;;
  EMOJI*)
    hook_deny "AUTHORSHIP GUARD: emoji no texto do commit/PR ($(printf '%s' "$verdict" | cut -f2)). A convencao aqui e prosa sem emoji. Override: AUTHORSHIP_OFF=1"
    ;;
esac

hook_allow
