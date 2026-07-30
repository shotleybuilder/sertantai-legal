---
session: Live Status Assurance Metrics
status: closed
opened: 2026-03-12
closed: 2026-03-12
---
# Title: Live Status Assurance Metrics

**Started**: 2026-03-12
**Spec**: `.claude/sessions/2026-03-12-ohs-data-quality-audit.md` → Phase 3

## Todo

### Backend
- [x] `GET /api/analytics/live-status` endpoint in `AnalyticsController`
- [x] Metric 1: Pipeline coverage (reconciled / changes-only / metadata-only / airtable / none)
- [x] Metric 2: Source agreement rate (conflicts count + breakdown)
- [x] Metric 3: JSONB cross-check misclassification detector (the "canary")
- [x] Metric 4: Revocation pattern distribution (affect types + target types)
- [x] Metric 5: Live status by family (with coverage %)
- [x] Metric 6: "Applied" status distribution for whole-instrument revocations

### Frontend
- [x] "Live Status Assurance" collapsible section on `/admin/analytics`
- [x] KPI row: Reconciled %, Agreement %, Misclassified count
- [x] Pipeline coverage stacked bar + per-family table
- [x] Conflict breakdown + misclassification alarm card
- [x] Pattern distribution bar charts + applied status

## Notes
- SQL queries are pre-tested in the spec doc
- Metrics 3/4/6 need JSONB unnesting — API-backed, not PGLite
- Metrics 1/5 could be PGLite but simpler to keep all in one API call

**Ended**: 2026-03-12
