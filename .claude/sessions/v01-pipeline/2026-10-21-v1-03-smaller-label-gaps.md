---
session: 'V1-03: Smaller Label Gaps on Laws from 2002'
status: pending
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
---

# Session: V1-03: Smaller Label Gaps on Laws from 2002 (PENDING)

## Problem

After V1-01 and V1-02, the rest of the v0.1 label load on UK laws from 2002 on is a set of smaller gaps (AR measure dry run, 2026-10-21): 1,366 undated changes in 133 laws (SI 2010/2214 198, 2020 c.7 151, SI 2005/1806 and its wsi twin 103 each, 2004 c.20 82); 144 insertions not in the register; rows whose id carries a duplicate disambiguator (`s.1(2)n1`) have no ancestors, so they inherit nothing (552 rows / 90 laws, 141 / 36 ≥2002; AR-00 open bug); feed effects named only in text ("Part 2B inserted", 24 effects, LR-27); a retained repeal read as everywhere where the note names a territory (8 rows: 2010/404 reg.14, 2020/7 s.8; LR-17). Several LR open bugs look stale (fixed by LR-25 under other wording) and need checking.

## Todo

- ⬜ Disambiguator ancestors: `LatStatus.ancestors` strips the `nN` suffix (test first); preview the 90 laws
- ⬜ Undated changes ≥2002: attribute the 1,366 rows by stage (as LR-40: pointer → locator → read → commencement); fix the stages with ≥2002 weight, the rest known limits
- ⬜ Insertions not in the register ≥2002 (144) and text-only feed refs (24 effects): count what each reaches; fix or known limit
- ⬜ LR-17's 8 retained-repeal rows: read the amending provisions from the store (an amendment-rules slice), or a known limit
- ⬜ Check and close stale open bugs: LR-20's note-fact fallback and provenance entries, LR-23's note-join spread, LR-27's text-only refs (each against today's code)
- ⬜ Preview only the affected laws, splice; batch into the v0.1 relabel (V1-00)

## Dependencies

- ⬜ V1-01, V1-02 (their previews first, so splices don't overlap)
- ✅ AR measure dry run (2026-10-21)
