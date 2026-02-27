# Issue #32 + #33: Zenoh admin dashboard

**Started**: 2026-02-27
**Ended**: 2026-02-27
**Issues**:
- https://github.com/shotleybuilder/sertantai-legal/issues/32 (subscriptions)
- https://github.com/shotleybuilder/sertantai-legal/issues/33 (queryables)

## Todo
- [x] Add telemetry to TaxaSubscriber (received, updated, failed counters)
- [x] Add telemetry to DataServer (query count, latency, errors)
- [x] Add telemetry to ChangeNotifier (published, dropped, errors)
- [x] ETS-backed ActivityLog GenServer
- [x] API endpoints: GET /api/zenoh/subscriptions, /api/zenoh/queryables
- [x] Frontend: /admin/zenoh with tabs (Subscriptions | Queryables & Publishers)
- [x] 10s polling for live updates via TanStack Query refetchInterval
- [x] Backend compiles clean, frontend type-checks clean
- [ ] Test with Zenoh enabled
- [ ] Commit and push

## Summary
- Completed: 8 of 10 todos (code complete, not yet tested/committed)
- Outcome: Full Zenoh admin dashboard implemented — needs live testing + commit
- Next: Test with Zenoh enabled, commit and push, close GH issues

## Notes
- Gracefully handles ZENOH_ENABLED=false (shows disabled state)
- status() functions use catch :exit for when GenServers aren't running
- DataServer now returns key_expressions list in status for display
