---
name: tdd-workflow
description: Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage. Test tooling by stack — pytest + httpx for FastAPI, vitest for Hono/React, Playwright for E2E.
---

# Test-Driven Development Workflow

This skill ensures all code development follows TDD principles with comprehensive test coverage.

## When to Activate

- Writing new features or functionality
- Fixing bugs or issues
- Refactoring existing code
- Adding API endpoints
- Creating new components

## Core Principles

### 1. Tests BEFORE Code
ALWAYS write tests first, then implement code to make tests pass.

### 2. Coverage Requirements
- Minimum 80% coverage (unit + integration + E2E)
- All edge cases covered
- Error scenarios tested
- Boundary conditions verified

### 3. Test Types

#### Unit Tests
- Individual functions and utilities
- Component logic
- Pure functions
- Helpers and utilities

#### Integration Tests
- API endpoints
- Database operations
- Service interactions
- External API calls

#### E2E Tests (Playwright)
- Critical user flows
- Complete workflows
- Browser automation
- UI interactions

## TDD Workflow Steps

### Step 1: Write User Journeys
```
As a [role], I want to [action], so that [benefit]

Example:
As a user, I want to search for markets semantically,
so that I can find relevant markets even without exact keywords.
```

### Step 2: Generate Test Cases
For each user journey, create comprehensive test cases:

```typescript
describe('Semantic Search', () => {
  it('returns relevant markets for query', async () => {
    // Test implementation
  })

  it('handles empty query gracefully', async () => {
    // Test edge case
  })

  it('falls back to substring search when Redis unavailable', async () => {
    // Test fallback behavior
  })

  it('sorts results by similarity score', async () => {
    // Test sorting logic
  })
})
```

### Step 3: Run Tests (They Should Fail)

Use the runner for the project's stack (the `npm test` below is a placeholder):
```bash
pytest -q            # Python / FastAPI
bun test             # or: npx vitest run   — TS / Hono / React
npx playwright test  # E2E
# Tests should fail - we haven't implemented yet
```

### Step 4: Implement Code
Write minimal code to make tests pass:

```typescript
// Implementation guided by tests
export async function searchMarkets(query: string) {
  // Implementation here
}
```

### Step 5: Run Tests Again
```bash
pytest -q   # or: bun test / npx vitest run
# Tests should now pass
```

### Step 6: Refactor
Improve code quality while keeping tests green:
- Remove duplication
- Improve naming
- Optimize performance
- Enhance readability

### Step 7: Verify Coverage
```bash
pytest --cov=. --cov-report=term-missing   # or: npx vitest run --coverage
# Verify 80%+ coverage achieved
```

## Testing Patterns

### Unit Test Pattern (Jest/Vitest)
```typescript
import { render, screen, fireEvent } from '@testing-library/react'
import { Button } from './Button'

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>)
    expect(screen.getByText('Click me')).toBeInTheDocument()
  })

  it('calls onClick when clicked', () => {
    const handleClick = vi.fn()   // vitest
    render(<Button onClick={handleClick}>Click</Button>)

    fireEvent.click(screen.getByRole('button'))

    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  it('is disabled when disabled prop is true', () => {
    render(<Button disabled>Click</Button>)
    expect(screen.getByRole('button')).toBeDisabled()
  })
})
```

### API Integration Test Pattern

**Python (FastAPI) — pytest + httpx against the ASGI app:**
```python
import pytest
from httpx import AsyncClient, ASGITransport
from main import app

@pytest.mark.asyncio
async def test_list_jobs_ok():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        r = await ac.get("/api/jobs")
    assert r.status_code == 200
    assert isinstance(r.json()["jobs"], list)

@pytest.mark.asyncio
async def test_bad_body_returns_422():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        r = await ac.post("/api/match", json={"scopes": []})   # violates Field(min_length=1)
    assert r.status_code == 422
```

**TS (Hono) — vitest against `app.request()`:**
```typescript
import { describe, it, expect } from 'vitest'
import app from '../src/server/index.js'

describe('GET /api/cv/:id', () => {
  it('404s an unknown id', async () => {
    const res = await app.request('/api/cv/nope')
    expect(res.status).toBe(404)
  })
})
```

### E2E Test Pattern (Playwright)
```typescript
import { test, expect } from '@playwright/test'

test('user can search and filter markets', async ({ page }) => {
  // Navigate to markets page
  await page.goto('/')
  await page.click('a[href="/markets"]')

  // Verify page loaded
  await expect(page.locator('h1')).toContainText('Markets')

  // Search for markets
  await page.fill('input[placeholder="Search markets"]', 'election')

  // Wait for debounce and results
  await page.waitForTimeout(600)

  // Verify search results displayed
  const results = page.locator('[data-testid="market-card"]')
  await expect(results).toHaveCount(5, { timeout: 5000 })

  // Verify results contain search term
  const firstResult = results.first()
  await expect(firstResult).toContainText('election', { ignoreCase: true })

  // Filter by status
  await page.click('button:has-text("Active")')

  // Verify filtered results
  await expect(results).toHaveCount(3)
})

test('user can create a new market', async ({ page }) => {
  // Login first
  await page.goto('/creator-dashboard')

  // Fill market creation form
  await page.fill('input[name="name"]', 'Test Market')
  await page.fill('textarea[name="description"]', 'Test description')
  await page.fill('input[name="endDate"]', '2025-12-31')

  // Submit form
  await page.click('button[type="submit"]')

  // Verify success message
  await expect(page.locator('text=Market created successfully')).toBeVisible()

  // Verify redirect to market page
  await expect(page).toHaveURL(/\/markets\/test-market/)
})
```

