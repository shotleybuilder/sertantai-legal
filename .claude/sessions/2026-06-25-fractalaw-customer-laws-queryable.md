# Title: Fractalaw Customer Laws Queryable

**Started**: 2026-06-25
**Context**: fractalaw needs a Zenoh queryable to get law names for a customer (integration brief in `backend/data/fractalaw-integration-brief.md`)

## Todo
- [ ] Read existing DataServer queryable pattern
- [ ] Add queryable: `@{tenant}/sertantai/customers/{customer_id}/laws` → JSON array of law names
- [ ] Source data from `org_applicabilities` table (customer ↔ law mapping)
- [ ] Handle customer_id lookup (org name → org UUID)
- [ ] Test with QQ corpus (expect 334 laws)
- [ ] Optional: subscribe to `@{tenant}/fractalaw/status/**` for pipeline events

## Notes
- Law names must be canonical format: `UK_ukpga_1974_37`
- Fractalaw will compose: get laws from sertantai → query pipeline status from its own DuckDB
- Keep it simple — JSON response, not Arrow IPC
