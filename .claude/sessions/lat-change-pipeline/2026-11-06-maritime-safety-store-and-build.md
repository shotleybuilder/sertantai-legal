---
session: "Maritime Safety: Store and build"
status: closed
opened: 2026-11-06
closed: 2026-11-06
outcome: success

summary: >
  Step 11 for TRANSPORT: Maritime Safety passed on every rule. Two parked bugs were fixed first: the measures came out of the build's version, and every step's gate now re-runs after a build (mix lat.gates). Seven gates pass; Extent and Amending fail, both already parked. The first two builds' digests differed for 18 of 138 laws with nothing stored moving. The cause was Conflicts.values listing its derived sources in atom-table order (Decision 2, B, Jason). After the fix, all 285 built laws' digests are identical across two builds, 0 stale, the staleness hand check 30/30, golden 27/27.

decisions:
  - what: "Decision 1, A: each step's check task returns a Gate.Step and lat.gates re-runs all nine; --check --family ends with it"
    why: "a value, not printed text that a wording change would break silently; the cost is the label fold's 12½ min, skipped with --no-gates"
    result: "Maritime gates: 7 PASS; Extent (5) and Amending (1) FAIL, both parked with their steps"
  - what: "Decision 2, B: the digest covers what is stored (no tiers, no conflicts); Conflicts.values takes its sources from a list (Evidence's code, by Jason's leave); two full rebuilds of 285 laws"
    why: "the digest moved with nothing stored moving (OTP 26+ atom-table order of a small map's atom keys); Gemini Flash agreed with B and asked for all 285 to be digested"
    result: "all 285 digests identical across builds C and D"
  - what: "Build time accepted: Maritime 117 laws in 39 s; the big golden Acts' slowdown (EPA 1990 513 s vs 156 s) parked"
    why: "the family build fits a fix round; the slowdown is on the golden Acts with 4 workers, to measure apart"
    result: "big-act-build-slowdown parked with Store and build"

metrics:
  build: { maritime_laws: 117, maritime_seconds: 38.6, other_laws: 168, other_seconds: 795, epa_1990_seconds: 513 }
  repeatable: { first_pass_differing: "18 of 138 (conflict order only)", after_fix: "285 of 285 identical" }
  stale_after: { built: 285, stale: 0, unbuilt_with_lat: 882 }
  gates: { pass: 7, fail_parked: 2, fail_new: 0 }
  hand_check: { seed: 1111, items: 30, ok: 30, wrong: 0, doubtful: 0, tokens: 58398 }
  golden: "27/27 from inputs (946 s) and from the store"
  tests: "mix test 10184 passed; Credo no new issue"

lessons:
  - title: "A digest of values derived on read is not a digest of the build"
    detail: "ChangeDigest hashed Store.for_law's resolved struct, including the conflicts it derives on read. Two digests of the same stored rows differed in 18 laws, so the build looked unrepeatable. A SQL fingerprint of the stored claims, before and after a rebuild, separated storage (stable) from reading (not)."
    tag: data
  - title: "Never build a list by iterating a map with atom keys (OTP 26+)"
    detail: "A small map's atom keys iterate in atom-table order, which moves with module load order between VMs, and the flip shows only now and then. The same class as Measures' Jason key-order fault. Take the order from a list."
    tag: tooling
  - title: "Dropping a glob from a version hash pulls in everything that reaches it"
    detail: "Taking measures/*.ex out took seven sample-drawing checks with it (not the three found by grep), because VersionCoverageTest walks compiled references. Let the test find them."
    tag: tooling
  - title: "Run the gates on the final code"
    detail: "Build C re-ran every gate after the Evidence fix and matched build A. A later fix to covered code needs its own gate re-run, which lat.gates makes one command."
    tag: tooling

