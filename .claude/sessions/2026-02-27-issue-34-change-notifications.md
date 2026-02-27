# Issue #34: Wire up ChangeNotifier to publish sync events

**Started**: 2026-02-27
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/34

## Todo
- [x] Add notify call to Persister after LRT persist
- [x] Add notify call to LatPersister after LAT persist
- [x] Add notify call to CommentaryPersister after annotations persist
- [x] Cascade batch-reparse — covered (calls persisters internally)
- [x] Rename key expression from `data-changed` to `sync`
- [ ] Test with Zenoh enabled — verify events appear in admin dashboard

## Notes
- ChangeNotifier.notify/3 wired into all three persisters
- Publishes to `fractalaw/@{tenant}/events/sync`
- Fractalaw subscribes to trigger selective pulls from queryables
- Updated ZENOH-SPEC.md and skill doc with new key name

**Ended**: 2026-02-27
