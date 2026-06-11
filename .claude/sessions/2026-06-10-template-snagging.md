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
- [ ] Bug: duplicate LRT/LAT rows from failed sync retries — need idempotent sync (delta mode)
- [ ] Bug: fractalaw position classification wrong for s.3 HSWA — fractalaw fix pending

## Notes
- First bug found by user reviewing Baserow PoC — s.3 HSWA missing Org: Employer
- Root cause was two-fold: fractalaw position bug + our aggregation not falling back to flat
- Tests would have caught the aggregation issue — gap now closed with profile_query_test.exs
