# Title: Oban Refactor — Async Sync Jobs

**Started**: 2026-06-11 04:30

## Todo
- [x] Add Oban dependency (2.18+) + migration v14 for oban_jobs table
- [x] Configure Oban: queues (sync:2, default:10), plugins (Pruner, Lifeline, Cron)
- [x] Add Oban to supervision tree (after Repo, before DNSCluster)
- [x] SyncWorker: wraps Engine.run/clean, uniqueness, is_active guard, PubSub broadcast
- [x] SchedulerWorker: cron every 6h, checks due configs, enqueues SyncWorker
- [x] Extract Engine.clean/1 from mix task into Engine module
- [x] Update mix sync.run: enqueue via Oban (--wait to block, --direct to bypass)
- [x] Update SyncController.trigger_sync: Oban.insert replaces Task.start
- [x] Multi-tenant workspace validation in Engine.execute_sync
- [x] Telemetry events for sync job completion
- [x] 10 worker tests (all passing)
- [x] Full suite: 1453 tests, 0 failures

## Notes
- Current sync runs synchronously in mix task — blocks terminal, no retry, no progress
- Oban gives: persistent queue, retries with backoff, concurrency limits, web dashboard
- P4 from Gemini code review (2026-06-11)
- Multi-tenant validation carried forward from template-snagging session

**Ended**: 2026-06-11 20:55
**Commits**: `b8c5218`
