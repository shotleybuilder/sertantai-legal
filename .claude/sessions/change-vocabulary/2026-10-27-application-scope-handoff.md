---
session: Application Scope Hand-off to Fractalaw
status: pending
opened: '2026-10-27'
depends_on: change-vocabulary/2026-10-27-cv-s05d-whole-reader-census.md
---

# Session: Application Scope Hand-off to Fractalaw (PENDING)

## Problem

The extent reader reads only territory (Jason 2026-10-27; CV-S05d decision, skill class KA). Laws also state which things, persons or activities they cover within a place. These sentences feed fitness, fractalaw's enrichment (personal, material, territorial, conditional and temporal scope), and fitness drives sertantai-compliance's applicability screener. Examples:
- "these Regulations do not apply in relation to any building in Wales other than an excepted energy building";
- "apply to lessors of social homes in England".

The CV-S05d census finds these sentences, mostly in the sweep's `noise:*` bins, and nothing hands them on. In run-01 there were 162 "apply" sentences across 106 laws. Of the 100 of those laws in `legal_register`, 61 have no fitness data (`has_fitness = false`), uksi 2025/1042 (lessors of social homes) among them.

## Todo

- ⬜ The extract: from the CV-S05d census input, read-only. Each application-scope sentence with:
  - law, provision ref, sentence;
  - polarity (applies / does not apply);
  - the place it names, if any;
  - the carve-out words ("other than …", "except …");
  - the sweep form.

  Facts as stated, no interpretation (readers carry, the fold means).
- ⬜ The priority list: laws with scope sentences and no fitness data (61 in run-01), ranked by Jason's screening interest.
- ⬜ Check the extract against fractalaw's existing fitness entities where they exist (39 laws), to see which sentences fractalaw already captured.
- ⬜ Agree the delivery with Jason: a file, a table, or Zenoh to fractalaw when it runs (fractalaw paused since 2026-10-23).
- ⬜ Store the run as evidence (`backend/data/experiments/application-scope-handoff/run-NN/`).

## Dependencies

- ⬜ CV-S05d run-02: the census rule that separates scope sentences (KA) from reader candidates
- ✅ CV-S05d run-01 input (`backend/data/experiments/cv-s05d-whole-reader-census/run-01/input.jsonl`)
