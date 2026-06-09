# Title: Compliance Templates — Phase 7: Dashboard + Polling Fallback

**Started**: 2026-06-09 00:00
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 7 — deferred from Phase 5)

## Todo
- [ ] Surface compliance metrics in /app/stats dashboard (extend existing page)
- [ ] Polling fallback: periodic reconciliation of Baserow assessment/action data (6-12 hour cycle)
- [ ] Handle missed webhooks: compare ETS metrics against polled data, reconcile gaps

## Notes
- ComplianceMetrics ETS processor already exists (Phase 5)
- GET /api/screening/compliance-metrics endpoint already exists
- /app/stats page exists with PGLite-local stats — extend with server-side compliance data
- Polling needs Baserow API read (list rows with filters) — existing batch read infrastructure
- Polling is critical: Baserow webhooks are fire-and-forget, can't lose Non-Compliant changes
