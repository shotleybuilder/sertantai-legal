# Title: Compliance Templates — Phase 5: Webhook Pipeline + Dashboard

**Started**: 2026-06-08 00:30
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 5)

## Todo
- [ ] Webhook common event struct module
- [ ] Webhook controller endpoint to receive provider callbacks
- [ ] Baserow webhook payload parsing (already stubbed in baserow.ex)
- [ ] Route webhook events to compliance metrics update logic
- [ ] Surface compliance metrics in /app/stats dashboard
- [ ] Polling fallback (6-12 hour reconciliation for missed webhooks)

## Notes
- Baserow webhooks: fire-and-forget, no old values, no user ID
- Common event struct: event_type, table_id, row_id, changed_fields, timestamp
- Webhooks only carry status field values — never free text, files, or PII
- /app/stats already exists with PGLite-local stats — extend with server-side compliance data
- Polling fallback critical for compliance: can't lose "Non-Compliant" status changes
