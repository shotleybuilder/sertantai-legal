# Obligations & RACI Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-19
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (obligations_json + raci_json sections)
**Depends on**: 2026-07-19-references-extension.md

**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/126

## Todo
- [ ] Create SecondaryObligation resource (`secondary_obligations` table)
- [ ] Create SecondaryRaci resource (`secondary_raci` table)
- [ ] Register in Api domain
- [ ] Generate + run migration
- [ ] Parse `obligations_json` in subscriber (DuckDB struct syntax)
- [ ] Parse `raci_json` in subscriber (DuckDB struct syntax)
- [ ] Upsert obligations keyed on `obligation_id` (`{section_id}:ob.{index}`)
- [ ] Full replace RACI per source_id
- [ ] Tests
- [ ] Verify with live publish

## Notes
- One provision → many obligations (lettered lists "a. X must... b. Y must...")
- One obligation → many RACI assignments
- `obligation_index` is the join key between obligations and RACI within a provision
- Uses same DuckDB struct parser as references_json
- Spec says Phase 3 of consolidated payload
