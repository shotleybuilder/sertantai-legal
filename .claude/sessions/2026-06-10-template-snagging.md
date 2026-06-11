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

### P2 — High (production robustness)
- [ ] **No rate limiting / retry** — 10+ rapid API calls with no backoff. Baserow 429 halts entire sync. [baserow_api_robustness.md §1]
- [ ] **JWT expiry mid-sync** — obtained once, no refresh. Long syncs (2+ min) risk 401 failures. [baserow_api_robustness.md §3]
- [ ] **--clean has no confirmation or prod guard** — accidental prod wipe with no recovery. [architecture_fitness.md §2]
- [ ] **link_row creation bypasses provider abstraction** — direct Req.post in engine.ex, not Baserow.create_field. [baserow_api_robustness.md §6]

### P3 — Medium (correctness/config)
- [ ] **Tuple pipe delimiter fragile** — actor labels could theoretically contain |. Validate or use safer delimiter. [actor_tuple_model.md §1]
- [ ] **governed_only not configurable** — hardcoded default excludes government actors. Gov agencies can't see their responsibilities. [actor_tuple_model.md §4]
- [ ] **actors empty array vs NULL** — fallback checks IS NULL but not empty array. Legacy data with [] actors misses flat fallback. [provision_aggregation.md §2]
- [ ] **section_id format hardcoded to UK** — s./reg. prefix doesn't handle EU art., Welsh, NI formats. [provision_aggregation.md §5]

### P4 — Future (architecture)
- [ ] **Sync should be async job (Oban)** — mix task blocks, no progress, no retry. [architecture_fitness.md §3]
- [ ] **Multi-tenant misconfiguration risk** — wrong table IDs = cross-org data leak. Needs validation. [architecture_fitness.md §5]
- [ ] **Monitoring/telemetry** — no structured metrics, no alerting on failure. [architecture_fitness.md §7]

## Notes
- First bug found by user reviewing Baserow PoC — s.3 HSWA missing Org: Employer
- Root cause was two-fold: fractalaw position bug + our aggregation not falling back to flat
- Tests would have caught the aggregation issue — gap now closed with profile_query_test.exs
- Gemini review script at backend/scripts/gemini_sync_review.py (reusable)
