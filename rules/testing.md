# Testing

Coverage floor for this codebase: **80%**, across unit, integration and E2E (Playwright).
That number is a local policy choice, not a default — everything else about testing
(red-green-refactor, isolation, mocking) the model already knows.

**Where tests run matters more than how they are written.** Never run a heavy suite on the
host: see `performance.md` and the `block-build` hook. Containerised projects run tests in
their container; projects with CI defer to the pipeline.

`tdd-guide` for new features, `e2e-runner` for Playwright journeys.
