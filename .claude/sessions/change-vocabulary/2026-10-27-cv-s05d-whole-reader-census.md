---
session: 'CV-S05d: Whole-Reader Census'
status: suspended
opened: '2026-10-27'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
enables:
  - change-vocabulary/2026-10-27-application-scope-handoff.md (PENDING: scope sentences to fractalaw)
bugs:
  - pattern: "Extent census run-01 confirmed wrong bounds: 2017/3 s.182(2)(v) 'this Chapter' dropped (R10 NEW-3 still open); 1977/45 s.65(10)(b) 'subsections (1), (3) and (6) to (10) of this section' and (d) s.65(4),(5) dropped; 1999/9 s.17(c) same-extent item dropped; 1999/28 s.43 default S (text S+NI); 2010/29 s.49 'extends only to E+W, except that—' no default; 1968/64, 1968/60, 1936/49 'not extend to Scotland or, . . . to NI' default E+W+NI"
    category: extent_reader
    module: Extent (Lists, Named, Default, Same)
    affected: 9 laws
    fix: "CV-S05 round 13, from the census's counted shapes"
    status: open
  - pattern: "Extent census run-01 over-reach and lost sub-letters: 2007/28 'Part 1, 8, … of Schedule 18' read as the Act's own Parts (s.1 → same; 109 refs); 2014/2 qualifier object s.46 read as UK; 1980/66 'Subsection (3)(a)' stored s.264(3) + s.264(a); 1990/8 'Subsection (2)(aa)' stored s.70(2)"
    category: extent_reader
    module: Extent (Same, ListItems, RefList, Applies)
    affected: 4 laws
    fix: "CV-S05 round 13"
    status: open
  - pattern: "Extent census run-03 fix list S1-S17 (~65 laws; run-03/out/triage.md): exception-list items dropped (S1, 13 laws); RefList sub-letter runs (S2, 8); owner read as whole provision (S13, 9); or-lists / 'Part N of Schedule M' in same subjects (S3, 4); qualified companions dropped not withheld (S4, 7); own subsections/self/Chapter dropped (S5, 6); two statements in a sentence (S6, 6); whole-law default (S7, 3); territorial application unread (S8, 5); qualified read whole (S9, 2); '. . .' in number lists (S10, 3); locator read whole (S11); same item dropped (S12); 'cease to apply' inverted (S14); bracket then bare number (S15); reference read as item (S16, 2); other law's sections in an SI list (S17, 2)"
    category: extent_reader
    module: Extent (Lists, ListItems, Named, Same, Applies, Default), RefList
    affected: 65 laws
    fix: "CV-S05 round 13, then re-run this census (run-04) as its check"
    status: open
---

# Session: CV-S05d: Whole-Reader Census (SUSPENDED)

> **Suspended 2026-10-27** (Jason: "I don't need to look at the list"): the fix list S1–S17 (`run-03/out/triage.md`) is handed to CV-S05 round 13. Resume for run-04, the census re-run as round 13's check, then decide the permanent mix task.

## Problem

CV-S05c's census covered only one reader, the lettered list items (plus default sentences with items, added in run-03). It also checked them with the reader's own parser. Round 12's agent check (seed 17) still found three NEW, each outside what the census checks:
- the application reader read "in regulation 16, paragraphs (4) and (5)" as all of reg.16 (uksi 2020/818);
- `RefList` read "34 (f)" as all of reg.34, and the census's check uses `RefList`, so it shares the fault (uksi 2013/1506);
- the sweep labelled "They apply in relation to— (a) England … (b) Wales" `noise:procedure` (uksi 2016/1154).

Agent sampling keeps finding tail items because the tail outside lists was never listed (Jason 2026-10-27: "the long-tail work in cv-s05c did half a job … are we going to do a proper job in cv-s05d?").

Aim: census every sentence and every reader, checked independently of the reader, and audit the sweep's noise bin. Fixes then go by count, and the agent check becomes a final confirmation that finds nothing the census could have found.

## Todo

