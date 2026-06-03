# Title: Customer Onboarding Phase 5b — LAT Taxa/Fitness Enrichment from Fractalaw

**Started**: 2026-06-03 11:00
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 5.2)
**Fractalaw ref**: ~/fractalaw/.claude/sessions/06-03-26-lat-taxa-fitness-columns.md

## Todo
- [ ] Add taxa/fitness columns to legal_articles (Ash migration)
- [ ] New zenoh subscriber for taxa/provisions/{law_name}
- [ ] Upsert by section_id
- [ ] Expose taxa columns in lat view + Baserow LAT sync
- [ ] End-to-end test: fractalaw publish → sertantai receive → query

## Notes
- Fractalaw side DONE: publishes 17 taxa/fitness columns per provision via Arrow IPC over zenoh
- Zenoh topic: fractalaw/@{tenant}/taxa/provisions/{law_name}
- Batched per law, delta tracking via provisions_published_at
- 97K provisions total, sertantai can handle bulk import
- Columns: drrp_types, governed_actors, government_actors, duty_family, duty_sub_type, clause_refined, purposes, popimar, taxa_confidence, fitness_polarity/person/process/place/plant/property/sector
