# Title: Compliance Templates — Phase 5: Webhook Pipeline + Dashboard

**Started**: 2026-06-08 00:30
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 5)
**Ended**: 2026-06-08 01:15
**Commits**: `ecb031c` (Phase 4), `c165969`

## Todo
- [x] Webhook common event struct module (WebhookEvent)
- [x] Webhook controller endpoint (POST /api/webhooks/template/:provider/:org_id)
- [x] Baserow webhook payload parsing (parse_webhook_event)
- [x] Route webhook events to ComplianceMetrics (ETS-backed processor)
- [ ] Surface compliance metrics in /app/stats dashboard → **deferred to Phase 7**
- [ ] Polling fallback (6-12 hour reconciliation for missed webhooks) → **deferred to Phase 7**

## Notes
- ComplianceMetrics tracks: compliant/non-compliant/partially counts, action open/completed, timestamps
- Per-org isolation via ETS
- 11 new tests
- Dashboard UI and polling are operational — deferred to Phase 7 (frontend + infrastructure)
