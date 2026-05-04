# Issue #79: Enacted By tab QA — continuation

**Started**: 2026-05-04
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/79
**Ended**: 2026-05-04
**Prior session**: 2026-04-25-issue-79.md
**Commits**: `b4aaac8`, `3f234f9`, `e8c40c8`, `badc835`, `05da6b0`, `1f15d3e`, `6715034`, `100692e`

## Context
Continuing #79 focused on the Enacted By tab of /admin/graph.
linked_* columns removed in #82 — law_edges now reads source columns (168,616 edges, +45,921).
Tab has 5 QA filter buttons, si_code_families derived table, enacted-by-qa skill ready.

## Todo

### Parser fixes
- [x] PowersClause back-reference fix — scan full sentence for footnote refs before "powers conferred"
- [x] Remove EU regulations/directives from @enabling_types (eur, eudr, eut don't confer domestic powers)
- [x] Test: back-reference pattern (UK_uksi_1997_654 Good Laboratory Practice)
- [x] Test: EU directive filtering

### New family member
- [x] Add 💙 PUBLIC: Data family (models.ex, family_rules.ex, health_safety.ex, 3 frontend files, FAMILY_VALUES.md)
- [x] Bulk classify 40 laws as PUBLIC: Data (Data Protection Acts, Online Safety Act, Digital Economy Act, Electronic Communications, NIS Regulations)

### Admin UI
- [x] Rebuild edges button on /admin/graph with staleness indicator
- [x] POST /api/graph/rebuild-edges endpoint

### Skills
- [x] Created enacted-by-family-qa skill
- [x] Updated skill: dual family/family_ii classification guidance
- [x] Updated skill: title keyword cross-check (step 2c)
- [x] Updated skill: title-confirmed false positives (step 2d)

### Family QA completed (all 💙 families)
- [x] OH&S: Occupational / Personal Safety — 12 reclassified
- [x] OH&S: Mines & Quarries — 6 nulled (coal industry restructuring)
- [x] OH&S: Gas & Electrical Safety — 7 reclassified (EMC, RoHS, equipment safety)
- [x] OH&S: Offshore Safety — clean
- [x] FIRE — 6 reclassified (heavy fuel oil, enterprise reform, air navigation)
- [x] FIRE: Dangerous and Explosive Substances — clean
- [x] PUBLIC: Consumer / Product Safety — 3 reclassified (fireworks, medical devices, gas redress)
- [x] PUBLIC: Building Safety — 7 reclassified (housing acts, leasehold reform, mobile homes)
- [x] PUBLIC: Data — 40 new classifications
- [x] TRANSPORT: Air Safety — 1 reclassified (working time)
- [x] TRANSPORT: Maritime Safety — 3 reclassified (tonnage tax, harbours EIA, working time)
- [x] TRANSPORT: Road Safety — 7 reclassified (working time, level crossings, ATV, tractor cabs)
- [x] TRANSPORT: Rail Safety — 2 family_ii added (working time)
- [x] PUBLIC — 2 reclassified (housing H&S rating, strikes minimum service)

### Remaining
- [ ] Run enacted-by-qa skill against outlier population to validate parser accuracy
- [ ] Family QA for 💚 environment families
- [ ] Family QA for 💜 HR families
- [ ] Family QA for remaining families (HEALTH, FOOD)
- [ ] Reverse-fill: infer missing SI codes from family (1,239 laws, mostly pre-2000)

## Notes
- ~60 reclassifications across all 💙 families
- Product Security Act: family + family_ii dual classification (Consumer/Product + Data)
- Working time pattern: transport primary, HR: Working Time as family_ii
- "fire" keyword in "Firearms" causes false positives in title cross-check
- Coal Industry Acts are industrial policy, not mine safety — nulled
