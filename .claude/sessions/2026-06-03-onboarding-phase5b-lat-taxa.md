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

**Ended**: 2026-06-03 15:00
**Commits**: `0290ff0`, `83506e4`, `6b596a1`, `3a2fb21`

## Summary
- Completed: 4 of 5 todos (end-to-end tested, Baserow LAT taxa exposure deferred)
- Files: legal_article.ex, provision_subscriber.ex, supervisor.ex, data_server.ex, lat-parse-session SKILL.md, customer-onboarding.md
- Outcome: 18 taxa/fitness columns on legal_articles, ProvisionSubscriber wired up, DataServer LRT queryable fixed (source_url rename). Full pipeline proven: fractalaw enrich → publish → sertantai law + provision taxa. 22 laws enriched (10 Making, 12 Empowering, 1 Housekeeping). Filed #88 (parser 0-row bug), #89 (skip revoked), #90 (L3 queue filter).
- Next: #90 (L3 queue filter for remaining ~170 QQ laws), Baserow LAT taxa columns, NAS/prod sync (Stages 7-11)
