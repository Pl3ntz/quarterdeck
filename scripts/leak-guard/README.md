# leak-guard

Aggressive, layered guard against committing/pushing sensitive data (pt-BR PII,
secrets, real infra/company/project identifiers) to any git repo. Built for daily
work across public projects. Quarterdeck-first, then all public repos.

## Layers (defense in depth)

| # | Component | Catches | Fail mode |
|---|-----------|---------|-----------|
| 1 | `pii_secrets_scan.py` | pt-BR PII **validated by check digit** (CPF, CNPJ, PIS, título eleitor), credit card (Luhn), phone-BR, + prefix-anchored secrets (AWS, GitHub, Google, Slack, Stripe, OpenAI, Anthropic, SendGrid, private keys, JWT, conn-strings), entropy fallback, base64/hex decode pass | fail-closed |
| 2 | `gitleaks stdin` | generic / high-entropy secrets from the community ruleset | optional (warns if absent) |
| 3 | `quarterdeck-guard/leak-scan.sh` + denylist | real infra/company/project identifiers you curate (`~/.claude/local/quarterdeck-denylist.txt`) | fail-closed |

Enforcement points, all reading **real blob bytes** (binary/`.gitattributes -diff`-proof):
- `git-wrapper.sh` — shell `git()` function; scans `commit`/`push` **before** git, so `--no-verify` cannot skip it.
- `hooks/pre-commit`, `hooks/commit-msg`, `hooks/pre-push` — per-repo defense in depth; chain to any prior hook.

## The ceiling — read this (no security theater)

This is a **client-side** guard. It stops *accidental* leaks extremely well. It does
**not** stop a determined actor, because a local guard fundamentally can't:

- The wrapper only wraps `git` **in a shell that sourced it** (zsh). `/usr/bin/git`
  directly, GUI clients (Tower, GitKraken, IDE git), or another shell **bypass it**.
- Hooks are skipped by `git commit/push --no-verify`, and a repo that sets its own
  `core.hooksPath` (e.g. Husky) bypasses `.git/hooks` entirely — the wrapper is what
  covers those, but only in the wrapping shell.

**The real backstop is server-side**, which cannot be bypassed from a laptop:
enable **GitHub Push Protection** (Settings → Code security → Secret scanning →
Push protection) on the org/repos, and/or a `pre-receive` hook on the remote.
Use this local guard as the fast first line; use server-side as the wall.

## Install

```sh
# one repo (quarterdeck first) — installs hooks + the shell wrapper
~/.claude/scripts/leak-guard/install.sh ~/dev/quarterdeck

# every repo on the machine (goal: all public projects)
~/.claude/scripts/leak-guard/install.sh --global

# just re-install the shell wrapper into ~/.zshrc
~/.claude/scripts/leak-guard/install.sh --wrapper-only
```

The wrapper is appended to `~/.zshrc` inside a marked block; open a new shell (or
`source ~/.zshrc`) to activate. Global mode sets `core.hooksPath`; repos with their
own hooksPath (Husky) still rely on the wrapper.

## False positives & the escape hatch

Test/fixture/spec/`.example`/`.md` files auto-relax the FP-prone rules (CPF, phone,
generic secrets → WARN). Canonical test documents (`111.444.777-35`, etc.) and
localhost/dummy connection strings are allow-listed. If something legitimate is
still blocked, extend the allow-lists in `pii_secrets_scan.py` or the denylist.

Audited one-shot bypass (use only after manually verifying the content):

```sh
LEAKGUARD_OFF=1 git commit ...
```

## Dependencies

- `python3` (stdlib only) — mandatory.
- `gitleaks` (`brew install gitleaks`) — layer 2; the guard runs without it (warns).
- `~/.claude/local/quarterdeck-denylist.txt` — layer 3; **absence = fail-closed block**.

## Known residual gaps (honest)

- Secrets split across two lines, or under arbitrary/nested encodings, can evade
  regex+entropy (one base64/hex layer is decoded; deeper nesting is not).
- Standalone full names are not detected (too FP-prone) — use the denylist for
  specific known names.
- CNH / RG are context-anchored WARN (no universal check digit) — surfaced, not blocked.
