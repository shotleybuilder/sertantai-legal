# Title: 4.5 — Aggregate All QQ Site CSVs

**Started**: 2026-06-04 04:30
**Meta-plan**: .claude/plans/customer-onboarding.md (4.5)
**Skill**: customer-onboarding-import

## Todo
- [x] List all QQ site CSVs — 20 new + BSC = 24 total
- [x] Process each through import pipeline — all 24 done
- [x] Seed applicability with union semantics — 275 yes, 60 no
- [x] Fix seed_applicability union bug (yes never downgrades to no)
- [x] Create scrape session for 118 missing laws — scraping in progress (102/118)
- [x] Update customer-onboarding-import skill (flags, multi-site, missing-law step)
- [x] EU making classification: Tier 0 in MakingDetector (eur=making, eudr/eudn=not_making)
- [x] EU family assignment: title keyword fallback (152/316 matchable, 48%)
- [x] Complete 118-law scrape — done, cleaned to 44 valid records
- [x] Fix misidentified Scottish/Welsh laws — ~45 SSIs redirected from uksi, 3 Acts (asp/asc/ukpga) fixed, 2 manual Enhesa SI→chapter corrections
- [x] Clean scrape session — removed 66 pre-existing laws, added 1 missing SSI (ssi_2006_140)
- [ ] LAT parse for domestic yes-laws missing LAT
- [ ] Re-sync Baserow with expanded dataset

## Notes
- 4 match count variants across sites: 595, 632, 677 — different Enhesa register versions
- Union semantics: yes always wins across sites (fixed in seed_applicability)
- EU metadata gap: no SI codes or dc:subject on legislation.gov.uk — structural, not parser bug
- Title keyword matching covers 48% of NULL-family EU laws with existing terms
- Misidentified law patterns: Enhesa S.S.I. refs matched as uksi, scraped completely wrong English laws
- Tool edge cases: Enhesa "S.I." (not "S.S.I.") for Scottish laws, Acts coded as S.I. (wrong chapter numbers)
- 8 uksi laws kept — valid sertantai laws that happened to share year/number with Enhesa SSIs
