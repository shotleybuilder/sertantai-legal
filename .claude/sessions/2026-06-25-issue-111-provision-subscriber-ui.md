# Issue #111: Provision Subscriber Dashboard UI

**Started**: 2026-06-25
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/111

## Todo
- [ ] Add ProvisionSubscriber to `/api/zenoh/subscriptions` endpoint
- [ ] Surface in frontend Zenoh admin dashboard alongside TaxaSubscriber
- [ ] Test with live provision publish

## Notes
- ProvisionSubscriber already logs to ActivityLog ETS with key `:provision_subscriber`
- Just needs wiring to ZenohController + frontend
