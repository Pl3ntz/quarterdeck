---
description: Manage your continuous learning personality profile (list/distill/forget/reset/inspect)
---

# /personality — Personality Profile Manager

You are managing the continuous learning system. Parse the user's argument and take the appropriate action.

## Subcommands

| Command | Action |
|---|---|
| `/personality` (no args) | Show current profile + summary stats |
| `/personality list` | List all raw patterns from patterns.jsonl |
| `/personality distill` | Run distill-patterns.py to regenerate profile.md |
| `/personality distill --confidence N` | Distill with custom confidence threshold |
| `/personality forget <text>` | Remove patterns matching text from patterns.jsonl |
| `/personality reset` | Wipe all learning data (requires confirmation) |
| `/personality stats` | Show counts by signal type, scope, and recency |
| `/personality inspect <signal>` | Show all patterns of a specific signal type |

## Implementation Steps

### Step 1: Parse the argument

Read the user's argument after `/personality`. Default to "show" if empty.

### Step 2: Execute the requested action

**show (default):**
- Read `~/.claude/learning/profile.md` and display it
- Read `~/.claude/learning/patterns.jsonl` and show count + last 5 entries
- If a project profile exists at `.claude/learning/profile.md` in cwd, show it too

**list:**
- Read `~/.claude/learning/patterns.jsonl`
- Display as a table: timestamp | signal | scope | prompt (truncated to 80 chars)

**distill:**
- Run: `python3 ~/.claude/scripts/distill-patterns.py [args]`
- Show the output and confirm the profile.md was regenerated
- Display the new profile to the user

**forget <text>:**
- Read patterns.jsonl
- Filter out lines whose `prompt` field contains `<text>` (case-insensitive)
- Write back the filtered file
- Report how many entries were removed
- Suggest running `/personality distill` to regenerate the profile

**reset:**
- ASK FOR CONFIRMATION first ("Esta ação vai apagar TODOS os padrões aprendidos. Confirma?")
- If confirmed: empty patterns.jsonl, regenerate profile.md from scratch
- Show summary of what was deleted

**stats:**
- Read patterns.jsonl
- Count by signal type, by scope (global/project), by age (last 24h, 7d, 30d)
- Display as a compact table

**inspect <signal>:**
- Read patterns.jsonl
- Filter by signal type (anti_pattern, preference, correction, memory, style)
- Display all matching entries with full text

## Files

- Global patterns: `~/.claude/learning/patterns.jsonl`
- Global profile: `~/.claude/learning/profile.md`
- Project patterns: `~/.claude/projects/<project-id>/learning/patterns.jsonl`
- Project profile: `~/.claude/projects/<project-id>/learning/profile.md`
- Distillation script: `~/.claude/scripts/distill-patterns.py`
- Capture hook: `~/.claude/hooks/capture-patterns.sh`
- Injection hook: `~/.claude/hooks/inject-personality.sh`

## Output rules

- Always respond in pt-BR
- Use tables for listings
- For destructive operations (forget, reset), ALWAYS confirm before executing
- After any change, suggest the next logical action
- Keep output concise — use truncation when listing many items

## Example flows

**User: `/personality`**
→ Show profile.md + last 5 patterns + stats summary

**User: `/personality forget Bun`**
→ Remove all patterns mentioning "Bun" → confirm count → suggest `/personality distill`

**User: `/personality reset`**
→ "Confirma reset completo?" → wait → execute → show clean state