- ✅ An independent mention-finder (`finder.py`, scratchpad prototype; Jason 2026-10-27: "start cv-s05d"): a deliberately simple scanner sharing no code with the reader (no `RefList`, `Parts`, `Forms`). It records every provision a sentence names (with sub-letters, "34 (f)", "in regulation 16, paragraphs (4) and (5)") and every place and verb ("extend", "apply").
- ✅ The test, per sentence (`census.py`): everything named lands in a stored row of the right kind and place, or in an unread row (withheld); nothing is stored that the sentence doesn't name; a provision named narrower than what's stored is a candidate.
- ✅ Prototype by count (run-01; Jason 2026-10-27 "start cv-s05d"): recall 10/10 on rounds 9–12 agent NEW; 11 confirmed wrong-bound laws the agent rounds hadn't found or had recorded as fixed
- ⬜ Population: all catalogue sentences of every class (default, list, named, same, application, own paragraph, exception, unread), plus the sweep's 520 uncaught sentences, noise labels included.
- ⬜ Noise-bin audit: each sweep label checked by the same test; anything naming our provisions with a place and an extend or apply verb is flagged, not trusted.
- ✅ (run-02) Census rule: an "apply" statement whose place is qualified by "other than" / "except" / "any [thing] in", or names things or persons within a place, counts as scope (class KA, extract for fractalaw), not a reader candidate (run-02)
- ✅ (run-02/03) Silent candidates and over-reach triaged by wording, S1–S17, each confirmed on a law with `Extent.of`; handed to CV-S05 round 13 (Jason 2026-10-27: "I don't need to look at the list - we should have a clear idea about what right looks like by now")
- ⬜ run-04: re-run the census after round 13 as its check (the S1–S17 laws flagged no more; new flags triaged)
- ✅ run-03: finder misses fixed; over-reach list reviewed in full; the fix list S1–S17 consolidated (`run-03/out/triage.md`)
- ✅ run-01 stored; ⬜ Store each later run as evidence (`backend/data/experiments/cv-s05d-whole-reader-census/run-NN/`, as CV-S05c: manifest, scripts, input, outputs, README; scan for effect ids; commit by path in one step).
- ⬜ If it earns its place, build it as a read-only mix task (pure modules and tests) to run every round.

## Dependencies

- ✅ CV-S05c Shape Mining (closed): the masking, the run folder layout, run-01 to run-03 as the list baseline
- ✅ CV-S05 rounds 11–12 (reader at `b09df1be`; agent seeds 16 and 17)

## Prototype (run-01, 2026-10-27)

