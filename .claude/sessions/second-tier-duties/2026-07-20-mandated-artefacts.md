# Mandated Artefacts Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-20
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (mandated_artefacts_json)
**Depends on**: 2026-07-19-obligations-raci.md

## Todo
- [ ] Create SecondaryMandatedArtefact resource
- [ ] Register in Api domain
- [ ] Generate + run migration
- [ ] Parse `mandated_artefacts_json` in subscriber
- [ ] Full replace per source_id (same as RACI)
- [ ] Add to batch summary logging
- [ ] Tests
- [ ] Verify with live publish

## Notes
- Phase 4 of consolidated payload
- Links to secondary_obligations via obligation_id
- 12 artefact types: Risk Assessment, Safety Case, Hazard Log, Permit, etc.
- Same DuckDB struct parser (parse_duckdb_structs)