bugs:
  - pattern: "A rebuild after a step closes moves the earlier steps' gates and nothing re-runs them: three Maritime gates passed and fail today (Sources 11, Extent 4 causes, Amending 1 group); the OH&S lesson of 2026-10-30 (S01) recurs"
    category: gates-not-rerun-after-rebuild
    module: mix lat.vocabulary (--check)
    affected: 3
    fix: "Each step's check task returns a Gate.Step; mix lat.gates --family F re-runs all nine and exits non-zero on any failure; --check --family ends with it (--no-gates skips) (4812e6a5)"
    step: Store and build
    status: fixed
  - pattern: "measures/*.ex is in ChangeVocabulary.Version's globs, though no build reads the measures: a new measures module (Measures.HandSample) marks every built law stale (the class of the parked label-in-build-version)"
    category: measures-in-build-version
    module: ChangeVocabulary.Version (patterns)
    affected: all built laws (285)
    fix: "measures/*.ex dropped; the seven sample-drawing checks that reach it added to except:; version_test.exs (4812e6a5)"
    step: Store and build
    status: fixed
  - pattern: "Conflicts.values/1 takes its derived sources from the Evidence.tiers() map, whose atom keys iterate in atom-table order (OTP 26+), so a change's conflicts come in an order that moves between VMs (18 of 138 laws' digests differed with nothing stored moving; e.g. UK_uksi_2010_1075)"
    category: conflict-order-atom-table
    module: change_vocabulary/conflicts.ex (Conflicts.values/1)
    affected: 18 laws
    fix: "Sources taken from the list [:markup, :feed]; fixed in this step with Jason's leave (Decision 2, B); conflicts_test (4812e6a5)"
    step: Evidence
    status: fixed
  - pattern: "ChangeDigest digested values Store.for_law derives on read (tiers, conflicts), so it could differ between runs over the same stored rows"
    category: digest-covers-derived
    module: ChangeDigest
    affected: 18 laws
    fix: "tiers and conflicts dropped from the digest; change_digest_test; lat.changes_digest --built (4812e6a5)"
    step: Store and build
    status: fixed
  - pattern: "The big golden Acts build 3x slower than on 2026-10-31 with 4 workers (EPA 1990 513 s vs 156 s alone; RTPA 1988 368 s, HSWA 1974 345 s); the family build itself is fast (Maritime 38.8 s)"
    category: big-act-build-slowdown
    module: ChangeVocabulary.Build (or LawRunner workers)
    affected: 4 laws (golden)
    fix: "Time EPA 1990 alone, then with 4 workers, to separate contention from a code slowdown; profile the slower"
    step: Store and build
    status: open

artifacts:
  - backend/lib/mix/tasks/lat.gates.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/step.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/stale_sample.ex
  - backend/lib/sertantai_legal/scraper/change_digest.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/conflicts.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/data/reports/store-build/maritime-stale-sample-seed-1111.json
  - backend/data/reports/change-vocabulary/verdicts/s11/maritime-safety/round-1-staleness-seed-1111.json
  - backend/data/code-reviews/2026-11-06-maritime-store-build-decision-2-gemini.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/store-build-check/SKILL.md
  - .claude/skills/measures-check/SKILL.md

depends_on:
  - 2026-11-06-maritime-safety-measures

enables:
  - "Maritime Safety: Labels side by side (step 12)"
---

# Session: Maritime Safety: Store and build (CLOSED)

## Problem

WORKFLOW.md step 11 for TRANSPORT: Maritime Safety: the change register is repeatable, fast enough for a fix round, and honest about staleness. Today all 285 built laws are stale on code version (Measures' new module moved the build's version: a parked bug), and the build's check re-runs only the sources gate, so three Maritime gates that had passed failed unseen (the second parked bug). Plan approved 2026-11-06 (plan mode).

## Todo

- ✅ 1. Open the session with these todos and Decision 1; restore point
- ✅ 2. Bug: measures out of the build's version (TDD), marked fixed
- ✅ 3. Bug: the build's check re-runs every step's gate — `Gate.Step`, each check task returns it, `mix lat.gates`, `--check --family` calls it (TDD), marked fixed
- ✅ 4. The staleness hand sample in code: `mix lat.stale --sample` (draw test)
- ✅ 5. Build A (gates printed, failures matched to parked bugs), digest; build B, digest, `cmp`; build time
- ✅ 6. `mix lat.stale` 0 stale; golden from inputs 27/27
- ✅ 7. One hand-check agent pass (seed 1111), VERDICTS saved and pooled
- ✅ 8. Docs (WORKFLOW step 11, store-build-check, measures register), `mix test`, Credo; close; commits, no push

## Dependencies

- ✅ Maritime Safety: Measures (closed and pushed, 0dfd9953)

## Pass rule (fixed at plan)

1. Measures bug fixed: `VersionCoverageTest` passes with `measures/*.ex` dropped; a test asserts `Version.files()` holds no measures file.
2. Gates bug fixed: `Gate.Step.summary/1` unit-tested; `mix lat.gates --family "TRANSPORT: Maritime Safety"` prints all nine steps.
3. Every failing gate is one already parked with its owning step (Extent reader, Amending-law reader); a new one is raised and parked.
4. Digest after build A and build B identical (`cmp`).
5. Maritime build time printed and accepted by Jason.
6. `mix lat.stale`: 0 built laws stale after the build.
7. One agent pass, 30 laws (20 built, 10 unbuilt), seed 1111: no verdict wrong; tokens recorded.
8. Golden 27/27 from inputs; `mix test`; Credo clean.

