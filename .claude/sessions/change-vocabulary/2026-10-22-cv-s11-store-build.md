---
session: 'CV-S11: Store and Build'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-31'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  The change register passes on the OH&S core family and golden laws: two builds from the same inputs store
  identical changes (168 laws, 70,702 changes), the family builds in 51 s, and mix lat.stale now shows each built
  law's change staleness by reason (0 of 168 after the build; hand check 30/30). The build records content
  fingerprints of what it read (the feed's was always null before), and --check ends with the sources gate.

decisions:
  - what: Scope is the OH&S core family plus the golden laws (168)
    why: Jason 2026-10-31, the same scope as steps 1-10; other families are built when they reach the workflow
    result: 168 laws built twice
  - what: Speed measured first, then accepted with no cache
    why: Jason 2026-10-31 ("Fast enough, drop the cache"); the family build is 51 s, and the golden build's 204 s is EPA 1990 (156 s) and a few other big laws outside OH&S whose amending laws the read pass never read
    result: the speed todo dropped; logged for the retrospective
  - what: Change staleness reported in mix lat.stale, not counted in --strict until CV-06
    why: Jason 2026-10-31 (one command for what is stale); the labels don't read the change register until the switch-over
    result: a change register section (N of M built laws stale, by reason) plus laws holding LAT with no build
  - what: Fingerprint inputs by content (LAT rows, law text, feed) and by each rules store's latest read_at; record the affecting and commencing laws
    why: a refetch with identical content shouldn't stale a build; recording the lists lets lat.stale fingerprint the rules again without a build (about 2 s for 168 laws)
    result: Store.Inputs shared by the build and lat.stale
  - what: An input the build didn't record counts as moved
    why: nothing says an older build is current on that input
    result: all 168 earlier builds showed stale before the rebuild
  - what: Hand check pass rule is none wrong, not the 2% bound
    why: as CV-S10's hand check; the agent judges verdicts, a small sample
    result: 30/30; the moved-input case covered by store_inputs_db_test

metrics:
  build_repeatable: { laws: 168, changes: 70702, digests_differing: 0 }
  build_time_s: { family_149: 51.4, family_and_golden_168_a: 204.6, family_and_golden_168_b: 201.1, epa_1990: 156, golden_from_inputs: 164, workers: 4 }
  changes_stale: { before: 168, after: 0, built: 168, lat_laws_no_build: 898 }
  amending_law_indexes: { fresh: 692, never_read: 1074, stale: 0, read_from_text_per_build: 139 }
  hand_check: { seed: 1101, items: 30, wrong: 0, doubtful: 0 }
  sources_gate_168: { failures: 565, register_differences: 11, pass: false }
  golden: { from_store: "27/27", from_inputs: "27/27" }

lessons:
  - title: A fingerprint nothing compares is never tested
    detail: Every build since CV-04 recorded feed_fetched as null, because it looked for the feed's metadata beside the law text. Nothing read the fingerprints, so nobody saw it. Writing the reader (lat.stale) found it on the first look at an event.
    tag: tooling
  - title: A misleading message steers the diagnosis
    detail: The build called 1,074 never-read amending laws "stored rules stale", which sent the speed diagnosis toward reader versions. Classifying the indexes showed 0 stale; the time was golden laws outside the family. Name each cause apart in progress messages.
    tag: tooling
  - title: Compare a timing with the run it came from
    detail: CV-S10's 52 s was the family build; the 168-law build is 204 s. The difference was scope (19 golden laws outside the family, EPA 1990 alone 156 s), not a regression.
    tag: tooling
  - title: A fresh-after-build hand check doesn't exercise the stale reasons
    detail: The agent rightly noted every built law in the sample had just been built, so only no_build was exercised. A DB test that writes a build through Store.write and then moves an input covers the detection path end to end.
    tag: tooling

bugs:
  - pattern: "Every build records feed_fetched: null: the build's inputs look for the feed's metadata beside the law text (clml/{type}/{year}/{num}/body), but feeds are stored under clml/changes/affected/…; a refetched feed never marks a law's changes stale"
    category: staleness
    module: mix lat.vocabulary (inputs/3)
    affected: 164
    fix: "fingerprint the feed from ClmlStore.feed_files/3 (content), in a Store.Inputs module the build and lat.stale share"
    status: fixed
  - pattern: "The build's message called every amending law without a fresh index 'stored rules stale', but 1,074 of 1,766 had never been read by the read pass (692 fresh, 0 stale); it sent the speed diagnosis the wrong way"
    category: tooling
    module: mix lat.vocabulary (fresh_rules)
    affected: 1074
    fix: "name never-read laws apart from stale ones (03dfb50c)"
    status: fixed
  - pattern: "mix lat.vocabulary is 705 lines (debug view, build, check, conflicts, golden in one task)"
    category: module size
    module: mix lat.vocabulary
    affected: 1
    fix: "split the build, check and golden into modules (CV-S12 retrospective, improve)"
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_staleness.ex
  - backend/lib/sertantai_legal/scraper/change_digest.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store/inputs.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/lib/mix/tasks/lat.changes_digest.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/test/sertantai_legal/scraper/change_staleness_test.exs
  - backend/test/sertantai_legal/scraper/change_digest_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/store_inputs_db_test.exs
  - .claude/skills/store-build-check/SKILL.md
  - backend/data/reports/change-vocabulary/verdicts/s11/ohs/round-1-staleness-seed-1101.json

depends_on:
  - change-vocabulary/2026-10-22-cv-s10-measures

enables:
  - CV-05 consumers (step 12a)
  - CV-S12 Retrospective (last)
---

# Session: CV-S11: Store and Build (CLOSED)

## Problem

Step 11 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Repeatable, fast enough, and it shows what is stale.

Renumbered from CV-S11 to CV-S12 on 2026-10-30, and back to CV-S11 on 2026-10-31 (Jason: "Switch the retrospective session to be the last session in the meta plan. Build session next"). It follows CV-S10.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test (Jason's three decisions, 2026-10-31)
- ✅ Build the acceptance check (`ChangeStaleness`, `ChangeDigest`, `Store.Inputs`, `Store.builds/0`, `mix lat.changes_digest`, staleness in `mix lat.stale`, build time and the sources gate in `--check`); run it (Jason's go 2026-10-31)
- ✅ Same input gives the same output (rebuild twice, diff): 168 laws' digests identical (2026-10-31)
- ❌ Speed: cache each law's parsed markup facts and feed effects, keyed by the stored document's version (CV-07) (dropped, Jason 2026-10-31: the family build is 51 s; the golden laws' time is a few big laws outside OH&S)
- ✅ `mix lat.vocabulary --check` / `--family` (CV-07 `83e15ae7`, fixed `41f9afe0`) proven: build, conflicts, golden from the store and the sources gate in one run, exit 0
- ✅ Staleness: `changes_built` events and code versions shown per law, in `mix lat.stale` (LabelStaleness learns :changes_version at the switch-over, CV-06)
- ✅ The sources check (`mix lat.sources`) reads its gaps from the stored changes: re-run after each rebuild, automatically (from CV-S01): `mix lat.vocabulary --check` ends with it
- ✅ Fix until the check passes reliably; record the result (PASS 2026-10-31)

## Dependencies

- ✅ The steps before it passed (CV-S01–S10 closed PASS; S01's gate failure deferred to the next pass, CV-S10)

## The store today (2026-10-31)

- `provision_changes` holds 164 laws (70,702 changes): the OH&S core family's 145, built 2026-10-30 by code `d364d7f8793d`, and 19 golden laws built 2026-10-22 by `41e9b4034057`. Of 1,066 laws holding LAT, the other ~900 have no build.
- Code version: CV-S10's edits moved `ChangeVocabulary.Version`, so all 164 now show as built by older code (CV-S10).
- Each build writes a `changes_built` lat_event: code version, and its inputs' fingerprints (the stored law's `dct_valid`, the feed's `fetched_at`, the latest `read_at` of the amendment, commencement and extent rules it read, the extents unread). Nothing reads them yet: `mix lat.stale` (`LabelStaleness`) covers the parse and the labels, not the changes.
- Store round trip is tested (`store_db_test`). The OH&S family build takes about 52 s (CV-S10).

## Decisions (Jason 2026-10-31)

- **Scope:** the OH&S core family and the golden laws (164 today), as steps 1–10. Other families are built when they reach the workflow.
- **Speed:** measure the family and golden builds first; the per-law cache stays only if the times are a nuisance in a fix round.
- **Staleness:** reported in `mix lat.stale`, beside the parse and label reasons.

## What good looks like

The aim: the change register is repeatable, fast enough, and shows what is stale.

1. **Repeatable** (`build_repeatable`): two builds from the same inputs store the same content. Measure: per law, a digest of its stored changes and claims (without ids and build times), compared across two builds; pass with 0 laws differing.
2. **Fast enough** (`build_time`): the wall time of a family build and of the golden build, printed by the task. Pass: under a target Jason sets.
3. **Shows what is stale** (`changes_stale`): per law, the reasons its changes are stale, in pure code tested on hand-built facts (as `LabelStaleness`):
   - no build;
   - code version (`ChangeVocabulary.Version`) differs;
   - an input moved since the build: the law text refetched, the feed refetched, rules it read re-read.
   Printed by a task. Hand check: a seeded sample of laws, each reason judged against the events and the stores; pass with none wrong.
4. **Sources gate re-run** (from CV-S01, found failing in CV-S10): a build ends with the sources check for the laws built, and prints its failures.
5. The golden from inputs (`mix lat.vocabulary --golden`) stays at 27/27.

## The acceptance check built (2026-10-31)

- **`ChangeStaleness`** (pure, `change_staleness_test`): a law's reasons from its latest build: `no_build`, `code_version`, or an input moved (`lat_rows`, `law_text`, `feed`, `amendment_rules`, `commencement_rules`, `extent_rules`). An input the build didn't record counts as moved.
- **`Store.Inputs`** (DB and files): the fingerprint, recorded by the build and taken again by `lat.stale`. Content digests for the LAT rows, the law text and the feed (the feed's was always null before: the bug above); the latest `read_at` for each rules store; the affecting and commencing laws recorded so the rules can be fingerprinted again without a build.
- **`mix lat.stale`** reports the change register after the parse and labels: built laws stale by reason, and laws holding LAT with no build. About 2 s for 168 laws. Not counted in `--strict` until the labels read the change register (CV-06).
- **`ChangeDigest`** (pure, `change_digest_test`) and **`mix lat.changes_digest`**: one line per law (digest, changes), for `cmp` across two builds. About 6 s.
- **`mix lat.vocabulary --build`** prints the whole build's wall time (`build_time`); **`--check`** ends with `lat.sources` on the laws built.
- Before the builds, every one of the 168 builds showed as stale: built by older code (CV-S10's edits), and built before the new fingerprints were recorded.
- Restore point `cv-s11-before-builds` (provision_changes, provision_change_claims, lat_events).

## The acceptance chain (2026-10-31, code `03dfb50c`, `ChangeVocabulary.Version` 135c6be74d0f)

The 168 laws (the OH&S core family and the golden laws), after the restore point:

| Measure | Result |
|---|---|
| `build_repeatable` | build A (`--check`) and build B: `lat.changes_digest` files identical (`cmp`), 168 laws, 70,702 changes |
| `build_time` | 168 laws 204.6 s and 201.1 s (4 workers); the family alone (149 laws, `--family`) 51.4 s, as CV-S10's 52 s |
| `changes_stale` | before: 168 of 168 stale (code version; inputs not recorded). After: 0 of 168; 898 laws holding LAT with no build |
| golden | 27/27 from the store (`--check`) and from inputs (`--golden`, 164 s) |
| sources gate | runs at the end of `--check`: FAIL, 565 failures over the 168 laws (not fetched: territory 196, introduction 227, backlog 99, dates 42, enabling parent 1); 11 feeds differ from the register's statistics. The S01 gate failure CV-S10 deferred to the next pass |

**Where the build's time goes.** Summed law time: the family 127 s, the 19 golden laws outside it 471 s. EPA 1990 (`UK_ukpga_1990_8`, 14,545 changes, 123,942 claims) takes 156 s on its own, so it sets the wall time. The build reads from their text every amending law whose read-pass index isn't fresh. Of the 1,766 amending laws behind the 168 builds, 692 have a fresh index; 1,074 were never read by the read pass (they are outside the family's read pass), and none is stale. Build B read 139 from their text.

## Hand check (2026-10-31, seed {1101, 11, 11})

- 30 laws drawn by `Measures.Draw.shuffled`: 20 built, 10 holding LAT with no build. An agent checked each verdict against its own SQL and file mtimes: event latest and matching the stored rows (changes, claims, code version, build time), code version current, no text or feed file newer than the build, each rules store's latest `read_at` equal to the recorded one, and the unbuilt laws with no rows and no event.
- **30 of 30 right**, 0 doubtful. Verdict file: `backend/data/reports/change-vocabulary/verdicts/s11/ohs/round-1-staleness-seed-1101.json`; `mix lat.verdicts` 0/30 (the pass rule here is none wrong, not the 2% bound).
- The agent noted the sample had no input that moved after a build, so only `no_build` was exercised among the stale reasons. Two things cover the rest: before the builds, the same report found all 168 laws stale on real data (code version, and inputs not yet recorded); and `store_inputs_db_test` (`b79a7a68`) writes a build through `Store.write/3`, then moves an input (an amendment rule read after it) and gets `[:amendment_rules]`.
