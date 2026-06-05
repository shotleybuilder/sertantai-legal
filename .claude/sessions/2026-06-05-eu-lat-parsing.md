# Title: EU LAT Parsing + fractalaw DRRP/Fitness

**Started**: 2026-06-05
**Meta-plan**: .claude/plans/customer-onboarding.md (2.3 item 4, 5.2)

## Todo
- [x] Assess EU law XML structure — same CLML namespace, just EURetained/EUBody + EUTitle/EUChapter
- [x] Extend existing LatParser — no new parser needed, just container + structural elements
- [x] Parse LAT for EU laws in QQ corpus — session created, 5 enriched, 65 parsing in progress
- [x] Update fractalaw for DRRP extraction on EU laws — actor model updated, REACH duties +48%
- [ ] Update fractalaw for Fitness extraction on EU laws — briefed, fractalaw-side work
- [x] QA enrichment results — DRRP 13-49% hit rate, fitness sparse (EU patterns needed)

## Notes
- EU LRT metadata improved in previous sessions (graph inference, title keywords, Tier 0 making)
- EU laws on legislation.gov.uk use different XML schema from UK domestic (Akoma Ntoso vs CLML?)
- ~507 EU laws in QQ corpus, ~140 have family assigned
- EU XML uses same CLML namespace — not Akoma Ntoso as suspected
- Parser extended: EURetained/EUBody containers, EUTitle→Part, EUChapter→Chapter
- EU uses `art.` prefix (not `reg.`), provision field is "Article N" not just "N"
- Tested with eudr/2010/75 (Industrial Emissions): 431 rows parsed correctly
- 24 new tests + 2 fixtures, all 94 tests green (commit 1e97477)
- Zenoh pipeline works as-is for EU laws — no sertantai-legal changes needed
- **21:50** Briefing note created at ~/fractalaw/data/EU-LAW-SUPPORT-BRIEFING.md — ready for fractalaw work
- LAT parse session created: lat-parse-eu-qq-2026-06-05-0731 with 70 EU laws (26 eur, 43 eudr, 1 eudn)
- REACH parsed + enriched: 1186 LAT rows, Making, 127/1186 provisions got DRRP (10.7% — low, EU modal verbs differ)
- Fixed reparse bug: LatParseReviewModal cached lastParsedName preventing re-trigger (commit 550ba4c)
- Fractalaw updating actor model for EU patterns — iterating on REACH
- **08:15** REACH re-enriched with updated actor model: duties 71→105 (+48%), DRRP provisions 127→159 (+25%)
- **08:20** Fixed modal completion loop — reset was firing on every tick, not just open transition (commit 90db3b9)
- **08:20** Added 13 EU actors to @holder_options in baserow.ex (EU: Member State, ECHA, EFSA, EEA, SC: Registrant, Downstream User, etc.)
- EU family coverage improved 24%→96% via expanded title keywords (commit dda68aa)
- Fixed 4 EU directives mis-assigned HR instead of OH&S (safety and health of workers)
- Fitness sparse for EU laws — fractalaw needs EU-specific fitness dictionaries

**Ended**: 2026-06-05 09:15
**Commits**: `1e97477`, `550ba4c`, `90db3b9`, `dda68aa`

## Summary
- Completed: 5 of 6 todos (fitness is fractalaw-side work)
- Files: lat_parser.ex, health_safety.ex, environment.ex, baserow.ex, LatParseReviewModal.svelte, 2 XML fixtures
- Outcome: Extended LAT parser for EU law XML, 24 new tests, 70-law parse session created, DRRP enrichment validated (13-49% hit rate). EU family coverage 24%→96%.
- Next: Fractalaw fitness dictionaries for EU laws, parse remaining 65 EU laws, Baserow re-sync
