---
session: "Environmental Protection: Store and build"
status: closed
opened: 2026-11-11
closed: 2026-11-11
outcome: success

summary: >
  Step 11 for 💚 ENVIRONMENTAL PROTECTION passed on every rule, with no agent pass. 106 built laws were stale on commencement readings by older reader code. Each was re-read in the mode that wrote it, and --build --stale brought the store and the 266 switched labels up to date. Then all 445 built laws' digests were identical across two builds, with 0 stale. Six gates pass, and the three that fail were parked in Measures (Sources 69, Extent 2, Amending 4). The two parked Store and build bugs are fixed: restore copies go to a restore schema, and --conflicts prints in a fixed order.

decisions:
  - what: "No agent pass: the staleness sample is drawn twice and compared with cmp, and 3 items are checked by SQL as a spot check"
    why: "Jason, after the Label fold's 427,919 tokens; Maritime's hand check of the same sample found 30/30"
    result: "sample byte-identical; 3/3 OK"
  - what: "Decision 1, A: EP's build time accepted (122 laws, about 5½ min with 1 worker while the VM runs)"
    why: "nearly 4 min is two Acts (EPA 1990 189 s, Environment Act 1995 59 s); a fix round rebuilds only its laws with --laws"
    result: "accepted by Jason"
  - what: "Stale reader readings re-read in the mode that wrote them, found from commencement_rules (own clause or order; holding LAT or not)"
    why: "lat.stale names the reason, not the mode; a different mode could write other rules"
    result: "--read 106, --read-amending 241, --read-orders --law 17, then the cited-orders mode for 3 orders the named-law mode does not find; 0 reader-stale"
  - what: "Restore copies: one helper, restore.<tag>__<table>, recorded in restore.points (a plain SQL migration, not an Ash resource)"
    why: "DATA-ARCHITECTURE (f) policy points 1 and 2; the old copies were two thirds of public"
    result: "five tasks moved (live.unapplied_effects added, same class); making.resolve parked with Making laws"

metrics:
  stale_before: { built: 445, stale: 106, reason: commencement_reader, switched_labels_stale: 266 }
  rereads: { read_lat: 106, read_amending: 241, orders_named: 17, rules_written: 948, seconds: 99 }
  build_stale: { laws: 107, seconds: 512.5, refolded: 266, refold_seconds: 223.3, workers: 1 }
  build: { ep_laws: 122, a_seconds: 336.8, b_seconds: 347.6, workers: 1, epa_1990_seconds: 189, env_act_1995_seconds: 59 }
  repeatable: { built_laws: 445, identical: 445 }
  stale_after: { built: 445, stale: 0, switched: 266, switched_stale: 0, strict_switched_exit: 0 }
  gates: { pass: 6, fail_parked: 3, fail_new: 0, sources: 69, extent: 2, amending: 4 }
  label_gate: { laws: 122, rows: 35766, breach_groups: 8, known: 8 }
  hand_check: { seed: 1211, items: 30, byte_identical: true, checked_by_sql: 3, ok: 3, tokens: 0 }
  golden: "27/27 from the store and from inputs (240 s)"
  tests: "mix test 10,696 passed, 2 skipped; architecture 22"

lessons:
  - title: "A reader reason needs the mode found from the readings themselves"
    detail: "lat.stale says commencement_reader and 're-read in the mode that wrote them' but not which mode. Grouping the old-version rules by own clause or order, and by whether the law holds LAT, gave three modes. A fourth showed only after them: 3 orders that only the cited-orders mode finds. Check lat.stale after each round of re-reads rather than trusting the plan's list."
    tag: tooling
  - title: "The VM serialises the build, and the build time with it"
    detail: "With the qemu VM up, LawRunner.Guard runs one worker. EP's 122 laws took about 5½ min, two Acts making up nearly 4 of it. A build time is only comparable to another step's at the same worker count, so record the workers with the time."
    tag: infrastructure

bugs:
  - pattern: "Tasks that snapshot before an apply still create restore tables in public (live.recompute, live.apply_effects, drrp.remap, extent.resolve; and live.unapplied_effects, same class)"
    category: restore-tables-in-public
    module: SertantaiLegal.Restore; those mix tasks
    affected: 5 tasks
    fix: "SertantaiLegal.Restore.copy!/4 writes restore.<tag>__<table> and a restore.points row (migration 20261111150000); the five tasks call it; restore_test plus the two live tests"
    step: Store and build
    status: fixed
  - pattern: "mix lat.vocabulary --conflicts prints its kind groups in an unstable order (map iteration); content stable"
    category: unstable-report-order
    module: mix lat.vocabulary (conflicts)
    affected: 1
    fix: "groups sorted by kind; EPA 1990 printed in the same order on two runs"
    step: Store and build
    status: fixed
  - pattern: "mix making.resolve copies legal_register to making_backfill_snapshot_<YYYYMMDD> in public before an apply (the restore-tables-in-public class)"
    category: restore-tables-in-public
    module: mix making.resolve
    affected: 1 task
    fix: "Call SertantaiLegal.Restore.copy!/4 (as extent.resolve does)"
    step: Making laws
    status: open

