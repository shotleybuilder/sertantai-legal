---
session: 'LAT Change Pipeline: Catalogues Across the Workflow — Meta Session'
type: meta
status: active
opened: '2026-11-21'
---

# Session: Catalogues Across the Workflow (ACTIVE)

## Problem

Each step's pattern catalogue reads the whole store, and they are run again and again. They share the machinery: `LawRunner` reads laws in parallel, so a run should take as long as its slowest law; `CatalogueCache` keeps each law's result; `SourceVersion` keys the cache. They share no readings, though: each catalogue parses the CLML itself. Two catalogues never took up the machinery. Jason (2026-11-21): a meta session, because it treats the catalogues in the round across the workflow, not per step, and optimises across it. The catalogue plan is reviewed by the Fable agent.

| Catalogue | Step | In parallel | Kept between runs |
|---|---|---|---|
| `lat.feed_patterns` | Feed reader | yes | yes |
| `lat.markup_patterns` | Markup reader | yes | yes |
| `lat.commencement_patterns` | Commencement reader | yes, but a 70 s serial check of the chosen examples (`LawScan.merge_law`, in law order) | yes |
| `lat.order_patterns` | Commencement reader | **no**: one order at a time, a document parsed up to 3 times | **no**: 96 s every run |
| `lat.extent_patterns` | Extent reader | yes | yes (`Extent.ReadCache`, shared with the extent check) |
| `lat.amendment_patterns` | Amending-law reader | yes | **no**: every amending law re-parsed every run (`Amendment.ReadLaw.doc`) |

Measured 2026-11-21, after the Commencement reader's speed fixes: commencement 438 s cold and 93 s warm (70 s of it the serial merge); orders 96 s. The same amending laws are parsed by the commencement, extent and amendment catalogues, each for itself. `ClmlRows` (a law's CLML rows, cached on file digests) is shared so far only within the Commencement reader.

## Todo

- ✅ Plan mode: approved 2026-11-21. Measured: a stored parsed `Doc` loads slower than parsing it (5.7 s against 6.8 s for 20 laws, 17× the size), so no shared document store. Timings from the step sessions, not new runs (Jason, Decision on timings: the recorded numbers now, a run log in the plan)
- ✅ The catalogue plan: `backend/data/code-reviews/catalogues-across-the-workflow-plan.md`
- ✅ Fable `reviewer`: the plan against `plan` (4 Blockers, 4 Majors, 1 Nit; about 70k tokens) and `zoom-out` (6 Majors, 2 Nits; about 73k), saved beside the plan; every finding triaged below
- ✅ Decision for Jason: continue the written plan as revised, and tackle cold runs too (2026-11-21)
- ⬜ The work, change by change, each proved by its fixtures unchanged in a dry run and its run record
- ⬜ One cold run of each catalogue profiled through the run log, for the pending session "Catalogue Cold Runs"
- ⬜ WORKFLOW's catalogue section (#195) and the step skills' catalogue lines
- ⬜ Close

## Dependencies

- ✅ Commencement Reader Speed Fixes (CLOSED, 940d40d2): `ClmlRows`, the own and amending readings cached under `Commencement.ReadVersion`, the commencement catalogue freed of the order reading
- Does not block Waste, Water and Climate: Commencement reader, which resumes on the new loop

## Timings (Jason, 2026-11-21)

