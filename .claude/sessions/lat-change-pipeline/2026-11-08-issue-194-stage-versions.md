---
session: "Store and build: rebuild only what an edit changes (#194)"
status: closed
opened: 2026-11-08
closed: 2026-11-08
issue: 194
outcome: success

summary: >
  The one change-vocabulary version is split into two stages, each stale on its own
  code and inputs. The changes stage (readers, merge and evidence: ChangeVocabulary.Version)
  and the labels stage (the fold, moved to ChangeVocabulary.Fold: FoldVersion) each hold
  exactly the files they reach. Builds record an output digest, and switched refreshes record
  the fold version, the digest they folded and the fold's inputs. mix lat.vocabulary
  --build --stale walks the stages. After the split, 285 laws were rebuilt in 198 s and 266
  re-folded in 95 s; digests and timelines were byte-equal, golden stayed at 26/27, and
  lat.stale --strict --switched gave 0.

decisions:
  - what: Two stages (changes; labels), not three
    why: Only merged changes are stored, so a readers stage needs a new table. Jason leaned to two stages and Gemini to two plus a profile, which cost no extra run
    result: "No reader-output table; the profile (readers ~62 s, merge and evidence ~41 s of the slowest law's 112 s) decided the follow-up"
  - what: Each version is exactly its stage's reach (StageSplitTest), with explicit change_vocabulary/ files in Version
    why: A wildcard pulled in checks, read passes and the fold, so any edit to them staled all 285 builds
    result: "A fold-only, check-only or measure-only edit stales no built change; a shared file stales both stages"
  - what: Labels are stale by digest, not by time
    why: Under the old time rule, any rebuild staled every switched law's labels, even when the output was unchanged
    result: "11 laws rebuilt after the re-fold left 0 labels stale"
  - what: No third stage; park parse-the-XML-once instead (Jason, option 2; Gemini agreed)
    why: A third stage helps only merge and evidence edits, at the cost of a table, a migration and a version; four readers each spend 5–13 s on the same body
    result: "readers-reparse-body parked for Store and build"
  - what: 1.8 GB a law stays; the guard reads the cgroup's room
    why: Measured peaks are 1.9 GB for the Town and Country Planning Act 1990, then 1.2 GB, then under 0.75 GB; MemAvailable was the host's, not the 14 GB cap's
    result: "4 at once under the cap, with 14.6 GB seen"

metrics:
  rebuild: { laws: 285, seconds: 198.2, workers: 4, before_split_seconds: 232.6 }
  refold: { laws: 266, seconds: 94.7, failed: 0 }
  equality: { change_digests_equal: 285, timelines_equal: 1145 }
  golden: { pass: 26, of: 27, failing: "COPA s.101 (parked)" }
  stale_after: { builds: 0, switched_labels: 0, old_path: 901 }
  peaks_gb: { tcpa_1990: 1.9, rta_1988: 1.2, ea_1995: 0.71, rest_max: 0.69, baseline: 0.11 }
  tcpa_1990_phases_s: { alone: 112, inputs: 9, readers: 62, merge_evidence: 41, write_digest: 11 }

lessons:
  - title: Make a version's file list exactly its stage's reach, tested both ways
    detail: "VersionCoverageTest only checked that a version missed nothing. Its wildcard also held 36 files no build reaches (checks, read passes, the fold), and each was a full rebuild waiting to happen. StageSplitTest asserts set equality with ModuleReach from the stage's entry, so an extra file fails as surely as a missing one."
    tag: tooling
  - title: A staleness test on time stales on any re-run; compare output digests
    detail: "labels_behind_changes compared refresh time with build time, so a rebuild giving identical changes staled all 266 switched labels. Recording the build's output digest and the digest folded removed the cascade with no loss: a different output still stales."
    tag: data
  - title: A function the build shares a file with puts the whole fold in the build's version
    detail: "ModuleReach works file by file, so labels/5 living in change_vocabulary.ex beside changes/5 made the build reach the fold. Moving it to its own module, with no delegate (a delegate keeps the atom edge), was the whole fix."
    tag: tooling
  - title: tprof call_time credits library calls to no phase
    detail: "Own-time by module put most time in Enum, lists and xmerl. A scratch script timing each phase's public call, as the build makes it, gave the answer in one run without touching build code (which would have moved the Version hash)."
    tag: tooling
  - title: The machine's free memory is not a capped run's
    detail: "Under systemd-run -p MemoryMax=14G, /proc/meminfo shows the host. The guard now walks /proc/self/cgroup up through memory.max − memory.current."
    tag: infrastructure

