# Expected Findings — ux-reviewer

8 seeded UX/accessibility issues across the fixture (`test-ui.tsx`), mixing
obvious and subtle. Keywords favour the code tokens / WCAG concepts the agent
cites, so matching is language-agnostic (agent prose may be EN or PT-BR).

**Note on detection ceiling:** ux-reviewer's output contract caps at ~150 tokens
(top findings only), so it will not exhaustively list all 8. The signal to read
is **stability** — which of the critical issues it surfaces on *every* run — not
raw recall. Blind/fluctuating on lower-severity rows is often budget truncation,
not a true blind spot.

| # | Line | Type | Severity | Keywords | Difficulty |
|---|---|---|---|---|---|
| img-missing-alt | 24 | missing alt text | HIGH | img; alt; decorative; 1.1.1 | obvious |
| div-onclick-not-button | 30 | non-native interactive | HIGH | div; onClick; button; keyboard | obvious |
| input-no-label | 35 | input without label | HIGH | input; label; placeholder; 3.3.2 | obvious |
| password-block-paste | 51 | paste blocked on password | HIGH | onPaste; preventDefault; password; autocomplete | subtle |
| error-color-only | 55 | color-only error indicator | MEDIUM | color; red; error; icon | subtle |
| icon-button-no-name | 58 | icon button no accessible name | HIGH | aria-label; icon; button; svg | obvious |
| touch-target-too-small | 66 | touch target under 24px | MEDIUM | touch target; 24; size; 2.5.8 | subtle |
| dialog-no-focus-mgmt | 71 | modal missing focus management | HIGH | role; dialog; focus; showModal | subtle |

## Scope

These are the only intended issues. A finding matching none of these rows (by
keyword overlap near the cited line) counts as a false positive. Pure code-quality
findings (types, naming) are out of ux-reviewer's scope and, if reported, are
false positives here.
