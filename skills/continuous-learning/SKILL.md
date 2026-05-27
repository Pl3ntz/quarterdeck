---
name: continuous-learning
description: Automatically extract reusable patterns from Claude Code sessions and save them as learned skills for future use.
---

# Continuous Learning Skill

Extracts reusable patterns from sessions and integrates with the Auto-Learning error memory system.

## How It Works

This skill connects two systems:

1. **Error Memory** (automatic): The `detect-errors.sh` PostToolUse hook captures Bash errors to `~/.claude/logs/error-events.jsonl`. The PE captures fixes to `error-resolutions.jsonl` and maintains the `error-index.md` curated index.

2. **Pattern Extraction** (manual/session-end): The PE extracts reusable tips from sessions per Section 13 (Self-Improvement) and reviews unresolved errors per Section 14 (Auto-Learning).

## Usage

### Mid-Session: `/learn`

Manually trigger pattern extraction at any point:

```
/learn
```

This instructs the PE to:
1. Review the current session for reusable patterns
2. Check `error-events.jsonl` for unresolved errors that were fixed
3. Write tips to the appropriate topic file in `~/.claude/projects/*/memory/`
4. Update `error-index.md` with any resolved errors

### Session End: Automatic Review

At session end, the PE follows Section 13 + 14 to:
1. Extract strategy/recovery/optimization tips
2. Resolve any unlogged error-fix pairs
3. Promote recurring patterns (3+ occurrences) to permanent rules

## Files

| File | Purpose |
|------|---------|
| `~/.claude/logs/error-events.jsonl` | Raw error events (written by hook) |
| `~/.claude/logs/error-resolutions.jsonl` | Fix descriptions (written by PE) |
| `~/.claude/logs/error-index.md` | Curated index, max 10/category (maintained by PE) |
| `~/.claude/projects/*/memory/tips-*.md` | Topic-specific tips (written by PE) |

## Configuration

Edit `config.json` to customize pattern detection:

```json
{
  "min_session_length": 10,
  "patterns_to_detect": [
    "error_resolution",
    "user_corrections",
    "workarounds",
    "debugging_techniques",
    "project_specific"
  ],
  "ignore_patterns": [
    "simple_typos",
    "one_time_fixes",
    "external_api_issues"
  ]
}
```

## Related

- PE Section 13: Self-Improvement Protocol (tip extraction)
- PE Section 14: Auto-Learning Protocol (error memory)
- `/learn` command: Manual mid-session extraction
