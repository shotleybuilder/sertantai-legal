---
session: Fractalaw Customer Laws Queryable
status: closed
opened: 2026-06-25
closed: 2026-06-25
---
# Title: Fractalaw Customer Laws Queryable

**Started**: 2026-06-25
**Context**: fractalaw needs a Zenoh queryable to get law names for a customer (integration brief in `backend/data/fractalaw-integration-brief.md`)

## Todo
- [x] Read existing DataServer queryable pattern
- [x] Add queryable: `@{tenant}/sertantai/customers/{customer_id}/laws` → JSON array of law names
- [x] Source data from `org_applicabilities` table (customer ↔ law mapping)
- [x] Test with QQ corpus (274 laws, status=yes)
- [x] Disable LAT pruner (#110) — was deleting HSWA LAT rows
- [x] Reparse HSWA, verify provision taxa landed (825 enriched, 431 with actors)
- [ ] Optional: subscribe to `@{tenant}/fractalaw/status/**` for pipeline events

## Notes
- customer_id is the org UUID (no friendly name stored in this service)
- Fractalaw composes: get laws from sertantai → query pipeline status from its own DuckDB
- Raised #109 (annotation duplicate key), #110 (pruner bug), #111 (provision subscriber not in UI)

**Ended**: 2026-06-25
**Commits**: `b4d53a7`, `44d7d08`

## Summary
- Completed: 6 of 7 todos (status event subscription deferred)
- Files: `data_server.ex`, `taxa_subscriber.ex`
- Outcome: Customer laws queryable live, LAT pruner disabled, HSWA end-to-end proven with refactored schema
- Next: #110 (pruner redesign with UI), #111 (provision subscriber dashboard), #109 (annotation upsert)
