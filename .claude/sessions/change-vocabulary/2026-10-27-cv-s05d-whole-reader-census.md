---
session: 'CV-S05d: Whole-Reader Census'
status: active
opened: '2026-10-27'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
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
---

# Session: CV-S05d: Whole-Reader Census (ACTIVE)

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
- ⬜ Census rule: an "apply" statement whose place is qualified by "other than" / "except" / "any [thing] in", or names things or persons within a place, counts as scope (class KA, extract for fractalaw), not a reader candidate (run-02)
- ⬜ Count candidates by shape (CV-S05c's masking) and rank them; review with Jason; hand the ranked shapes to CV-S05 round 13.
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
