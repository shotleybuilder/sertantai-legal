# CV-S05d census: run-05 — CV-S05 strategy step 1 (2026-10-27)

**Reader:** the round 13 acceptance reading after the seed 19 fixes (`9a721593`; `05f66ca4` changes no behaviour). `input.jsonl.gz` is that run's dump, so no cache was rebuilt.

**Finder change:** Schedules are named as the reader names them (`finder.py`):
- an unnumbered Schedule is `sch`;
- a paragraph whose id holds its Part is `sch.N.pt.R.para.M`;
- "Part R of Schedule N" also reaches the paragraphs the Part holds in the document;
- `census.py` `ancestors` gives each Part and Schedule holding a ref.

| Measure | run-04 | run-05 |
|---|---|---|
| Silent candidate sentences | 64 | 64 |
| Unnamed stored refs | 234 (40 laws); 793 (53 laws) after seed 19 | 320 (44 laws) |
| Recall bench | 6/10 | 6/10 (unchanged) |

**Triage** (`out/triage.md`): every silent sentence and every unnamed ref is triaged. There are 16 real wordings (R1–R16), one decision for Jason (Q1), and the rest are known, doubtful or finder-side.

R1 is a regression from the seed 19 fix: `Parts.schedule_parts` expands a Part that only owns the paragraphs listed. It also includes an older `ApplicationClause` fault, where "Schedule 1 to this Order apply in relation to England only" sets the whole SI's application.

**Helpers:**
- `show.py LAW [REF…]`: the stored rows;
- `grepl.py LAW REGEX`: the stored sentences;
- `detail.py`: `out/silent_detail.txt`;
- `ugroups.py SKIP`: `out/unnamed_detail.txt`.