Jason asked whether the step sessions record the catalogues' times. They do only sometimes, in prose, never cold, warm and serial side by side (e.g. extent 7 min 41 s cold, amendment 6 min for 527 laws, orders "30 s" undated). That is a gap for the round's retrospective. Decided: use the recorded numbers now, with their sources, and add a run log that every catalogue writes (`data/reports/catalogue-runs.jsonl`, the plan's change 1).

## Triage of the two Fable reviews

Saved: `backend/data/code-reviews/catalogues-across-the-workflow-plan-review-plan.md` and `…-review-zoom-out.md`. Every finding is Taken; none is Contested. Findings both reviews made are merged.

- **Taken, the root (zoom-out): the plan speeds warm runs, but the runs that cost are cold.**
  - Every reader fix moves a catalogue's version, so the step's runs after a fix are cold (`WORKFLOW.md:203`).
  - Cold is capped at 4 workers: total/4, not the slowest law.
  - Markup's cold run is about 25 min (`WORKFLOW.md:202`), not 5½.
  - Changes 2–4 help only warm runs. This reshapes the plan: see the Decision.
- **Taken, Blocker (both): the proof run overwrites fixtures for four of the six catalogues.** Feed, markup, extent and amendment write their fixture directory without `--accept`; only commencement and orders use `CommencementCatalogue.Target`. Fix: all six on `Target` (a dry-run directory unless `--accept` or `--out`). This is a small change in four steps' tasks.
- **Taken, Blocker (both): the run record does not fit every cache.**
  - `Extent.ReadCache.law/2` gives no hit signal.
  - Commencement would have two caches.
  - The record has no scope field (`--laws` runs).
  - `peak_mb` from two samples is no peak.
  - Its line repeats `CatalogueCache.summary/1`.
  - Fix: count hits and reads per cache; add a scope field; take peak memory from `:erlang.memory(:total)` sampled by a timer process, or drop it; the record replaces the summary and `merge:` lines.
- **Taken, Blocker (both): the machinery test cannot check functions.** `ModuleReach` follows modules, not functions; the tasks call `fetch` through their `LawRead` modules; a hand-kept list catches no new catalogue. Fix: drop change 6. The rule goes in WORKFLOW, and the run log shows any catalogue with no cache (its `hits` nil).
- **Taken, Blocker and Major (both): the order catalogue's choices were left open.**
  - `pairs/1` parses serially, and 87 of 1,904 listed orders sit under more than one Act.
  - The Act's title has no grouped query.
  - The examples could be all of them, or as `LawScan.scan/3`.
  - Errors: `LawRunner.ordered/3` has no rescue.
  - `Commencement.OrderRead` is not named.
  - `act/1`'s fallback parses the Act's document, not the order's.
  - The second version is unexplained, beside `Commencement.ReadVersion`, which excludes the catalogue's code.
  - Fix: each decided in the revised plan.
- **Taken, Major (plan): the amendment cache thrashes across scopes.** The task runs per family or `--laws`; with `by_law` in the key, alternate scopes overwrite each other; errors would be cached; `law_ref` costs two queries per amended law. Fix: key per amending law and amended law; never cache an error; memoise `law_ref` once a run.
- **Taken, Major (both): change 3's gain is unmeasured.** The 70 s is the selection plus `merge_law`, and the key's digest is serial. Fix: time `merge_law` alone and the digest before building; the fetch goes in a named module; the cold run its version edit costs is listed.
- **Taken, Major (plan):** no run list (purpose, time, writes, ask first), and no named tests or edge cases. Both go in the revised plan.
- **Taken, Nits:**
  - the #195 times as WORKFLOW gives them (104 s warm from 228 s, merge about 30 s);
  - `CatalogueRun` split into a pure record and an IO writer.

## Decision for Jason: what the catalogue work aims at

- **The question:** the reviews show the plan speeds warm runs, but a step's catalogue runs after a reader fix are cold, and the cold ones cost minutes (markup about 25 min, extent about 8, commencement about 7). What should the work aim at?
- **The aim it bears on:** a step that runs in hours, not days (the code review's flow, Decision 1 (a)); the new loop runs catalogues once per batch, `--laws` after each fix.
- **Options:**
  - **(a) The log and the safe proof first, then re-plan for cold runs.** Land the run log (change 1, as fixed) and every catalogue on `Target` now. Then read where each cold run's time goes, from the log and one profiled cold run each. Plan the cold-run work from that: narrower versions, so a fix stales only the laws its code reads, as `ClmlRows.Version` does; more workers where memory allows. Changes 2–4 are kept only where the log shows their warm gain matters.
  - **(b) Revise and build all now:** the plan as fixed, changes 1–5, warm-run gains, and cold runs left as they are.
  - **(c) The log only:** change 1 and `Target`, and stop.
- **Recommendation: (a).** It builds the two pieces both reviews need, makes no warm-run change the log may show is not worth it, and points the work at the cold runs a step actually pays for.

**Decided (Jason, 2026-11-21):** "the plan tackled the fast warm runs and didn't tackle the slow cold runs - kinda back-to-front. Given the plan is written, let's continue but also tackle cold runs too. Session structure for cold run refactoring to be decided."
- The written plan goes ahead, revised per every Taken finding (`catalogues-across-the-workflow-plan.md`, r2).
- Cold runs are tackled too. How their refactoring is held (this session, or its own) is the next decision.

**Decided (Jason, 2026-11-21):**
- **Cold runs** get their own pending meta session after this one, "Catalogue Cold Runs". It starts from one profiled cold run of each catalogue, recorded through the run log this session builds.
- **Code across steps:** "These sessions are across the round - steps don't 'own' their code - it's all project code after all. So yes, this session changes code across the steps. TDD." So change 4 (the amendment catalogue) and the move of every catalogue onto `Target` are made here, test first.

