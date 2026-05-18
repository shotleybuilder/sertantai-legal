# Title: Phase 1.2 — Backend Resource Generalisation

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo
- [x] Create `SertantaiLegal.Legal.LegalRegister` resource (backed by `legal_register` table)
- [x] Add `country` and `jurisdiction` attributes, replace `leg_gov_uk_url` with `source_url`
- [x] Register in domain (`api.ex`) — new resources + old as legacy aliases
- [x] Update all actions/queries to include `country` context (by_country, paginated with country arg)
- [x] Create `SertantaiLegal.Legal.LegalArticle` resource (backed by `legal_articles` table)
- [x] Update `AmendmentAnnotation` resource — added `country` attr, relationship → LegalRegister
- [x] Generalise API routes: `/api/laws/*` added alongside `/api/uk-lrt/*` legacy aliases
- [x] Update controllers: UkLrtController, ScrapeController, CascadeController, LatAdminController → use LegalRegister
- [ ] Update internal references (scrapers, taxa, graph, zenoh) — deferred to Phase 1.3/1.4
- [x] Update tests: Ash refs in scrape_controller_test (5), parsed_law_test (1), uk_lrt_controller_test (comment)
- [x] Raw SQL test helpers kept as-is (insert via uk_lrt view, Electric proxy tests use uk_lrt table name)
- [x] Verify: all 1,211 tests pass
- [x] Fix Electric proxy: rewrite uk_lrt→legal_register_uk, lat→legal_articles_uk in shape requests
- [x] Verify: existing frontend works — 19,492 records synced via Electric proxy rewrite

## Notes
- Phase 1.1 created backwards-compat views — old resources still work during transition
- Can keep old UkLrt resource temporarily alongside new LegalRegister
- Old `/api/uk-lrt/*` routes should redirect or alias to `/api/laws/?country=uk`
