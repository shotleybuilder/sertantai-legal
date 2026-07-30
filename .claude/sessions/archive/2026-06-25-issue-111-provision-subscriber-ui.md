---
session: Provision Subscriber Dashboard UI
status: closed
opened: 2026-06-25
closed: 2026-06-25
---
# Issue #111: Provision Subscriber Dashboard UI

**Started**: 2026-06-25
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/111

## Todo
- [x] Add ProvisionSubscriber to `/api/zenoh/subscriptions` endpoint
- [x] Surface in frontend Zenoh admin dashboard alongside TaxaSubscriber
- [x] Test with live provision publish

## Notes
- ProvisionSubscriber already logs to ActivityLog ETS with key `:provision_subscriber`
- Just needs wiring to ZenohController + frontend

**Ended**: 2026-06-25
**Commits**: `9cde372`

## Summary
- Completed: 3 of 3 todos
- Files: `zenoh_controller.ex`, `zenoh.ts`, `+page.svelte`
- Outcome: Both TaxaSubscriber and ProvisionSubscriber visible in /admin/zenoh dashboard
- Next: none — #111 resolved
