# Title: Template Snagging — Bugs & Polish

**Started**: 2026-06-10 03:00

## Todo
- [x] Bug: aggregation drops actors when provisions have flat governed_actors but null actors struct — fixed with union fallback + 8 tests
- [x] Bug: aggregation didn't filter invented labels — fixed with label_source=canonical filter
- [x] Bug: provision text rolled up without numbers or separators — fixed with "3(1)" prefix + blank lines + 4 tests
- [x] Bug: Actor Tuples Name column empty — fixed by populating with _source_id composite key
- [x] Bug: lat view missing actors/extraction_method columns — migration 20260611000001 recreates view
- [x] Polish: removed unused fitness_process/place/plant_options functions
- [x] Polish: grouped tier_fields clauses together (all 3 baserow.ex warnings resolved)
- [x] Bug: duplicate LRT rows — DeltaDetector module + Engine.sync_lrt refactor (create/update/delete)
- [x] mix sync.run task — proper single-command Baserow sync with --clean flag
- [ ] Bug: fractalaw position classification wrong for s.3 HSWA — fractalaw fix pending
- [ ] Delta sync for LAT and Actor Tuples (LRT done, LAT/tuples still batch_create)

## Gemini Code Review Findings (2026-06-11)

Reviews at: backend/data/code-reviews/

### P1 — Critical (data integrity) — ALL FIXED
- [x] **Partial batch failure loses mappings** — per-batch on_batch callback saves mappings immediately
- [x] **LAT now uses DeltaDetector** — create new, update changed, delete orphaned. Customer enrichment preserved
- [x] **duty_sub_type array_agg(DISTINCT)** — collects all duty sub-types per provision, not just first

### P2 — High (production robustness) — ALL FIXED
- [x] **Retry with exponential backoff** — all API calls retry transient errors (429, 5xx) up to 3 times
- [x] **JWT refresh helper** — refresh_auth/1 for re-authentication on 401
- [x] **--clean prod guard** — confirmation prompt + warning in production environment
- [x] **link_row via provider abstraction** — Baserow.create_field with raw opts pass-through, no more direct Req.post

### P3 — Medium (correctness/config) — ALL FIXED
- [x] **Pipe delimiter sanitised** — actor labels have | replaced with _ in composite key
- [x] **governed_only configurable** — reads from target_config["governed_only"], defaults true
- [x] **actors empty array handled** — fallback checks IS NULL OR array_length IS NULL
- [x] **section_id multi-jurisdiction** — EU art., Welsh/Scottish Acts s., NI regs reg.

### P4 — Future (architecture) — DONE (separate session)
- [x] **Sync should be async job (Oban)** — `b8c5218` SyncWorker + SchedulerWorker, persistent queue with retry
- [x] **Multi-tenant misconfiguration risk** — `b8c5218` workspace validation before sync (all tables same workspace)
- [x] **Monitoring/telemetry** — `b8c5218` telemetry events for sync job completion, TelemetryHandler extended

**Ended**: 2026-06-11 04:30
**Commits**: `59fcaff`, `dbad92d`, `29f3d75`, `11b9ef3`, `705ffe5`, `9ca77d5`, `172abe9`, `99da084`, `7b0510e`, `31f4d2d`, `ec4c278`, `054928b`

## Carried Forward
- Fractalaw position bug (s.3 HSWA) — external dependency
- Delta sync for LAT and Actor Tuples — future session

## Notes
- First bug found by user reviewing Baserow PoC — s.3 HSWA missing Org: Employer
- Root cause was two-fold: fractalaw position bug + our aggregation not falling back to flat
- Tests would have caught the aggregation issue — gap now closed with profile_query_test.exs
- Gemini review script at backend/scripts/gemini_sync_review.py (reusable)
