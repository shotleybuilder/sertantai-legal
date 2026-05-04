# Amends tab on /admin/graph

**Started**: 2026-05-04
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/79

## Todo

### UI improvements
- [x] Add title to Law column in Amends tab (match Enacted By tab pattern)
- [x] Backend: added u.title_en to amends SQL + handler response
- [x] Frontend: AmendsMismatch type + Law column shows title + law_name

### Skill
- [x] Create amends-family-qa skill (follow enacted-by-family-qa pattern)

### Amends QA completed (all 💙 families)
- [x] OH&S: Occupational — 3 reclassified (phytosanitary, azo dyes, hazardous substances)
- [x] OH&S sub-families (Gas & Electrical, Mines, Offshore) — 2 family_ii added
- [x] TRANSPORT Safety (Air, Maritime, Road, Rail) — 2 nulled, 2 kept after review
- [x] FIRE + FIRE: D&E — 1 reclassified (firearms→PUBLIC), 1 family_ii added (fertiliser→AGRICULTURE)

## Notes
- Amends consensus >80% is very strong signal for reclassification
- 60-80% needs judgment — cross-family amendments are sometimes legitimate
- "Firearms" matching FIRE keyword is a recurring false positive
