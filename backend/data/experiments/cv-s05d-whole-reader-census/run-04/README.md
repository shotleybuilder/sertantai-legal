# CV-S05d census: run-04, round 13's check (2026-10-27)

**Reader:** after CV-S05 round 13 (`fbf94b8b`). The scripts are run-03's.

| Measure | run-03 | run-04 |
|---|---|---|
| Silent candidate sentences | 113 | 64 (51 cleared, 2 new: finder-side) |
| Unnamed stored refs | 358 (53 laws) | 234 (40 laws) |
| Recall bench | 10/10 | 6/10 |

**Recall bench:** the four live defects of rounds 10–12 (2017/3, 2020/818, 2013/1506, 2016/1154) are fixed, so they are no longer flagged. Every fixed defect put back in a copy of the reading is still flagged.

**Fix-list check** (`out/fix_list_check.txt`, fresh reads with `Extent.of`): every wording reads as its text states. The 4 rows marked MISS are expectation errors of the check, not reader faults:
- 1981/29 and 1992/43 have no default, so their bound comes from the list alone;
- 2016/12 s.14 is in Part 1, which extends to the UK;
- 2014/2 s.46 is listed plainly ("(c) section 46").

**The run found 7 regressions in round 13's first pass, all fixed before this final run:**
- 3 loose application reads;
- 1 unanchored range;
- 2 owner rewrites;
- 1 reference guard.

**New unnamed refs:** all 39 are correct reads the finder can't name: "subsections (1) to (6) of section 11", Sch.18's Parts, "229 (and Schedule 22), 230", "Paragraphs (28) … of regulation 5", and the two exception clauses of 1973/26.
