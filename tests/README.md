# Tests

Manual test fixtures for validating agent behavior. These are not automated — they are reference files designed to be fed to agents for regression testing.

## How to use

### Language agents (ortografia-reviewer, grammar-reviewer)

1. Start a Claude Code session with Quarterdeck agents installed
2. Ask the agent to review the test file:

```
# PT-BR
Run ortografia-reviewer against tests/ortografia-reviewer/test-errors.md

# EN-US
Run grammar-reviewer against tests/grammar-reviewer/test-errors.md
```

3. Compare the agent's output against `expected-findings.md` in the same directory
4. The agent should detect all listed errors with correct severity and rule citation

### Coverage targets

| Agent | Test errors | Expected detection | Acceptable false positives |
|---|---|---|---|
| ortografia-reviewer | 30 across 8 categories | 90%+ | 0-2 |
| grammar-reviewer | 30 across 8 categories | 90%+ | 0-2 |

### When to re-test

- After editing any agent's system prompt
- After changing output format rules
- After adding/removing grammar or spelling rules
- Before any release or PR that touches agent files