bugs:
  - pattern: "Four readers of one law each take 5–13 s on the same CLML body (the Town and Country Planning Act 1990: markup facts 9 s, markup 13 s, application 10 s, expiry 5 s), apparently each parsing the XML; parsing once and sharing would save ~30 s of the slowest build"
    category: readers-reparse-body
    module: change_vocabulary.ex (build/6) and the readers' XML entry points
    affected: "every build; ~30 s of the 112 s slowest law"
    fix: "Parse the body once in the build and pass the document to each reader; prove byte-equal digests, re-time by phase, re-measure peaks"
    step: Store and build
    status: fixed  # 2026-11-08-parked-owner-bugs
  - pattern: "ChangeVocabulary.Version hashed the label fold, so a fold-only fix marked every built law stale"
    category: label-in-build-version
    module: change_vocabulary.ex (labels/5) and change_vocabulary/version.ex
    affected: "285 built laws per fold edit"
    fix: "Fold moved to ChangeVocabulary.Fold; FoldVersion; StageSplitTest"
    step: Store and build
    status: fixed
  - pattern: "The build's wall time is one law, UK_ukpga_1990_8; its build is unprofiled"
    category: build-long-pole
    module: ChangeVocabulary.Build
    affected: "1 law, the rebuild's wall time"
    fix: "Profiled 2026-11-08 (phases-tcpa-1990.txt): readers ~62 s, merge and evidence ~41 s of 112 s; the speed-up is readers-reparse-body"
    step: Store and build
    status: moved
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/fold.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/fold_version.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/fold_inputs.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/stale_stages.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/lib/sertantai_legal/scraper/label_staleness.ex
  - backend/lib/sertantai_legal/scraper/label_refresh.ex
  - backend/lib/sertantai_legal/scraper/law_runner/guard.ex
  - backend/test/sertantai_legal/architecture/stage_split_test.exs
  - backend/data/code-reviews/2026-11-08-stage-versions-choice-gemini.md
  - backend/data/code-reviews/2026-11-08-third-stage-choice-gemini.md
  - backend/data/reports/stage-versions/ (gitignored run logs)

depends_on:
  - 2026-11-07-issue-193-silent-staleness

enables:
  - "#195 incremental catalogues"
  - "Store and build: readers-reparse-body"
  - "Family 3 (Environmental Protection) steps rebuild earlier families once per round"
---

# Session: Store and build: rebuild only what an edit changes (CLOSED)

## Problem

One code version, `ChangeVocabulary.Version`, covers the readers, merge, evidence and the label fold. So any edit stales all 285 built laws, whatever it touched: the Maritime switch-over paid four full rebuilds in one step. A rebuild also stales every switched law's labels, even when the changes come out the same, because label staleness compares times. Design: scaling review items 1, 3 and 5 (`backend/data/reports/pipeline-scaling/2026-11-07-scaling-review.md`).

**Aim:** a code edit rebuilds only the stage it can change, and no stage's output can be out of date without `lat.stale --strict` saying so (AIMS, the time machine). No reader, merge, evidence or fold output changes.

## Todo

