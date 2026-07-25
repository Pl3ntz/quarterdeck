# Frontend Baseline Viewport

**Design for 1440×900 first, then scale up.** That is a MacBook Air 13" at default scaling,
which is the machine the Owner actually reviews on. It is the floor of "desktop", not the
ceiling.

Applies to layouts, components, E2E viewports, Lighthouse runs and any visual audit: use
1440×900 as the primary scenario, and report issues that only appear at other sizes
separately.

Two consequences that are easy to get wrong:

- **The fold is ~820px**, not 900 — browser chrome eats the rest. Anything that must be
  seen without scrolling has to fit there.
- **Wider screens get more, never less.** Breakpoints above 1440 may expand the grid or add
  a column; the baseline layout must not depend on that space existing.

Mobile and tablet are separate adaptations, not the base. If the project is genuinely
mobile-first, kiosk, TV or targets an external monitor, confirm with the Owner before
applying this.
