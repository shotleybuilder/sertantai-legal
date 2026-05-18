# Title: Phase 1.3 — Country Module Pattern

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo

### Country behaviour + UK module
- [x] Define `SertantaiLegal.Countries.Country` behaviour (11 callbacks + registry)
- [x] Create `SertantaiLegal.Countries.Uk` implementing the behaviour
- [x] Type codes: 19 entries (delegates to existing TypeClass for title inference)
- [x] Geo extents: 13 UK region combinations
- [x] Family taxonomy: delegates to FamilyRules.title_keywords (41 families)
- [x] Actor definitions: delegates to ActorDefinitions (46 govt, 84 governed)
- [x] Source URL builder: `legislation.gov.uk/{type}/{year}/{number}`

### Update internal UkLrt → LegalRegister references (deferred from 1.2)
- [x] `scraper/persister.ex` (6 refs)
- [x] `scraper/staged_parser.ex` (1 ref)
- [x] `scraper/law_parser.ex` (2 refs)
- [x] `scraper/lat_session_manager.ex` (2 refs)
- [x] `scraper/reparse_manager.ex` (2 refs)
- [x] `legal/function_calculator.ex` (6 refs)
- [x] `zenoh/data_server.ex` (4 refs)
- [x] `zenoh/taxa_subscriber.ex` (1 ref)
- [x] `legal/lat.ex` — belongs_to relationship updated
- [x] `sync/delta/config.ex` — resource reference updated
- [x] `scraper/parsed_law.ex`, `sync/providers/baserow.ex` — comments updated

### Verify
- [x] All 1,211 tests pass
- [x] Frontend still works

## Notes
- Country behaviour defines the interface; Uk module is the first implementation
- Taxa modules (making_detector, purpose_classifier) stay in current location but may call country module for data
- Scraper abstraction is Phase 1.4 — don't move scraper files yet
