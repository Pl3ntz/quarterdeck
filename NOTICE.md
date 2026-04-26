# NOTICE — Third-Party Components

Quarterdeck contains code authored by Pl3ntz (MIT, see `LICENSE`) **and** code
vendored from third parties under their original licenses. This file maps which
files are governed by which license.

## Vendored from `borghei/Claude-Skills`

- Upstream: https://github.com/borghei/Claude-Skills
- Vendored at fork date: **2026-04-26**

| Path | Original License | Notes |
|---|---|---|
| `skills/skill-security-auditor/` | MIT + Commons Clause | unmodified (license header preserved) |
| `scripts/borghei/claudemd_optimizer.py` | MIT (per `claude-code-mastery/SKILL.md`) | unmodified |
| `scripts/borghei/context_analyzer.py` | MIT (per `claude-code-mastery/SKILL.md`) | unmodified |
| `scripts/improvement/rule_promoter.py` | MIT + Commons Clause | HARDENED with sanitizer + candidate-only output + TTY confirm. Original at `rule_promoter.py.original` |
| `scripts/improvement/memory_health_checker.py` | MIT + Commons Clause | unmodified |

### Evaluated and removed

The following components were vendored, evaluated, and removed during the same audit because they did not deliver enough value to justify their maintenance footprint:

- `skills/skill-tester/` — schema mismatch with our skill conventions (most local skills don't follow borghei's tier system). Cherry-picked dual-mode validator patch is preserved for reference only.
- `skills/tech-debt-tracker/` — overlaps with the `staff-engineer` agent (Opus), which produces context-aware debt analysis without per-project threshold tuning.

## Commons Clause — what it means

The **Commons Clause** is a non-OSI restriction added on top of MIT. It does **not** restrict use, modification, or non-commercial redistribution. It **does** restrict selling the software or selling a service whose value derives substantially from the software.

For Quarterdeck (open-source, no fee, no SaaS bundling), this means:

- You can clone Quarterdeck and use these skills personally.
- You can fork Quarterdeck and contribute modifications.
- You can mirror Quarterdeck publicly.
- You **cannot** sell a product/service whose value derives substantially from the borghei-licensed parts.

If you build a commercial product, replace the Commons-Clause-licensed components first.

## License layout

```
quarterdeck/
├── LICENSE                                  # MIT (root, applies to everything not listed below)
├── NOTICE.md                                # this file
├── agents/, rules/, hooks/, commands/, docs/  # MIT (Pl3ntz)
├── scripts/                                 # MIT EXCEPT subdirectories below
└── third-party with separate LICENSE files:
    ├── skills/skill-security-auditor/        # MIT + Commons Clause (in SKILL.md frontmatter)
    ├── scripts/borghei/LICENSE               # MIT (claude-code-mastery)
    └── scripts/improvement/LICENSE           # MIT + Commons Clause (self-improving-agent)
```

## Modifications log (Pl3ntz, 2026-04-26)

1. **`scripts/improvement/rule_promoter.py`** — Added `sanitize_rule_text()` rejecting prompt-injection markers, dangerous shell tokens, non-https URLs, shell-language code fences, and oversized text. Changed `apply_promotion()` default target to `candidates` (writes to a review file the operator inspects manually) instead of direct write to `CLAUDE.md` / `rules/`. Direct writes now require an interactive TTY confirmation. Reason: original was a memory-poisoning vector — a poisoned `MEMORY.md` entry could be promoted to a permanent rule without sanitization. Original preserved at `rule_promoter.py.original`.

## Attribution

Thanks to **borghei** (https://github.com/borghei) for publishing the Claude-Skills repository as open source. Selected components were vendored into Quarterdeck because they fit gaps in the existing 26-agent stack. The hardening modifications above address security findings during Quarterdeck's pre-adoption audit; the underlying detection logic and overall design remain borghei's work.