Python, no reader code: `dump.exs` writes each held law's stored reading (default, application, lists, applies) with its catalogue sentences and the sweep's uncaught ones (sweep form attached) from `ReadCache`, read-only. `finder.py` reads each sentence into segments (head, lettered items; a sub-listed item merged with its sub-items), and each segment into own provisions (with sub-letters, "34 (f)", locators "in regulation 16, paragraphs (4) and (5)", "of Schedule N" / "of Part N" owners, ranges and Parts/Chapters expanded from the CLML's own structure), places, verb, negation, qualifier (subject vs object), exceptions and other laws' provisions. `census.py` judges each named provision against the stored rows: ok, withheld, broader (only an ancestor stored, unnamed elsewhere), place, missing, q_read, q_missing, exc_held; whole-law statements against default / application; and stored refs that no statement of their place names (unnamed, over-reach).

**Recall bench (`bench.py`): 10/10.** Every agent NEW of rounds 9–12 is flagged: live where still open, else on the reading with the recorded faulty rows put back.

**Two NEW the census found that the agent rounds had recorded as fixed (live, verifying):**
- ukpga 2017/3 s.182(2)(v) "this Chapter" (ss.180–184): in no list (round 10 NEW-3, still open).
- ukpga 1977/45 s.65(10)(b) "subsections (1), (3) and (6) to (10) of this section" (namely-list): in no list; (d) "subsections (4) and (5) above and Schedules 12 and 13, so far as …": s.65(4), (5) in no list (KQ-like).

**run-01 results** (`backend/data/experiments/cv-s05d-whole-reader-census/run-01/`, README has the full list):
- 3,560 sentences in 3,358 laws; 129 silent flagged sentences (109 laws) and 516 unnamed stored refs (83 laws), not yet reviewed.
- Confirmed with `Extent.of` (bugs in the frontmatter):
  - 2017/3: ss.180–184 → E+W;
  - 1977/45: s.65(1), (7) → E+W;
  - 1999/9: s.15, Sch.3 → E+W+S;
  - 1999/28: default S;
  - 2010/29: no default;
  - 1968/64, 1968/60, 1936/49: default E+W+NI;
  - 2007/28: s.1, s.10 → `:same`;
  - 2014/2: s.46 → UK;
  - 1980/66, 1990/8: sub-letters lost.
- **Noise bin:** the sweep's `noise:*` holds real application statements, e.g. wsi 2014/3303 "apply in relation to live fish in Wales" and uksi 2026/335 "apply to buildings and building work in England". The "any building in Wales other than an excepted energy building" form (5 laws) is a scope question for Jason.
- **Precision:** tuned by sampling; the remaining candidates mix real defects and finder misses. Next: review them by shape (todo), then hand them to round 13.

## Decision: application to cases is fitness scope, not extent (Jason 2026-10-27)

Jason: "agree with the analysis, the breakdown and scopes. do the proposal". Fractalaw drills into application rules as enrichment, and that data drives sertantai-compliance's applicability screener ("we operate as a lessor of social homes").

**The extent reader stays territorial.** It reads where a provision extends or applies, as place codes. A statement of which things, persons or activities are covered within a place is fitness scope (personal, material, conditional), not extent. Example: "these Regulations do not apply in relation to any building in Wales other than an excepted energy building" (2012/3119, 2013/1959, 2014/579, 2015/767, 2016/285).
- These are not read into rows and are never NEW: skill class **KA**.
- They are territorial, and the reader's to read, where the place is the whole of what's said. Examples: "apply in relation to live fish in Wales", and 2016/1154's "They apply in relation to— (a) England …, (b) Wales".
- uksi 2025/1042 "apply to lessors of social homes in England" sets the bound England (territorial), and its "lessors of social homes" is fitness scope as well.

**Our coarser reading still feeds fractalaw.** The census's scope sentences go out as a located, uninterpreted extract, in a separate deliverable: PENDING session `2026-10-27-application-scope-handoff.md`. The run-01 count: 162 "apply" sentences in the sweep's bins, across 106 laws. Of the 100 of those laws in the register, 61 have no fitness data.

## run-02 (2026-10-27): the scope rule and the triage

Evidence: `backend/data/experiments/cv-s05d-whole-reader-census/run-02/` (README, `out/triage.md`, `out/verify3.txt`). The reading is unchanged; recall 10/10.

**The KA rule:** "apply" statements are sorted territorial / scope / both. `out/scope.tsv` is the hand-off extract (44 scope, 19 both).

**The 114 silent candidates, triaged by hand.** The real ones, with a sample of each wording confirmed by `Extent.of`, form the round 13 fix list:

| # | Wording | Laws |
|---|---|---|
| S1 | Exception lists' items dropped ("This Act, except— …", "Except for the following provisions …", "with the exception of— …", "but, with the exception of those provisions, …") | 1971/11, 1972/62, 1976/55, 1996/25, 1990/16, 1995/45, 1993/11, 1981/69 (no default), 1986/44, 1988/19 |
| S2 | Sub-letter runs lost in `RefList`, leaving garbage refs `s.264(a)` and `reg.72(b)(i)` | 2005/457, 1998/37, 1981/29, 2024/437, 2022/1273, 2013/1506, 1980/66, 1990/8 |
| S3 | "or"-lists in same-extent subjects; "Part N of Schedule M" read as the Act's Part N | 2019/530, 2022/6, 2020/1540, 2007/28 |
| S4 | Qualified companions dropped, not withheld | 2022/30, 2023/55, 2013/602, 2005/2060, 1980/34, 1977/38, 1972/71 |
| S5 | A provision's own subsections, self or Chapter dropped | 1992/43, 1973/32, 1998/31, 2017/3, 1977/45, 1988/19 |
| S6 | Two statements in one sentence | 1969/10, 1968/64, 1968/60 |
| S7 | Whole-law default misread or missing | 1999/28, 2010/29, 2021/30 |
| S8 | Territorial application unread | 2016/1154, wsi 2014/3303, 2026/335, 2025/1042, 1978/29 |
| S9 | Qualified subject or object read whole | 2006/41, 2014/2 |
| S10 | Repealed words (". . .") inside number lists | 1974/40, 1976/55, 1972/62 |
| S11 | Locator read whole | 1977/38, 2020/818 |
| S12 | Same-extent item dropped | 1999/9 |
| — | Also | 2023/55 "229 (and Schedule 22), 230 …" read as Schedules 230 …; 1972/20 "except as provided by section 189" read as an item; one-offs 1985/71, 1972/11 |

**Lesson:** CV-S05c run-03's default-sentence check labelled the S1 laws "KX by design". It checked them with the reader's own parser and looked only at the qualified items. The independent finder shows the unqualified items dropped too. A check that shares the reader's code shares its blind spots, which is CV-S05d's premise, now measured.

## run-03 (2026-10-27): the round 13 fix list

Evidence: `backend/data/experiments/cv-s05d-whole-reader-census/run-03/` (README, `out/triage.md`, `out/verify4.txt`). The reading is unchanged; recall 10/10. 113 silent candidate sentences; 358 unnamed refs in 53 laws, all reviewed.

**The fix list:** 17 wordings in about 65 laws (bugs in the frontmatter). The new ones since run-02:

| # | Wording | Example |
|---|---|---|
| S13 | An owner read as the whole provision | "subsections (1) to (6) of section 11" → all of s.11 UK, 1995/45; also 2016/12, 2007/1843, 1980/51, 1985/71, 1977/38 |
| S14 | "cease to apply in relation to England" stored as applies E | 2013/27 |
| S15 | "229 (and Schedule 22), 230 …" read as Schedules 230 … | 2023/55 |
| S16 | "except as provided by section 189" read as an item | 1972/20, 1988/52 |
| S17 | Another law's sections in an SI's list | 2010/490, 2017/1012 |

S1 gained 1991/65 and 1982/49. S6 gained 1973/26 (default E+W+S; the text gives E+W), 1987/27 and 1982/53.

**Left:** about 15 finder misses and about 12 doubtful, listed in the triage. Round 13's re-run of this census (run-04) is its check.
