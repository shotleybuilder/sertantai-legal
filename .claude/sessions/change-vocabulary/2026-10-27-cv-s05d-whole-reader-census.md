---
session: 'CV-S05d: Whole-Reader Census'
status: active
opened: '2026-10-27'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
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

- ⬜ An independent mention-finder: a deliberately simple scanner sharing no code with the reader (no `RefList`, `Parts`, `Forms`). It records every provision a sentence names (with sub-letters, "34 (f)", "in regulation 16, paragraphs (4) and (5)") and every place and verb ("extend", "apply").
- ⬜ The test, per sentence: everything named lands in a stored row of the right kind and place, or in an unread row (withheld); nothing is stored that the sentence doesn't name; a provision named narrower than what's stored is a candidate.
- ⬜ Prototype by count (scratchpad, read-only; ask Jason before running). Must flag every agent NEW from rounds 9–12 (list in the CV-S05 session) before any modules are written.
- ⬜ Population: all catalogue sentences of every class (default, list, named, same, application, own paragraph, exception, unread), plus the sweep's 520 uncaught sentences, noise labels included.
- ⬜ Noise-bin audit: each sweep label checked by the same test; anything naming our provisions with a place and an extend or apply verb is flagged, not trusted.
- ⬜ Count candidates by shape (CV-S05c's masking) and rank them; review with Jason; hand the ranked shapes to CV-S05 round 13.
- ⬜ Store each run as evidence (`backend/data/experiments/cv-s05d-whole-reader-census/run-NN/`, as CV-S05c: manifest, scripts, input, outputs, README; scan for effect ids; commit by path in one step).
- ⬜ If it earns its place, build it as a read-only mix task (pure modules and tests) to run every round.

## Dependencies

- ✅ CV-S05c Shape Mining (closed): the masking, the run folder layout, run-01 to run-03 as the list baseline
- ✅ CV-S05 rounds 11–12 (reader at `b09df1be`; agent seeds 16 and 17)