- ✅ Open the session: plan in; branch `stage-versions`; Gemini's review saved and triaged
- ✅ Tests first: the cases in pass rule 1 (split, staleness, digest, guard, stage walk)
- ✅ Move the fold out and split the version: `ChangeVocabulary.Fold`, `FoldVersion`, `Version` narrowed, the coverage and split tests
- ✅ Digests and label staleness: `changes_digest` on the build; `fold_version`, `changes_digest` and `fold_inputs` on the refresh; `refold/1`; the three reasons; the `FoldCache` key
- ✅ `--build --stale`, the stage walk, and the RULES rule (`earlier-families-rebuild-once-per-round`)
- ✅ The parallel budget: the cgroup room in `Guard`; measured peaks keep 1.8 GB a law; the slowest law timed by phase (a scratch script, no build code)
- ✅ The runs (Jason's go, 2026-11-08): restore point; before; `--build --stale`; after; golden; `lat.stale --strict --switched`; memory peaks and the profile
- ✅ Close: DATA-ARCHITECTURE, WORKFLOW, TESTING, RULES; session and #194 closed; commits; pushed (Jason 2026-11-08)

## Dependencies

- ✅ #193 silent staleness (closed, f191b116): reader-stamped readings, switched-label reasons, `lat.stale --strict --switched`
- ✅ `ChangeDigest` and `mix lat.changes_digest --built` (label-tools run-time session)

## Plan (approved 2026-11-08)

Plan file: `~/.claude/plans/gleaming-doodling-matsumoto.md`.

**The design:**
1. The fold (`labels/5`) moves from `change_vocabulary.ex` to `ChangeVocabulary.Fold`. Its callers migrate, with no delegate.
2. There are two versions: `Version` covers the changes (readers, merge, evidence) and `FoldVersion` covers the labels.
3. Digests:
   - `changes_built` records `changes_digest`;
   - `labels_refreshed` records `fold_version`, the `changes_digest` it folded, and `fold_inputs`.
4. Switched labels are stale on `:fold_version`, `:labels_behind_changes` (now a digest comparison, not a time comparison) and `:fold_inputs`.
5. `lat.vocabulary --build --stale` walks the stages: the changes, then a re-fold of the switched labels.
6. `Guard` sees the cgroup's memory cap. `@per_law_kb` is set from the measured peaks of the 10 heaviest laws, and the build of the Town and Country Planning Act 1990 is profiled by phase.

**Pass rule:**
1. Tests:
   - the two versions share no file, and the build reaches no fold file;
   - label staleness: a digest equal with a later build → fresh; a different digest, a moved fold version, moved fold inputs or no digest → stale;
   - a comment-only reader rebuild stales no labels;
   - `Guard` takes the cgroup's room;
   - coverage for both versions.
2. After the catch-up:
   - all 285 change digests byte-equal before and after;
   - the switched timelines equal before and after the re-fold;
   - golden unchanged at 26/27, with COPA s.101 the one failure;
   - `lat.stale --strict --switched` exits 0;
   - the rebuild of 285 takes under 4 minutes.
3. `mix test`, Credo, Dialyzer and Sobelow pass.

**Out of scope:** #195; a third stage; speeding up the Town and Country Planning Act 1990's build; the old register path; COPA s.101 and Ports Act s.29.

## Decision: two stages, plus a profile

- **Question:** #194 asked for three stages (readers; merge and evidence; fold). Only the merged changes are stored, so a readers stage would need a new table for each reader's output. Should we have two stages or three?
- **Aim:** rebuild only what an edit changes, without a stored record going stale silently.
- **Options:**
  1. two stages;
  2. three stages, with a reader-output table;
  3. two stages plus a per-phase profile of the slowest law, the profile deciding whether a third stage follows.
- **Decided:** two stages; Jason leaned to this. Gemini Flash recommended option 3. The profile costs no extra run, because it rides on the memory measure, so it is taken.

**Gemini triage** (`backend/data/code-reviews/2026-11-08-stage-versions-choice-gemini.md`):

| # | Finding | Triage |
|---|---|---|
| 1 | A stage's version must hash all the code it runs | **Taken, as built.** `SourceVersion` hashes the files, `VersionCoverageTest` holds each version to the modules it reaches, and #193 made the file lists current (`__mix_recompile__?`). |
| 2 | Inputs outside the fingerprint stale silently | **Taken.** The fold reads more than the changes: rows, start, made date and title, the CLML body and the known-limit periods. The refresh records these as `fold_inputs`. |
| 3 | A non-deterministic stage defeats the digest | **Taken.** `ChangeDigest` sorts and serialises deterministically. All 285 digests byte-equal before and after the rebuild is the check. |
| 4 | Per-reader staling; storing each reader's output | **Contested.** Per-reader staling is the per-law dependency tracking the review rejected, since a missed edge means silent staleness. A reader-output table waits for the profile. |
| 5 | Caching within stages | **Out of scope.** That is #195 (catalogues), and the extent and feed caches already do it. |

## The code (5cc00dea)

- **Fold moved:** `labels/5` moved from `change_vocabulary.ex` to `ChangeVocabulary.Fold.labels/5`, which takes the changes already built. Callers build first (`golden.ex`, `lat.vocabulary`, the tests) or read from the store (`LabelSource`). `Ref.version/1` is shared.
- **Two versions, each exact:** `StageSplitTest` asserts that each version's files are exactly what its stage reaches.
  - `ChangeVocabulary.Version` is the build's reach. Its list now names the `change_vocabulary/` files it needs, not a wildcard, and its `except:` gained the read passes and the commencement catalogues no build reaches.
  - `FoldVersion` is the timeline path's reach, from `LabelSwitch` and `Fold`, stopping at the stores (`FoldVersion.boundaries/0`: `Store.Inputs`, `Version`, `LabelTimeline`).
  - Shared files (`Readers.Markup`, `Territory`, `Store`, `ChangeDigest`, …) are in both, so an edit to one stales both stages.
  - A fold-only edit stales no built change.
- **Digests:**
  - `changes_built` records `changes_digest`: `ChangeDigest.build/2` over the changes as stored (read back in the transaction) and the start.
  - A switched `labels_refreshed` records `fold_version`, `changes_digest` (from `Store.digest/1`) and `fold_inputs`. `FoldInputs` fingerprints the rows as the fold reads them, the made date and title, the CLML body's text and the known-limit rows.
  - `changes_version` is no longer written.
- **Staleness:**
  - `:timeline_version` is replaced by `:fold_version`.
  - `:labels_behind_changes` now compares digests, not times. A refresh recorded before #194 counts as behind.
  - New reason `:fold_inputs`.
  - `FoldCache` is keyed on `FoldVersion`.
- **The walk:** `StaleStages` lists stale changes and stale labels, and `label_action/1` chooses refold, refresh or re-parse. `lat.vocabulary --build --stale` runs the walk, and `lat.stale` reads the stale changes from it.
- **Guard:** `probe/0` reads the room under any memory limit on its cgroup or the cgroup's ancestors. Under `systemd-run -p MemoryMax=14G` it reports "14.6 GB available under the cgroup's limit".
- **The profile:** timed by a scratch script, `phases.exs`, which calls each phase as `Build.law` does. It replaces the planned phase-timing option, so no build code changes and no Version hash moves. `:tprof` was tried first but credits library calls to no phase.
- **Checks:**
  - `mix test`: 10,276 passed.
  - Credo diff: no new issues. Two were fixed by splitting `LabelStaleness.reasons` and `build_laws`.
  - Dialyzer and Sobelow passed.

## Before the runs (`backend/data/reports/stage-versions/`)

- **`stale-before.txt`:**
  - all 285 built laws are stale on `code_version`, because the version moved with the split;
  - all 266 switched laws' labels are stale on `fold_version`, `labels_behind_changes` and `fold_inputs`, because no digests have been recorded yet;
  - the old path has 901 laws stale, as before.
- **`digests-before.tsv`:** 285 laws.
- **`timelines-before.tsv`:** 1,145 laws, md5 per law over every period field except ids and times (`timelines.sql`).

## Results (`backend/data/reports/stage-versions/`)

- **Restore point:** `issue194-stage-versions` (provision_changes, provision_change_claims, lat_label_timeline).
- **`--build --stale`** (`build-stale.log`):
  - changes stage: 285 stale, all rebuilt in **198.2 s** with 4 workers, inside the 14 GB cap;
  - labels stage: 266 re-folded with no build in **94.7 s**, 0 failed, 0 refreshed, 0 needing a re-parse.
- **Byte-equal:**
  - all 285 change digests (`digests-before.tsv` = `digests-after.tsv`);
  - all 1,145 timelines (`timelines-before.tsv` = `timelines-after.tsv`).
- **Golden** (`golden.log`): 26/27, with COPA s.101 the one failure, as before.
- **`lat.stale --strict --switched`** (`stale-after.txt`): exits 0, with 0 of 285 builds stale and 0 of 266 switched labels stale. The old path's 901 are unchanged.
- **A rebuild with the same output stales no label, live:**
  - the peak runs rebuilt 11 laws after the re-fold;
  - digests were still equal (`digests-after-peaks.tsv`);
  - `lat.stale --strict --switched` still gave 0.
- **Memory peaks** (`peaks.log`, each law alone in its own unit, baseline 112 MB):

  | Law | Peak | Alone |
  |---|---|---|
  | Town and Country Planning Act 1990 | 1.9 GB | 112 s |
  | Road Traffic Act 1988 | 1.2 GB | 38 s |
  | Environment Act 1995 | 0.71 GB | 22 s |
  | the next 7 | 0.39–0.69 GB | 5–31 s |

  So 1.8 GB a law stays: it is the worst law's figure, and with 14 GB, a 6 GB reserve and 4 cores the run is 4 wide either way.
- **The slowest law by phase** (`phases-tcpa-1990.txt`, the Town and Country Planning Act 1990 alone, 112 s):
  - inputs 9 s (7 s of it the feed effects);
  - **readers about 62 s**: markup facts 9, feed 12, markup 13, amending law 13, application 10, expiry 5;
  - **merge, evidence and placement about 41 s** (`changes/5` took 103 s in all);
  - write and digest 11 s.

  Under 4 workers it took 198 s, because the four builds share the machine's 6 cores.

## Decision: a third stage? (for Jason)

- **Question:** the profile was to decide whether a third stage (each reader's output stored, so a merge or evidence edit re-merges without re-reading) becomes a follow-up issue.
- **Aim:** rebuild only what an edit changes.
- **Finding:** the readers are about 60% of the slowest build and merge and evidence about 40%. Four of the readers each take 5–13 s on the same body, and they seem to read the XML separately each time.
- **Options:**
  1. raise a third stage as an issue now;
  2. park it: first raise the cheaper fix, reading the body's XML once for every reader, which could save about 30 s of the slowest build;
  3. neither.
- **Decided: 2** (Jason 2026-11-08). A third stage helps only merge and evidence edits, and costs a table, a migration and a version. The rebuild already takes 198 s, inside the 4-minute pass rule.
- **Jason** leaned to 2 and asked for Gemini's view. **Gemini Flash** also recommends 2 (`backend/data/code-reviews/2026-11-08-third-stage-choice-gemini.md`). Triage:

  | # | Finding | Triage |
  |---|---|---|
  | 1 | Sharing one parsed document could change what a reader sees | **Taken.** The fix is proved the same way the split was: all 285 digests byte-equal and golden unchanged. |
  | 2 | The 30 s is an estimate | **Taken.** The fix times the slowest law by phase before and after (`phases.exs`). |
  | 3 | One shared document could raise a worker's peak | **Taken.** Peaks are measured again as in `peaks.log`. Holding one parsed document should be no worse than four parsed one after another, but that has to be shown, not assumed. |
  | 4 | The gain is mostly on the slowest law; readers could run in parallel within a law | **Noted.** The rebuild's wall time is the slowest law, so its gain is the rebuild's gain. Parallel readers are left for the fix's own plan. |


## Parking list

- Store and build: `readers-reparse-body` — four readers of the Town and Country Planning Act 1990 take 5–13 s each on one body, apparently each parsing the XML; parse it once and share it (Decision above)
