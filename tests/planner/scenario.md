Plan the implementation of **per-user rate limiting** for a production FastAPI
service. Context:

- Stack: FastAPI (async), PostgreSQL, Redis, deployed via systemd on a shared box.
- Requirement: limit each authenticated user to 100 requests/minute across all
  endpoints; return HTTP 429 with a `Retry-After` header when exceeded.
- Must be zero-downtime to deploy; the service handles live traffic.
- Admin users are exempt. Limits must survive a service restart.
- The team wants it observable (metrics on how often users hit the limit).

Produce your plan.