artifacts:
  - backend/lib/sertantai_legal/restore.ex
  - backend/priv/repo/migrations/20261111150000_restore_schema.exs
  - backend/test/sertantai_legal/restore_test.exs
  - backend/lib/mix/tasks/live.recompute.ex
  - backend/lib/mix/tasks/live.apply_effects.ex
  - backend/lib/mix/tasks/live.unapplied_effects.ex
  - backend/lib/mix/tasks/drrp.remap.ex
  - backend/lib/mix/tasks/extent.resolve.ex
  - backend/lib/sertantai_legal/scraper/live_status/recompute.ex
  - backend/lib/sertantai_legal/scraper/live_status/effects_backfill.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md
  - .claude/skills/store-build-check/SKILL.md

depends_on:
  - 2026-11-11-environmental-protection-measures.md

enables:
  - "Environmental Protection: Labels side by side"
---

# Session: Environmental Protection: Store and build (CLOSED)

## Problem

Step 11 for "💚 ENVIRONMENTAL PROTECTION": the change register must be repeatable, fast enough for a fix round, and honest about staleness, with every earlier step's gate passing or parked. Today 106 of 445 built laws are stale (all on older commencement readings), and the switched families' labels are behind the fold's version (266). Two parked Store and build bugs are fixed first. No agent pass (Jason). Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session; restore point (provision_changes, provision_change_claims, lat_events, commencement_rules, lat_label_timeline; tag ep-store-build)
- ✅ Parked bug: the `Restore` helper (restore schema, `restore.points`) by TDD; the four tasks moved onto it; `making.resolve` parked with Making laws; original entry marked fixed with `moved_to`
- ✅ Parked bug: `--conflicts` groups sorted by kind (one sort in the task, checked by two runs; no unit test, the task holds no pure function for it); compile with warnings as errors, architecture tests, `lat.stale` (build version moves only if a build file changed)
- ✅ Store up to date: re-read the 106 laws' commencement in their modes, then `--build --stale`
- ✅ Build A with the check and every gate, digest A; build B, digest B, `cmp`; EP build time for Jason; gate failures against what is parked
- ✅ `lat.stale --strict --switched` exits 0; seed 1211 sample twice and `cmp`; 3 items by SQL; golden 27/27; `mix test`
- ✅ Docs and close: skill history, WORKFLOW step 11 note, DATA-ARCHITECTURE (f) points 1–2 done, meta row, commits by path

## Pass rule (fixed)

1. Every built law's digest identical across builds A and B.
2. EP's family build time printed and accepted by Jason.
3. `mix lat.stale --strict --switched` exits 0.
4. Every failing gate already parked with its own step (expected: Sources 69, Extent 2 causes, Amending 4 groups, from Measures).
5. Staleness sample (seed 1211) byte-identical twice; 3 items checked by hand (spot check, not a gate). No agent.
6. Golden 27/27 from inputs; `mix test`; compile with warnings as errors, architecture tests; Credo diff adds nothing.

## Dependencies

- ✅ Environmental Protection: Measures (closed, c82abb3c)

## Parking list

- Making laws: restore-tables-in-public — `mix making.resolve` still copies to `public`; call `Restore.copy!/4`.

## Parked bugs fixed

- **Restore copies.** `SertantaiLegal.Restore` (`backend/lib/sertantai_legal/restore.ex`) names a copy `restore.<tag>__<table>`, refuses a name Postgres would truncate, and records each copy in `restore.points`. The migration is 20261111150000, applied to dev. `live.recompute`, `live.apply_effects`, `live.unapplied_effects`, `drrp.remap` and `extent.resolve` now pass a tag. `live.unapplied_effects` wasn't on the parked list but is the same class. `LatReparse` is already parked with LAT parser, and `making.resolve` is now parked with Making laws. Tests: `restore_test` 4, the live tests 9.
- **The order of `--conflicts`.** Its kind groups are sorted. On EPA 1990, two runs printed the same order.
- The build's version is unchanged (57baac9c87dc), and the architecture tests pass (22).

