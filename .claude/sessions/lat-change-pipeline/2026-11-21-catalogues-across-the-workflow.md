---
session: 'LAT Change Pipeline: Catalogues Across the Workflow — Meta Session'
type: meta
status: closed
opened: '2026-11-21'
closed: '2026-11-21'
outcome: success
summary: >
  Every whole-store catalogue now on the shared machinery and recorded: all six write a dry run unless --accept (four had overwritten their fixtures on every run), every run goes to catalogue-runs.jsonl (cold/warm, serial part, peak memory), and the orders, commencement merge and amendment catalogues are kept between runs. Warm runs went from 100 s, 92 s and 467 s to 9.2 s, 24.1 s and 9.6 s, each output identical. The plan's two Fable reviews (all findings Taken) showed it had sped warm runs and not the slow cold ones; cold runs go to the pending "Catalogue Cold Runs".
decisions:
  - what: The recorded times as the before, and a run log every catalogue writes
    why: Jason — the step sessions record times only now and then, a gap for the retrospective
    result: data/reports/catalogue-runs.jsonl, one line a run, from every catalogue
  - what: Continue the written plan, and tackle cold runs too, in their own pending session
    why: "Jason — the plan was back-to-front: it sped the fast warm runs, not the slow cold ones"
    result: Catalogue Cold Runs pending, starting from the profiled cold runs
  - what: A meta session changes code across steps, test first
    why: "Jason — steps don't own their code; it's all project code"
    result: the amendment, extent, feed and markup tasks changed here
  - what: The amendment cache per amending law, not per pair
    why: per pair adds example builds to every cold run; the catalogue's scope is one growing list
    result: warm 467 s to 9.6 s, cold unchanged (423 s)
  - what: No shared store of parsed documents
    why: a stored Doc loads slower than parsing (6.8 s against 5.7 s for 20 laws) and is 17 times the size
    result: only small derived results are shared (ClmlRows)
metrics:
  warm_s_before: { orders: 99.6, commencement: 91.8, amendment: 467.0 }
  warm_s_after: { feed: 2.3, markup: 7.2, commencement: 24.1, orders: 9.2, extent: 2.3, amendment: 9.6 }
  cold_s: { feed: 718.8, markup: 1700.8, commencement: 397.7, orders: 85.9, extent: 1814.9, amendment: 422.7 }
  commencement_serial_s: { before: 72.5, after: 1.4, merge_reread_share: 59.8 }
  fable_review_tokens: { plan: 70391, zoom_out: 72905 }
lessons:
  - title: A speed plan should start from the runs that cost, not the runs that are easy to speed
    detail: The plan cached warm runs; the zoom-out review showed every reader fix makes the next catalogue run cold (markup 28 min, extent 30 min), which none of it touched. Ask which runs a step actually pays for first.
    tag: tooling
  - title: A catalogue run without --accept must never write the fixtures
    detail: Four of six catalogues wrote their fixture directory on every run, so any check run overwrote the fixtures. Found by the Fable plan review, not by use.
    tag: tooling
  - title: Measure the serial part's split before caching it
    detail: A call-time trace (:erlang.trace_pattern with :call_time; eprof was not available) showed 59.8 of 63.4 s in one function, which made the merge cache worth its key.
    tag: tooling
  - title: Fixtures fall behind the store between a step's rounds
    detail: The extent fixture read 4,239 laws; the store now holds 5,807. A cold run after an unrelated version bump shows 23 new patterns that are store growth, not a regression. Compare with a run from before the change, not the fixture, when a fixture is older than the store.
    tag: data
bugs:
  - pattern: "The extent catalogue's fixture is behind the store: it read 4,239 laws on 2026-11-15, the store now holds 5,807 — a cold run shows 23 new patterns and higher counts, none gone"
    category: fixture-behind-store
    module: test/fixtures/extent_patterns
    affected: 1568
    fix: "Review and accept at the Extent reader's next round"
    step: Extent reader
    status: open
  - pattern: "The amendment catalogue's fixture is behind the notes table: the same 1,436 amending laws and 161 patterns, but 34 more provisions read (15,008 → 15,042) and 14 patterns' counts changed"
    category: fixture-behind-store
    module: test/fixtures/amendment_patterns
    affected: 34
    fix: "Review and accept at the Amending-law reader's next round"
    step: Amending-law reader
    status: open
  - pattern: "The markup catalogue's totals.too_large depends on the held set an --accept starts from (425 in the fixture, 398 on a re-run with identical patterns and examples), so the fixture is not reproducible byte for byte"
    category: catalogue-count-unstable
    module: ChangeVocabulary.MarkupPatterns.LawScan
    affected: 1
    fix: "Count too_large from the final selection, not every example tried; or leave totals out of the byte-for-byte proof"
    step: Markup reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/catalogue_target.ex
  - backend/lib/sertantai_legal/scraper/catalogue_run.ex
  - backend/lib/sertantai_legal/scraper/catalogue_run/log.ex
  - backend/lib/sertantai_legal/scraper/order_catalogue/law_read.ex
  - backend/lib/sertantai_legal/scraper/order_catalogue/version.ex
  - backend/lib/sertantai_legal/scraper/commencement_catalogue/merge_read.ex
  - backend/lib/sertantai_legal/scraper/amendment/catalogue_read.ex
  - backend/lib/sertantai_legal/scraper/amendment/catalogue_version.ex
  - backend/lib/sertantai_legal/scraper/amendment/law_doc.ex
  - backend/data/code-reviews/catalogues-across-the-workflow-plan.md
  - backend/data/code-reviews/catalogues-across-the-workflow-plan-review-plan.md
  - backend/data/code-reviews/catalogues-across-the-workflow-plan-review-zoom-out.md
  - docs/lat-change-pipeline/WORKFLOW.md
