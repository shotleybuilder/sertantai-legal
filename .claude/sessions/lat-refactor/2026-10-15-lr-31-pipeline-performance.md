---
session: 'LR-31: Pipeline Performance'
status: pending
opened: 2026-10-15
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-31 Pipeline Performance (PENDING)

## Problem

A full-corpus run (the LR-25 wave, its dry runs, a relabel) takes about 1.5 hours for 1,066 laws: about 5 s per law, minutes for the largest. Each verification cycle in LR-29 cost a full run. Jason (2026-10-15): "is there a way to change the architecture to speed things up. Thinking about the xml store".

## Profile (2026-10-15, WIA 1991 / UK_ukpga_1991_56, 8,288 rows)

Measured alongside a running dry run, so absolute times are inflated; the proportions hold.

| Phase | Time |
|---|---|
| store read + gunzip | 55 ms |
| one xmerl parse (`SweetXml.parse`) | 5.2 s |
| `EffectTarget.tree` (xpath per element) | 2.2 s |
| changes feed from the store (Atom XML → effects) | 4.2 s |
| `LatParser.parse` | 31 s |
| `fetch_changes` (rows + notes + effects) | 76 s |
| `ChangeCollector.collect` (amending laws) | 97 s |

**The store is not the bottleneck** (55 ms). The cost is:
1. **xmerl**, Erlang's DOM parser: slow, heavy trees, and xpath walks over them.
2. **The same document parsed several times per law:** `LatParser` (rows), `CommentaryParser` (notes), `EffectTarget.tree` (targets).
3. **The changes feed re-parsed from Atom XML each time**, twice per pipeline (`law_effects`).
4. **Amending laws re-parsed for every law they amend.** Since LR-25's leak fix, the doc cache is scoped to one law. A large amending Act is parsed once per affected law.
5. **Laws run sequentially** on a multi-core machine.

## Plan (in order of payoff for effort)

- **A. Parallel laws.** `mix lat.wave_preview`, `mix lat.reparse` and `mix lat.relabel` run 4–6 laws at once (`Task.async_stream`, bounded). Each law is independent: its own transaction and store reads. Memory is flat since the LR-25 leak fix (about 300 MB per worker). Watch the DB pool size, long transactions, and lat_events ordering.
- **B. Derived artefacts in the store.** Next to each `data.xml.gz`, a compact term file (`.etf.gz`) of its parsed result:
  - the changes feed's effects;
  - each amending law's index (`AmendingLaw.Doc`: ids, text, structure).

  Each is keyed by the source file's content hash and rebuilt only when that changes. No XML is parsed twice across a run. This removes most of the collect cost and the feed cost.
- **C. Parse each document once per law.** Share one parsed tree across `LatParser`, `CommentaryParser` and `EffectTarget.tree` (a moderate refactor of `LatStagedParser`).
- **D. Later, if A–C aren't enough:** replace xmerl with a streaming parser (Saxy) on the hot paths. The largest per-parse gain, but the largest change: the parser and collectors use xpath throughout.

Expected: A + B take a full run from about 1.5 h to roughly 10–15 min. Measure on an idle machine before claiming it.

## Todo

- ⬜ Clean baseline profile (idle machine): the per-law phases for a sample of small, average and large laws; whole-run time
- ⬜ Gemini review of the plan
- ⬜ **Jason: D1** — scope (A + B first; C; D later)
- ⬜ A: parallel runs — tests first; output identical to a sequential run (compare reports)
- ⬜ B: derived artefacts — tests first; equality gate: the effects and Docs from the artefact equal those from the XML across the corpus
- ⬜ C: one parse per document — zero-diff gate (`mix lat.parse_snapshot`)
- ⬜ Re-profile; record before and after

## Dependencies

- ✅ LR-25 leak fix (flat memory: the precondition for A)
- ⬜ After the LR-25 wave (the wave runs on verified code, not a fresh optimisation); A may come sooner if Jason wants faster dry runs