Out of scope: every step's gate logic and readers; the sibling bug "label fold in the build's version" (moving `labels/5`, larger, stays parked); the other Store and build bugs.

## Decision 1: how the build's check knows each gate's result

- **Question:** should `lat.gates` take each gate's result as a value the check task returns, or read its printed PASS/FAIL line?
- **Aim:** `binds-on-date` — a rebuild that moves an earlier step's gate must show, or labels rest on a step that no longer passes.
- **Options:** A. each check task's `run/1` returns a `Gate.Step` (step, pass, failing count): one return value per task, gate logic untouched. B. parse the printed line: no task change, but a wording change breaks it silently.
- **Recommendation:** A. Cost either way: the label gate is the label fold (about 12½ min), so `--check --family` takes about 15–20 min; `--no-gates` skips them for a fix round.
- **Decided:** A, approved with the plan (Jason 2026-11-06).

## Parking list

- Store and build: big-act-build-slowdown — the golden Acts build ~3x slower with 4 workers; time accepted, parked (Jason 2026-11-06)

## Results

**1. Restore point:** `maritime-store-build-before` (provision_changes, provision_change_claims, lat_events; lat_events 57,113 rows).

**2. Measures out of the build's version.** `measures/*.ex` dropped from `ChangeVocabulary.Version`. Not three but seven check modules in the covered globs reach the measures (each draws a sample through `Measures.Draw`): `amendment/check_sample`, `check_strata`, `amending_law/extent/check`, `change_vocabulary/evidence_sample`, `label_sample`, `label_strata`, `merge_sample`. All seven went to `except:`, and `VersionCoverageTest` passes, so nothing a build reads reaches them. New `change_vocabulary/version_test.exs`. Version 4e6f2d657825 → 7df56ac9a12b.

**3. Every step's gate re-run.** `Gate.Step` (`change_vocabulary/gate/step.ex`, 3 tests): each of the nine check tasks' `run/1` now returns its result (gate logic untouched). `mix lat.gates --family F` re-runs them in order, prints one line per step, and exits non-zero on any failure. `lat.vocabulary --check --family F` ends with it (`--no-gates` skips; `--laws` keeps the sources gate only). Smoke: `lat.amending_check --gate` on Maritime returns `pass?: false` (its parked group).

**4. The staleness sample in code.** `Measures.StaleSample` (4 tests; seed tuple `{s, 11, 11}`, `Draw.shuffled`, built then unbuilt), `mix lat.stale --sample FILE --family F --built 20 --unbuilt 10 --seed S`. `--family` scopes the built laws only: Maritime has no unbuilt LAT law, so the unbuilt are drawn from every law holding LAT. Two draws at seed 1111 `cmp`-identical.

**5. Build A** (code 7df56ac9a12b):
- The 168 other built laws (OH&S, golden and others) first: 796 s with 4 workers. The slowest were EPA 1990 513 s (14,565 changes; 156 s alone on 2026-10-31), RTPA 1988 368 s, HSWA 1974 345 s and the Fire Precautions Act 249 s.
- Maritime Safety's `--check`: 117 laws built in **38.8 s**; golden from the store 27/27. The whole check, gates included, took 921 s.
- **Every step's gate**, re-run by `lat.gates`: Sources, Feed, Markup, Commencement, Merge, Evidence and Label fold PASS. Two FAIL, both already parked with their owning steps:
  - Extent reader, 5 failing: UK_ukpga_1992_52's extent rules are stale (1), and 4 no-bound causes are not named;
  - Amending-law reader, 1 group not named.
- No new failure. The exit is non-zero, as designed.
- Digest A: 138 laws (Maritime plus golden), written in 7 s.
- **Build B:** the other 168 laws took 789 s; Maritime built in 38.6 s. `lat.stale`: **0 of 285 built laws stale** (code 7df56ac9a12b). The hand sample at seed 1111, drawn twice, is `cmp`-identical.
- **The digests DIFFER** for 18 of 138 laws, among them MSA 1995. The counts are equal, and so are the recorded inputs.

