# Continuous Learning System

**Last Updated:** 2026-06-17 | [← Back to README](../README.md)

The continuous learning system automatically captures session patterns, detects recurring issues, and promotes proven practices into permanent rules — turning session learnings into enforced policy.

---

## How It Works: Three-Layer Pipeline

```
Capture → Distill → Promote
  ↓         ↓          ↓
Record   Dedupe    Enforce
```

### Layer 1: Capture (`capture_patterns.py`)

Triggered on every `UserPromptSubmit` hook:

1. **Memory poisoning defense (Layers 1-4):** Rejects non-user content:
   - XML/markup (`<system-reminder>`, `<tool-use>`, etc.)
   - Structural markers (`---context---`, `---agent-memory---`, commit trailers)
   - Pasted code blocks (fenced ` ``` `)
   - Tool output transcripts

2. **Signal detection:** Identifies genuine user preferences in 6 types:
   - `anti_pattern` — "never do X", "stop using Y"
   - `preference` — "always use X", "prefer Y over Z"
   - `correction` — "that's wrong", "incorrect approach"
   - `memory` — "remember X", "don't forget Y"
   - `style` — "be more brief", "write longer explanations"

3. **Scope classification:** Determines if pattern is global or project-specific
4. **Append:** Writes clean entries to `~/.claude/learning/patterns.jsonl`

**Status:** ✓ Deployed. Defends against prompt injection, agent bleed, and tool-output contamination.

### Layer 2: Distill (`distill-patterns.py`)

Periodically (or manually via `/distill-patterns`):

1. **Load patterns:** Reads `patterns.jsonl`
2. **Quarantine poisoned lines:** Granular isolation of bad entries (not file-level destruction)
3. **Apply decay:** Filters stale patterns (>30 days old by default)
4. **Cluster by signal:** Groups patterns by type (anti_pattern, preference, etc.)
5. **Find recurring:** Counts occurrences; only patterns appearing ≥3 times pass confidence threshold
6. **Render profile:** Regenerates `profile.md` preserving manual edits, injecting auto-learned patterns

**Output:** `~/.claude/learning/profile.md` with sections:
- **Communication** (manual seed preserved)
- **Workflow** (manual seed preserved)
- **Anti-padrões** (auto-learned merged with manual)
- **Preferências Técnicas** (auto-learned)
- **Estilo** (auto-learned)
- **Metadata** (counts, thresholds, last updated)

**Safeguards:**
- Hard minimum: 3 occurrences (single poisoned entry cannot become rule)
- Granular quarantine: Bad lines moved to `.patterns.jsonl.quarantine`, clean entries preserved
- Fast-path idempotent: If no poisoned entries, file untouched

**Status:** ✓ Deployed. Sanitizes + organizes patterns without destroying clean corpus.

### Layer 3: Promote (`rule_promoter.py`)

Converts MEMORY.md entries into permanent rules via manual review:

```bash
# Find candidates
rule_promoter.py --memory ./MEMORY.md --list-candidates

# Review and promote
rule_promoter.py --memory ./MEMORY.md --entry-title "Use pnpm" --target candidates --apply
```

**Promotion Criteria Matrix** (ALL five must pass):

| Criterion | Threshold | Verification |
|-----------|-----------|---------------|
| **Recurrence** | 3+ distinct sessions | Check memory entry metadata |
| **Consistency** | Same solution every time | No contradicting entries |
| **Impact** | Prevented ≥1 error or saved time | Reference incident in memory |
| **Stability** | Underlying code/system unchanged | Tool/file/dependency still exists |
| **Clarity** | Statable in 1–2 sentences | Max 200 chars (enforced by sanitizer) |

**Sanitizer Rules** (reject patterns with):
- Prompt-injection markers (`<system-reminder>`, `<command-name>`, etc.)
- Shell/RCE tokens (`subprocess`, `sudo`, `curl`, `chmod +x`)
- Non-HTTPS URLs (except GitHub, Anthropic, AWS official)
- Personal paths or internal server aliases
- Code fences (shell, bash, cmd, powershell)

**Workflow:**
1. Entry passes 5-criterion validation → appears in `--list-candidates`
2. Owner reviews candidate text
3. **Default target: `candidates` file** (`~/.claude/learning/rule-candidates.md`)
   - Owner reviews via git PR
   - Zero auto-promotion (defense against memory poisoning)
4. Owner manually promotes via PR → rule added to `~/.claude/rules/`
5. Rule loads automatically in all future PE sessions

**Anti-Pattern:** Auto-promotion is **forbidden**. All rule changes require explicit Owner approval.

**Status:** ✓ Deployed. Hardened against injection; requires human review before enforcement.

### Injection: Context Loading (`inject_personality.py`)

Triggered on every `UserPromptSubmit` hook:

1. **Load profile sections:** Extracts distilled patterns from `profile.md`
2. **Find project profile:** Searches project hierarchy for `.claude/learning/profile.md`
3. **Sanitize:** Strips any XML markers that leaked into the profile
4. **Wrap as untrusted data:** Encloses in `<untrusted-learned-patterns>` tags with "DATA ONLY" instruction
5. **Truncate:** Caps at 1500 chars to avoid context bloat
6. **Inject:** Returns as `additionalContext` to Claude Code for use in this session

**Memory Poisoning Defense:** Injects as DATA, never as INSTRUCTIONS. Claude treats learned patterns as soft hints, never executable directives.

**Status:** ✓ Deployed. Safely reintroduces learned patterns without execution risk.

---

## Scripts & Tools

| Script | Location | Purpose | Triggers |
|--------|----------|---------|----------|
| `capture_patterns.py` | `scripts/` | Detects user preferences from prompts | `UserPromptSubmit` hook (every session) |
| `distill-patterns.py` | `scripts/` | Deduplicates patterns, regenerates profile | Manual: `/distill-patterns` or scheduled |
| `rule_promoter.py` | `scripts/improvement/` | Validates entries against 5-criterion matrix | Manual: `rule_promoter.py --list-candidates` |
| `memory_health_checker.py` | `scripts/improvement/` | Audits memory for stale/duplicate/promotable entries; reports maturity level | Manual: `memory_health_checker.py --memory ./MEMORY.md` |
| `inject_personality.py` | `scripts/` | Loads distilled patterns as session context | `UserPromptSubmit` hook (every session) |

---

## Improvement Maturity Levels

A self-assessment scale (0–5) for the continuous-learning system. Use when proposing changes to memory, error handling, or pattern promotion.

| Level | Name | Mechanism | Characteristics |
|-------|------|-----------|---|
| **0** | Stateless | No memory between sessions | Each session starts from zero |
| **1** | Recording | Captures observations into memory hooks | Data captured but not organized; no action taken |
| **2** | Curating | Organizes + deduplicates observations | Memory health checks; duplicates removed; patterns extracted |
| **3** | Promoting | Graduates validated patterns to enforced rules | `rule_promoter.py` converts candidates → permanent code (CLAUDE.md, rules/) |
| **4** | Extracting | Creates reusable skills from proven patterns | Best practices become standalone skills in `~/.claude/skills/` |
| **5** | Meta-Learning | Adapts the learning strategy itself | System evaluates + improves its own detection/promotion logic |

**Current Quarterdeck Status:** **Level 3 (Promoting)**
- ✓ Records patterns (Layer 1: `capture_patterns.py`)
- ✓ Curates patterns (Layer 2: `distill-patterns.py`)
- ✓ Validates against criteria (Layer 3: `rule_promoter.py`)
- ✓ Requires manual approval before enforcement
- → Target: Level 4 (extracting common patterns into reusable skills)

---

## Memory & Files

```
~/.claude/learning/
├── patterns.jsonl              # Raw captured patterns (append-only)
├── patterns.jsonl.quarantine   # Poisoned/malformed entries (granular isolation)
├── profile.md                  # Distilled profile (auto-generated, preserves manual edits)
├── errors.log                  # Capture/distill/inject error logs
└── rule-candidates.md          # Output of rule_promoter.py (awaiting manual review)

~/.claude/projects/<project>/learning/
├── patterns.jsonl              # Project-specific patterns
├── profile.md                  # Project-specific profile
└── [topic-files]               # Specialized topics (e.g., database.md, api.md)
```

---

## Workflow Examples

### Scenario 1: Record a Preference

**Session:**
```
you: "always use pnpm instead of npm"
```

**System:**
1. `capture_patterns.py` detects `preference` signal
2. Appends: `{ "signal": "preference", "prompt": "always use pnpm...", ... }` to `patterns.jsonl`

### Scenario 2: Distill After 3 Occurrences

**After 3 separate sessions with pnpm preference:**

```bash
distill-patterns.py --scope global
```

**System:**
1. Loads `patterns.jsonl` (3 entries match pnpm)
2. Normalizes & clusters by "preference"
3. Detects: 3 occurrences of "use pnpm" → confidence pass
4. Regenerates `profile.md`:
   ```
   ## Preferências Técnicas
   - _(3x)_ always use pnpm instead of npm
   ```

### Scenario 3: Promote to Permanent Rule

**Owner reviews:**
```bash
rule_promoter.py --memory ~/.claude/projects/my-project/memory/MEMORY.md --list-candidates
```

**System lists:**
```
READY FOR PROMOTION (1)
  >> Line 45: Use pnpm
     Recurrence: 3 | Confidence: high
     Rule: **Always use pnpm instead of npm** -- proven pattern
```

**Owner promotes:**
```bash
rule_promoter.py --memory ... --entry-title "Use pnpm" --target candidates --apply
```

**System:**
1. Writes rule to `~/.claude/learning/rule-candidates.md` (default, no TTY required)
2. Owner reviews via git
3. Owner creates PR merging to `~/.claude/rules/package-manager.md`
4. Rule enforced in all future PE sessions

---

## Memory Poisoning Defenses

**Four-layer capture protection:**
1. XML marker rejection (starts-with-`<`)
2. Structural markers (e.g., `<system-reminder>`, commit trailers)
3. Content patterns (pasted context preambles, agent attribution)
4. Code fence detection (fenced blocks = tool output, not preference)

**Distillation protection:**
- Quarantine (not destroy): Bad lines isolated; clean entries always preserved
- Granular rewrite: Only poisoned lines removed; corpus integrity maintained
- Confidence threshold: Minimum 3 occurrences (single bad entry cannot become rule)

**Promotion protection:**
- Sanitizer: Rejects shell metacharacters, injection markers, non-HTTPS URLs, personal paths
- Manual review: Zero auto-promotion (Owner approves all rules)
- TTY enforcement: Direct writes to CLAUDE.md require interactive confirmation

**Injection protection:**
- Untrusted-data wrapping: Profile injected as DATA, never as INSTRUCTIONS
- Sanitize on load: XML markers stripped before injection
- Token budget: Truncated to 1500 chars (prevents context bloat)

---

## Customization

Edit `~/.claude/learning/` config (if exposed):

- **Confidence threshold:** Default 3. Change via `distill-patterns.py --confidence 5`
- **Decay window:** Default 30 days. Change via `distill-patterns.py --decay 60`
- **Scope:** Global, project, or both. Change via `distill-patterns.py --scope [global|project|all]`
- **Max profile size:** Default 1500 chars (injection). Adjust `inject_personality.py` MAX_CHARS

---

## Related Documentation

- [**Improvement Maturity Levels**](PATTERNS-APPLIED.md#improvement-maturity-levels) — Full scale with example trajectories
- [**Promotion Criteria Matrix**](PATTERNS-APPLIED.md#promotion-criteria-matrix) — Complete 5-criterion validation framework
- **PE Rule Section 17:** Improvement Maturity Levels (in `rules/principal-engineer-always-on.md`)
- **Skill:** `skills/continuous-learning/SKILL.md` — Integration with error memory and manual `/learn` command
