# Title: Customer Onboarding Phase 5 — LAT Sync to Baserow

**Started**: 2026-06-03 08:15
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 5)

## Todo
- [x] 4.6 — JSONB → multi-selects (Function, Duty Type, Purpose, Holders) — e10669a
- [x] 5.1 — LAT table in Baserow (ID 1008280), section_type filter in profile_query — 922bc59
- [x] 5.2 — 623 LAT rows synced (OH&S, section+article level) with parent law links — 922bc59

## Deferred
- [ ] Engine.run sync flow bug (#87) — rows created but not persisted via engine
- [ ] Delta sync: update existing rows via _source_id match
- [ ] LAT schema: no Taxa/Fitness columns — needs fractalaw parser enhancement + migration

## Notes
- Baserow free tier: 5K row limit. POC total: 729 rows (106 LRT + 623 LAT)
- Master holder vocabulary: 165 options hardcoded from ActorDefinitions + observed data
- Vocabulary validation stops sync if fractalaw introduces unknown actors
- LAT sync uses section_types filter (configurable in target_config)
- Engine.run bug workaround: call sync steps directly outside engine

**Ended**: 2026-06-03 10:30
**Commits**: `08485ce`, `e10669a`, `428ada0`, `922bc59`, `8b6304a`

## Summary
- Completed: 3 of 3 todos + housekeeping fixes
- Files: baserow.ex, engine.ex, profile_query.ex, customer-onboarding.md
- Outcome: JSONB fields converted to multi-selects (Function, Duty Type, Purpose, Holders with 165-option master vocabulary). LAT synced to Baserow with section_type filter and parent law links — 729 total rows within free tier. Engine.run bug filed as #87. LAT schema gap identified (no Taxa/Fitness columns — needs fractalaw enrichment).
- Next: #87 engine flow fix, delta sync, LAT Taxa enrichment from fractalaw, prod deployment (Phase 6)
