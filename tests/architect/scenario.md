Design how to add **real-time notifications** to a FastAPI (async) + React app.
When a long-running job finishes (e.g., a report is ready), the user should see it
without refreshing the page.

Constraints:
- Shared single box: PostgreSQL + Redis already run there; services via systemd.
- Must not require a new piece of paid infrastructure if avoidable.
- Existing API is REST; the frontend is a React SPA.
- Expect up to a few thousand concurrent users, mostly idle.

Produce your design proposal.