## Store up to date

- **Restore point** `ep-store-build`, taken before any write. Rows held: `provision_change_claims` 1,218,911; `lat_events` 67,909; `commencement_rules` 61,402; `lat_label_timeline` 679,792; and `provision_changes`.
- **Why the 106 were stale.** Their commencement rules came from older Commencement reader code: versions 29e5d9319bcf (read 2026-11-08) and dc81f09cb61f (2026-11-09). The current version is de2446699978. Each law was re-read in the mode that wrote it, offline, with 0 errors:

  | Mode | Laws | Rules written | Time |
  |---|---|---|---|
  | `--read --law` (own clause, laws holding LAT) | 106 | 295 | 37 s |
  | `--read-amending --law` (own clause, no LAT) | 241 | 653 | 51 s |
  | `--read-orders --law` (a labelled law's orders) | 17 | — | 3 s |
  | `--read-orders` (cited orders) | — | — | 8 s |

  The cited-orders mode was needed for 3 orders: SI 2005/423 and SI 2006/1279 under the Countryside and Rights of Way Act 2000, and SI 2002/2024 under the Transport Act 2000. Afterwards no built law is stale on reader code. 107 are stale on their commencement rules, which the build fixes.
- Rows by older reader code still remain for laws no built law reaches. They are left as they are.
- **`--build --stale`** (12 min 21 s): 107 laws built in 512.5 s with 1 worker (the guard keeps it serial while the qemu VM runs), then 266 switched laws refolded in 223.3 s, 0 failed. Afterwards `lat.stale` shows 0 of 445 built laws stale and 0 of 266 switched laws' labels. The 964 `labels_version` and 901 `parser_version` are old-path labels of families not yet switched, outside `--switched`.

## Builds A and B

- **Build A** (`--check --family`, 21 min 9 s in all): 122 laws built in 336.8 s with 1 worker. Golden from the store 27/27. Every gate:

  | Gate | Result | Owner |
  |---|---|---|
  | Sources | FAIL 69 | parked in Measures |
  | Feed reader | PASS | |
  | Markup reader | PASS | |
  | Commencement reader | PASS | |
  | Extent reader | FAIL 2 | parked in Measures (EPA 1990, UK_ukpga_2018_12) |
  | Amending-law reader | FAIL 4 | parked in Measures (4 groups) |
  | Merge | PASS | |
  | Evidence | PASS | |
  | Label fold | PASS (122 laws, 35,766 rows; 8 breach groups, all 8 known) | |

  All three failures were parked in Measures with the same counts. There is no new failure, and the re-read moved no Commencement gate.
- **Build B** (`--build --family`): 122 laws in 347.6 s. **All 445 built laws' digests are identical** across A and B (`cmp`).
- **Build time** (Decision 1 below), 1 worker because the VM is up: EPA 1990 189 s, the Environment Act 1995 59 s, the Environment Act 2021 19 s, and the other 119 laws about 32 s in all.

## Decision 1: accept EP's build time?

- **The question:** is a family build of about 5½ min fast enough for a fix round?
- **The aim:** the change register is fast enough for a fix round (WORKFLOW step 11).
- **The options:**
  - (A) accept it as measured;
  - (B) re-time with 4 workers once the VM is down before accepting;
  - (C) park EPA 1990's build time with Store and build as its own bug.
- **The recommendation:** A. Nearly 4 of the 5½ min are two Acts. EPA 1990 took 156 s alone on 2026-10-31 and 189 s now, serial, with the store grown since. For a fix round, `--laws` rebuilds only the laws a fix touches.

## Fresh and hand check

- `mix lat.stale --strict --switched` exits 0.
- **The staleness sample**, seed 1211, `--built 20 --unbuilt 10`, was drawn twice and is byte-identical (`cmp`). The 20 built laws are all fresh; the 10 unbuilt are all `no_build`.
- **3 items checked by SQL**, a spot check and not a gate (no agent), all 3 OK:
  - **SSI 2015/383 and SI 1999/931:** stored changes and claims match the event (156/1,225 and 13/187), the code version is current (57baac9c87dc), the event is the latest, no amendment rules then or now, and the law text predates the build. The event's `extents_unread` is a record of what was not read, not an input.
  - **SI 1986/1320:** 172 LAT rows, no changes and no event, so `no_build` is right.

## Decision 1 outcome

Jason chose A: the build time is accepted as measured.

## Verify

- Golden from inputs 27/27 (4 min); `mix test` 10,696 passed, 2 skipped.