depends_on:
  - 2026-11-21-commencement-reader-speed-fixes
enables:
  - lat-change-pipeline/2026-11-21-catalogue-cold-runs
---

# Session: Catalogues Across the Workflow (CLOSED)

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
- ✅ The work, change by change, each proved by its fixtures unchanged in a dry run and its run record
- ✅ One cold run of each catalogue profiled through the run log, for the pending session "Catalogue Cold Runs"
- ✅ WORKFLOW's catalogue section (#195) and the step skills' catalogue lines
- ✅ Close

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

## Change 1 (commits 138af384, f474cc97)

- **1a:** all six catalogues write a dry run unless `--accept` or `--out` (`CatalogueTarget`, moved from `CommencementCatalogue.Target`). Feed, markup, extent and amendment had been overwriting their fixtures on every run.
- **1b:** every run is recorded (`CatalogueRun`, `CatalogueRun.Log`) in `backend/data/reports/catalogue-runs.jsonl` and printed as its last line, e.g. `run: warm, law: 1 hits 0 read, 0.2 s (serial 0.1 s), 142 MB, 4 workers`. Each cache's hits and reads are counted; `Extent.ReadCache.fetch/2` now gives a hit or read. Memory is sampled every 500 ms.
- Tests: 7,125 across the catalogues, the extent reader and the architecture tests.

## The runs after change 1 (2026-11-21, `backend/data/reports/catalogue-runs.jsonl`)

| Catalogue | Cold | Warm | Dry run against the fixtures |
|---|---|---|---|
| Feed | 719 s, 1,860 laws read, **1 worker**, 1.3 GB | 2.3 s | identical |
| Markup | 1,701 s, 6,156 laws read, 3 workers, 3.9 GB | 7.2 s | identical but `totals.too_large` (425 → 398) |
| Commencement | (its version had not moved: warm) | 91.8 s, serial 72.5 s, 3 workers | identical |
| Orders | 107 s, no cache, serial throughout | 99.6 s | identical |
| Extent | 1,815 s, 5,807 laws read, **2 workers**, 2.2 GB | 2.3 s | differs: the store has grown (below) |
| Amendment (527 laws) | 408 s, no cache, 3 workers, 2.9 GB | 467 s | differs in counts only (below) |

The differences, each explained, none from this session's code:
- **Markup's `too_large`** counts the examples tried that would not hold. The selection tries the fixture's held examples first, and the fixture's total was written by the 11-20 `--accept` run, which started from the earlier held set. Same patterns, same examples.
- **Extent:** its fixture (11-15) read 4,239 laws; the store now holds 5,807 (the Fire and Waste, Water and Climate fetches). 23 new patterns and higher counts; none gone. For the Extent reader's next round.
- **Amendment:** the same 1,436 amending laws and 161 patterns; 34 more provisions read (15,008 → 15,042) and 14 patterns' counts changed, from the notes table the later rounds' re-parses changed since its fixture (11-15). For the Amending-law reader's next round.

**For "Catalogue Cold Runs":**
- The cold runs are long: markup 28 min, extent 30 min, feed 12 min.
- They ran on fewer workers than allowed: feed on 1, extent on 2, at a load of about 7 on this machine. `LawRunner.Guard`'s choice from the machine's state is the first thing to examine.
- The warm runs are seconds, except commencement (72.5 s serial), orders (uncached) and amendment (uncached), which changes 2–4 address.

## Changes 2–4 (commits 4b3e2ece, 4e1f0d0b, 19fcff13)

| Catalogue | Warm before | Warm after | Proof |
|---|---|---|---|
| Orders (`OrderCatalogue.LawRead`) | 99.6 s, uncached, serial | 9.2 s | dry run identical to the fixtures, cold and warm |
| Commencement (`MergeRead`) | 91.8 s, serial 72.5 s | 24.1 s, serial 1.4 s | identical to the fixtures, cold and warm |
| Amendment (`Amendment.CatalogueRead`) | 467 s, uncached | 9.6 s | identical to the run before the change (527 laws), cold and warm |

- **The commencement probe** (call-time trace of a warm run): of the 63.4 s serial part, 59.8 s was re-reading the chosen examples in the merged input (`SentencePatterns.read/3`, 1,610 calls); the merge 0.4 s, the selection 0.7 s.
- **One change from r2:** the amendment cache is per amending law, not per pair. Per pair, every pair builds its own first example of each pattern, adding work to every cold run. The catalogue runs over one growing list, so the scopes rarely alternate. `law_ref` is computed once a run.
- **`Amendment.LawDoc`** holds `ReadLaw.doc/1`, which delegates to it, so the amendment catalogue's version covers only what it reads.
- **Docs:** WORKFLOW (the whole-store catalogues section: the machinery rule, the dry run, the run log, the warm times) and the five step skills' catalogue lines, which now point to the run log.
- **Which doc did this session change?** WORKFLOW and the skills above. No rule was decided, so RULES.md is unchanged.