## Test File Organization

```
# Python (FastAPI) — tests/ mirrors src, pytest
api/
├── src/<pkg>/routers/jobs.py
└── tests/
    ├── test_jobs.py            # httpx integration
    └── test_store.py           # data layer (temp sqlite)

# TS (Hono + React) — colocated unit tests + top-level e2e
src/
├── client/components/Button/Button.test.tsx   # vitest + RTL
├── server/api/cv.test.ts                       # vitest against app.request()
└── e2e/
    ├── cv.spec.ts                              # Playwright
    └── auth.spec.ts
```

## Mocking External Services

Mock the flaky/external edges (LLM APIs, network); use a real temp DB for data code.

### LLM client mock (Python — pytest, monkeypatch)
```python
def test_match_degrades_when_llm_fails(monkeypatch):
    # force the optional refine to fail; the endpoint must still return the
    # deterministic heuristic order, never 500 (graceful degradation).
    def boom(*a, **k):
        raise groq_client.GroqError("rate limited")
    monkeypatch.setattr(groq_client, "rerank", boom)
    result = ranking.match(profile, jobs, refine=True)
    assert result.mode == "heuristic"
```

### DB — use a real temp SQLite, not a mock
```python
def test_upsert_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    import importlib, store; importlib.reload(store)
    store.init_db()
    store.upsert_job(sample_job)
    assert store.count_active() == 1
```

### TS (Hono/React) — vitest with `vi.fn()` / `vi.mock()`
```typescript
import { vi } from 'vitest'
vi.mock('../src/lib/llm.js', () => ({ rerank: vi.fn(async () => []) }))
```

## Test Coverage Verification

### Run Coverage Report
```bash
pytest --cov=. --cov-report=term-missing   # Python
npx vitest run --coverage                  # TS
```

### Coverage Thresholds
```python
# Python — pyproject.toml
[tool.coverage.report]
fail_under = 80
```
```typescript
// TS — vitest.config.ts
test: { coverage: { thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 } } }
```

## Common Testing Mistakes to Avoid

### ❌ WRONG: Testing Implementation Details
```typescript
// Don't test internal state
expect(component.state.count).toBe(5)
```

### ✅ CORRECT: Test User-Visible Behavior
```typescript
// Test what users see
expect(screen.getByText('Count: 5')).toBeInTheDocument()
```

### ❌ WRONG: Brittle Selectors
```typescript
// Breaks easily
await page.click('.css-class-xyz')
```

### ✅ CORRECT: Semantic Selectors
```typescript
// Resilient to changes
await page.click('button:has-text("Submit")')
await page.click('[data-testid="submit-button"]')
```

### ❌ WRONG: No Test Isolation
```typescript
// Tests depend on each other
test('creates user', () => { /* ... */ })
test('updates same user', () => { /* depends on previous test */ })
```

### ✅ CORRECT: Independent Tests
```typescript
// Each test sets up its own data
test('creates user', () => {
  const user = createTestUser()
  // Test logic
})

test('updates user', () => {
  const user = createTestUser()
  // Update logic
})
```

## Continuous Testing

### Watch Mode During Development
```bash
pytest-watch          # Python    | npx vitest    # TS (watch is default)
```

### Pre-Commit Hook
```bash
pytest -q && ruff check .          # Python
bun test && npx tsc --noEmit       # TS
```

### CI/CD Integration
```yaml
# GitHub Actions — pick the stack's step
- run: pytest --cov=. --cov-report=xml   # Python
# - run: npx vitest run --coverage       # TS
```

## Best Practices

1. **Write Tests First** - Always TDD
2. **One Assert Per Test** - Focus on single behavior
3. **Descriptive Test Names** - Explain what's tested
4. **Arrange-Act-Assert** - Clear test structure
5. **Mock External Dependencies** - Isolate unit tests
6. **Test Edge Cases** - Null, undefined, empty, large
7. **Test Error Paths** - Not just happy paths
8. **Keep Tests Fast** - Unit tests < 50ms each
9. **Clean Up After Tests** - No side effects
10. **Review Coverage Reports** - Identify gaps

## Success Metrics

- 80%+ code coverage achieved
- All tests passing (green)
- No skipped or disabled tests
- Fast test execution (< 30s for unit tests)
- E2E tests cover critical user flows
- Tests catch bugs before production

---

**Remember**: Tests are not optional. They are the safety net that enables confident refactoring, rapid development, and production reliability.
