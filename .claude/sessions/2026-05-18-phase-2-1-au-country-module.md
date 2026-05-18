# Title: Phase 2.1 — AU Country Module

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo
- [x] Implement `SertantaiLegal.Countries.Au` module
  - [x] Type codes: 24 entries (cth_act/li/reg, 8×state act/reg, cop, model_cop, award, nes)
  - [x] Jurisdictions: 9 (cth + 6 states + 2 territories)
  - [x] Geographic extents: 10 (au + 9 jurisdictions)
  - [x] Family taxonomy: 35 families (31 shared with UK + 4 AU-specific)
  - [x] Actor definitions: 23 government + 25 governed (incl. PCBU, HSR, Labour Hire)
  - [x] Source URL builders: portal_url/1 per jurisdiction, source_url returns nil (AU URLs aren't predictable)
- [x] Register AU in `Countries.Country` registry
- [x] Create `legal_register_au` + `legal_articles_au` partitions with REPLICA IDENTITY FULL
- [x] All 1,227 tests pass (16 new AU tests added)
- [x] AU test coverage: registry, identity, type codes, geo extents, families, actors, source URLs, partition CRUD, country isolation

## Notes
- First real multi-country data — proves the Phase 1 architecture works
- Research findings in `.claude/sessions/2026-05-17-australian-ehs-hr-research.md`
- No data import yet — that's Phase 2.2

**Ended**: 2026-05-18
**Commits**: `e251f50`
