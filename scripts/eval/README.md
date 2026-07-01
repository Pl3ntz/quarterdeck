# Eval — Judge Stability Harness

A review agent is an **AI judge**: a non-deterministic LLM that grades output.
Asserting a single-run pass rate hides the real question — *which findings does
it catch every time, and which does it catch only sometimes?* This harness runs
an agent **K times** against its fixture and reports where the judge is stable.

The idea (borrowed from a production practitioner): don't force the judge to be
consistent — **measure where it already is**. Run the same input repeatedly until
the score stops fluctuating; the findings that flip between runs are the ones you
can't trust yet.

## Prerequisites

Just the **`claude` CLI** on your PATH — the same one from your Claude Code
subscription. No Anthropic API key, no `pip install`, no per-call billing: the
harness shells out to `claude -p` (headless mode), so every run goes through your
subscription and the same runtime the agents actually run in.

```bash
claude --version   # confirm the CLI is installed
```

## Usage

```bash
# Sanity check first (1 call) — validates parsing/matching cheaply
python scripts/eval/stability_runner.py --agent grammar-reviewer --runs 1

# Real stability run
python scripts/eval/stability_runner.py --agent grammar-reviewer --runs 5

# Both agents that ship a fixture
python scripts/eval/stability_runner.py --all --runs 5
```

| Flag | Default | Meaning |
|---|---|---|
| `--agent <name>` | — | one agent (must have a fixture under `tests/<name>/`) |
| `--all` | — | every agent with a fixture (`grammar-reviewer`, `ortografia-reviewer`) |
| `--runs K` | 5 | number of repetitions |
| `--model <alias>` | frontmatter | override the agent's `model:` (`sonnet`/`opus`/`haiku`) |

## How it works

1. Reads the agent's system prompt + `model:` from `agents/<name>.md`.
2. Runs `claude -p "<fixture>" --system-prompt "<agent prompt>" --model <m>
   --output-format json`, K times, from a neutral temp dir (so a project
   `CLAUDE.md` doesn't bias the run).
3. Parses each run's `FINDINGS`/`ACHADOS` bullets from the JSON `result`.
4. Matches each finding against `tests/<name>/expected-findings.md` **by token**
   (the wrong/correct text appearing in the finding) — *not* by line number,
   because the fixtures' line column is off-by-one vs the file. The matcher is
   fuzzy but **deterministic**, so the variance it reports is the agent's.

## Output

- **`tests/<name>/stability-report.md`** (versioned) — per-finding hit rate +
  classification, plus highlighted **Fluctuating** and **Blind** sections.
- **`tests/<name>/.stability-runs.jsonl`** (gitignored via `*.jsonl`) — one line
  per run with the raw output, for auditing whether a flip was the agent or the
  matcher.

### Classification

| Class | Meaning |
|---|---|
| **ESTAVEL** | detected in K/K runs — the judge's trustworthy floor |
| **FLUTUANTE** | detected in some runs — non-deterministic; the signal to act on |
| **CEGO** | detected in 0/K runs — a blind spot in the prompt/rules |

**Stability score** = ESTAVEL / total. **Detection score** = mean hit rate.

## Notes

- **Variance source:** runs use the CLI's default sampling (no temperature flag in
  headless mode). That's intentional — it measures the variance you actually get
  in Claude Code, not a synthetic one.
- **Token matching** can undercount findings the agent phrases very differently
  from the gabarito (mainly multi-word "wrong" entries like comma splices).
  Because it's deterministic, that bias is constant across runs and doesn't
  distort the *stability* signal — only the absolute detection number.
- Only `grammar-reviewer` and `ortografia-reviewer` have fixtures today. Adding a
  `tests/<agent>/{test-errors,expected-findings}.md` pair makes that agent
  runnable with no code change.
- **Commit gate:** `hooks/eval-gate.sh` (PreToolUse, installed by `setup.sh`)
  warns on `git commit` when a staged `agents/<name>.md` changed, that agent
  ships a fixture, and no eval run was seen in the session transcript. It only
  warns — the harness fires K LLM calls, too slow/costly to block a commit.
