# Title: Template Snagging — Bugs & Polish

**Started**: 2026-06-10 03:00

## Todo
- [x] Bug: aggregation drops actors when provisions have flat governed_actors but null actors struct — fixed with union fallback + 8 tests
- [ ] Bug: lat view missing actors/extraction_method columns after schema change — needs migration not manual DDL
- [ ] Bug: duplicate LRT/LAT rows from failed sync retries — need idempotent sync (check-before-create or delta)
- [ ] Bug: fractalaw position classification wrong for s.3 HSWA (employer as counterparty) — fractalaw fix pending
- [ ] Polish: clean up unused fitness_*_options functions (compiler warnings)
- [ ] Polish: group tier_fields clauses together (compiler warning)

## Notes
- First bug found by user reviewing Baserow PoC — s.3 HSWA missing Org: Employer
- Root cause was two-fold: fractalaw position bug + our aggregation not falling back to flat
- Tests would have caught the aggregation issue — gap now closed with profile_query_test.exs
