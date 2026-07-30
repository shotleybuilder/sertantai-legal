---
session: Live Sync Pipeline Test
status: closed
opened: 2026-06-11
closed: 2026-06-11
---
# Title: Live Sync Pipeline Test

**Started**: 2026-06-11 21:45

## Todo
- [ ] Consume latest fractalaw publish (Zenoh taxa enrichment)
- [ ] QA: verify enrichment landed correctly (function labels, DRRP, actors)
- [ ] Run Baserow sync (mix sync.run --direct or via Oban)
- [ ] QA: LRT rows in Baserow — counts, field values, delta detection
- [ ] QA: LAT rows — provision text, DRRP types, parent links
- [ ] QA: Actor Tuples — correct tuples, LAT links
- [ ] Verify idempotency: re-run produces 0 creates, 0 deletes

## Status: SUSPENDED (resume ~2026-06-15)

## Resume Instructions
1. Start Phoenix server: `cd backend && mix phx.server`
2. Check Zenoh connectivity: visit `/admin/zenoh` — DataServer and TaxaSubscriber should show `ready`
3. Ask fractalaw to publish latest enrichment (or check if it auto-published while away)
4. Verify enrichment landed: check uk_lrt function labels, LAT actors/drrp_types
5. Run sync: `mix sync.run --direct --wait` (use --direct for immediate feedback during QA)
6. Walk through each QA todo item above
7. After clean run, re-run without --clean to verify idempotency (0 creates, 0 deletes)

## What was done this conversation (2026-06-11)
- **Oban refactor** (`b8c5218`): SyncWorker, SchedulerWorker, Engine.clean, workspace validation, telemetry
- **Delta sync LAT + Actor Tuples** (`55da3ef`): DeltaDetector for all three table types, mapping timestamps
- All P1-P4 Gemini code review items resolved
- 1453 tests, 0 failures, pushed to origin/main

## Notes
- Delta sync for all three tables (LRT/LAT/Actor Tuples) now in place
- Oban available but --direct flag for immediate feedback during testing
- Fractalaw position bug (s.3 HSWA employer as counterparty) still pending their fix