**Why they differ.** In each differing law, the only thing that changes is the order of the `conflicts` list in `resolved`. For example, UK_uksi_2010_1075 lists `[law_text vs markup, law_text vs feed]` in one run and `[law_text vs feed, law_text vs markup]` in the other.
- Conflicts aren't stored. `Store.for_law` derives them on read (`Evidence.derive` → `Conflicts.values/1`).
- `Conflicts.values/1` takes its derived sources by iterating `Evidence.tiers()`, a map with atom keys. Since OTP 26, a small map's atom keys iterate in atom-table order, and that varies with module load order from one VM to the next. This is the class behind Measures' Jason key-order fault.
- So two digest runs over the same stored rows can differ.
- **The stored rows are repeatable:** a SQL fingerprint of two differing laws' stored claims (key, target, position, source, attribute, value, ref) is identical before and after their rebuild. Four dumps in a row with no rebuild are also identical; the order flips only now and then.

## Decision 2: the digest and the conflict order

- **Question:** how should repeatability be proved, now that the digest includes a value derived on read whose order isn't fixed?
- **Aim:** `binds-on-date`, through "same inputs, same register": a digest that moves when nothing moved hides a build that really did move.
- **Options:**
  - **A.** Fix the digest in this step: `ChangeDigest` covers what is stored, dropping the derived `tiers` and `conflicts`. Park the conflict order as an Evidence bug. Then rebuild the 138 digested laws once (about 10 min; the golden laws include EPA 1990), digest before and after, and `cmp`.
  - **B.** Option A, plus a one-line fix in `Conflicts.values/1`: take the sources from the list `[:markup, :feed]`, not the map. That is Evidence's code, so it needs your say-so for this bug. It changes no stored row, but it makes every reader of `Store.for_law` stable: the conflict report, the gates' examples, the samples. Cost: `conflicts.ex` is in the build's version, so all 285 built laws go stale, and the repeat becomes a full rebuild of all 285, twice (about 14 min each).
  - **C.** Leave the digest alone, park the bug, and record repeatability as not proved.
- **Recommendation:** B. The digest fix is this step's own. The Evidence line is one line, changes no stored data, and the same fault would make the Evidence and Label samples flip between runs.

**Second opinion (Gemini 2.5 Flash):** `backend/data/code-reviews/2026-11-06-maritime-store-build-decision-2-gemini.md`. The reply was cut off near the end of point 4 (MAX_TOKENS); its answer was complete by then.
- It confirms the diagnosis is plausible and sufficient, with nothing in the evidence against it.
- It chooses **B**: A only hides the symptom from the digest, and C gives up the gate.
- It names two risks:
  - another derived value or map iteration in `Store.for_law` or the digest;
  - aliases or claim order being unstable in a subtler way.
- Its proof: two full builds of all 285 laws, then all 285 digests compared, not only the 138.
- **Taken:** digest all 285 laws, and check `Store.for_law` for other map-order derivations before the rebuild.

**Build time** (Jason 2026-11-06): Maritime's 38.8 s accepted; the big-Act slowdown parked.

**Decided: B** (Jason 2026-11-06, after Gemini).
- `ChangeDigest` drops `tiers` and `conflicts`.
- `Conflicts.values/1` takes its sources from `[:markup, :feed]`. This is Evidence's code, fixed by Jason's leave for this bug.
- One test each was red first: in this VM, feed came before markup.
- `lat.changes_digest --built` digests every built law; two runs over one store give the same 285 digests.
- Code 7df56ac9a12b → the next version, so all 285 laws are stale, then rebuilt twice (builds C and D).
- **Build C** (code 22970e8c0bd4): other laws 779 s. Maritime `--check`: 117 laws in 38.6 s; golden from the store 27/27. The gates match build A: 7 pass, and Extent (5) and Amending (1) fail, both parked.
- **Build D:** other laws 795 s; Maritime 41 s.
- **Digests C and D, all 285 built laws: `cmp` IDENTICAL.**

**6. Stale:** `mix lat.stale` shows 0 of 285 built laws stale (code 22970e8c0bd4); 882 laws hold LAT with no build.

**7. Hand check** (one agent pass, **58,398 tokens**). Sample `data/reports/store-build/maritime-stale-sample-seed-1111.json`: 20 Maritime built laws, plus 10 unbuilt laws from all LAT laws; drawn twice, `cmp`-identical.
- **Result:** OK 30, wrong 0, doubtful 0.
- **What the agent didn't recompute:** the content hashes. Its independent evidence was file mtimes and LAT `updated_at`.
- **VERDICTS:** `verdicts/s11/maritime-safety/round-1-staleness-seed-1111.json`. Pooled by `lat.verdicts`: 0/30 wrong. The pool's statistical bound prints NOT PASSED: 30 items give a 95% upper bound of 9.5%, against its 2% limit. The step's own rule is "no verdict wrong", which is met, as on OH&S at 30/30.
