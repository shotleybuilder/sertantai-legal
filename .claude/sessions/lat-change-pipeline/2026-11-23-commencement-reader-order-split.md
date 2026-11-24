---
session: 'Commencement reader: split the order reader'
status: closed
opened: 2026-11-23
closed: 2026-11-24
outcome: success
lane: build

summary: >
  Commencement.Order (2,173 lines) was split into 12 one-concept modules under commencement/order/, with Territory and OtherLaw grown; Order (181 lines) keeps rules/2 and its delegates, and the 4 Credo nesting issues are fixed. Reading is unchanged: the orders catalogue and the orders' re-read preview are identical before and after, and the 22 order test files pass unchanged. A stamp fault found on the way (a read stamp's file list fed the build's and fold's versions) was fixed TDD, followed by one rebuild (6 digests explained) and a relabel with 0 label changes.

decisions:
  - what: "Pre-flight test is the preview identical to the baseline, not 0 changes"
    why: "the baseline preview, on today's code before any edit, already read 20 orders differently from the store"
    result: "the 20 differences identical before and after the split"
  - what: "Fix the stamps (b), then rebuild and relabel once (Jason 2026-11-24)"
    why: "ChangeVocabulary.Version and FoldVersion globbed commencement/read_version/*.ex, so adding files to ReadVersion.Orders staled all 1,261 builds and 527 switched labels with nothing computed changed; the clause split would pay it again"
    result: "b6d7e37d: another stamp's list feeds neither stage's version (StageSplitTest); one rebuild, 6 digests explained; relabel 0 label changes"
  - what: "Re-read all orders before the one rebuild (the 20 changed orders written)"
    why: "the rebuild was needed anyway; the orders' changes reach it once, reviewed as the only expected digest change"
    result: "2 changes newly dated (SI 1998/2212), 3 commencement claims gained, 3 same-day stage swaps (the parked stage-order bug)"

metrics:
  split: { order_lines_before: 2173, order_lines_after: 181, new_modules: 12, largest: "Items 503", nesting_fixed: 4, credo_added: 0 }
  tests: { new: 26, targeted_pass: 6702, order_test_files_unchanged: 22 }
  catalogue: { orders: 1181, identical: true }
  reread_preview: { acts: 214, orders: 1133, rules: 11617, stored: 11441, differing_orders: 20, identical_before_after: true }
  rebuild: { laws: 1261, seconds: 6012, workers: 1, failed: 0, digests_changed: 6 }
  relabel: { laws: 527, label_changes: 0, failed: 0, seconds: 1131 }
  checks: { commencement_pass: 5, label_gates_pass: 4, golden: "27/27", extended: "44/50" }

lessons:
  - title: A stamp that holds another stamp's file list stales its stage on every reader edit
    detail: The build and fold reach the ReadVersion modules only to compare stamps, but their versions globbed read_version/*.ex, so listing the split's new files in ReadVersion.Orders staled all 1,261 builds and 527 labels. The plan's check (no order file in those stamps) missed it; lat.stale straight after the first stamp edit showed it. Reach tests now stop at every other stamp, as at SourceVersion itself.
    tag: tooling
  - title: A behaviour-preserving split's yardstick is the preview identical to its baseline, not zero
    detail: The baseline preview on untouched code already differed from the store in 20 orders (code fixes since they were last written). Comparing before and after the split, not against the store, kept the pass rule honest.
    tag: data
  - title: Scripted moves keep bodies unchanged; check the script's own edges
    detail: Cutting order.ex by a Python splitter moved 141 functions without retyping, but its first passes got delegate heads, attribute self-uses, captures and multi-line @doc placement wrong; each showed as a compile error. Adding @spec after pruning aliases left four specs naming unaliased modules (the compiler does not check remote types; Dialyzer caught a wrong spec).
    tag: tooling
  - title: Commit by path needs the modified files named, not only the staged new ones
    detail: Passing git diff --cached names to git commit -- left the four modified files out of 206e1bf4; a second commit (37e19742) completed it. List every path, modified and new.
    tag: tooling

bugs:
  - pattern: "A read stamp's file list (commencement/read_version/*.ex, Extent.ReadVersion, Amendment.ReaderVersion) fed ChangeVocabulary.Version and FoldVersion, so any reader's file-list edit staled every build and switched label (the order split: 1,261 builds, 527 labels)"
    category: stamp-holds-stamp
    module: change_vocabulary/version.ex, change_vocabulary/fold_version.ex
    affected: "1261 builds, 527 labels"
    fix: "leave other stamps out of both stages' versions; StageSplitTest holds it (b6d7e37d)"
    step: Store and build
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/lib/sertantai_legal/scraper/commencement/order/ (12 new modules; territory.ex, other_law.ex)
  - backend/lib/sertantai_legal/scraper/commencement/read_version/orders.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/fold_version.ex
  - backend/test/sertantai_legal/scraper/commencement/order/ (13 new test files)
  - backend/test/sertantai_legal/architecture/stage_split_test.exs
  - backend/test/sertantai_legal/architecture/version_coverage_test.exs
  - backend/data/reports/commencement-reader/order-split/
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md

depends_on:
  - 2026-11-23-commencement-reader-old-path-decouple.md

enables:
  - "Commencement reader: split the clause reader (2026-11-24-commencement-reader-clause-split.md, pending)"
  - Commencement reader feed differences as patterns
---

# Session: Commencement reader: split the order reader (CLOSED)

## Problem

`Commencement.Order` is 2,188 lines, 169 functions and 58 patterns, touched by 51 commits; changes to it are hard to track and review. `LawStart.Provisions` (1,823 lines) and `LawStart.Clause` (1,021) are next. Retrospective Decision 1 (c): split by the family of form each reads, as one or more sessions sized at the plan.

## Todo

Plan approved 2026-11-24 (`~/.claude/plans/gleaming-doodling-matsumoto.md`): `Order` split into 12 modules of one concept each under `commencement/order/`; `LawStart.Provisions` and `Clause` go to a pending session of their own.

- ✅ 1. Measure: the call graph (141 functions, 58 patterns), the cut lines, the stamps the move touches, the tests that hold behaviour
- ✅ 2. Baseline: the orders catalogue (`lat.order_patterns`) and the round preview of the orders' re-read (0 changes)
- ✅ 3. Red: one test file per new module
- ✅ 4. Green, module by module, leaves first; the orders' stamp and the catalogue's version lists updated
- ✅ 5. Pre-flight: tests, Credo diff, Dialyzer; the catalogue identical; the preview 0 changes
- ✅ 6. The orders' re-read on Jason's go: it wrote the 20 changed orders, then the stamp fix (decision (b)), one rebuild and the relabel preview
- ✅ 7. Check and close (checks, golden, module sizes, the pending clause-reader split session)

## Dependencies

- ✅ Commencement reader: decouple the new path from the old dater closed (2026-11-23)

## Baseline (todo 2)

Reports: `backend/data/reports/commencement-reader/order-split/before/`.

- **The orders catalogue** (`lat.order_patterns`, dry run, cold): 1,181 orders read in 37 s. Its generated files are copied to `before/order_patterns/`.
- **The orders' re-read preview** (`--read-orders --law <the 214 Acts that stored order rules commence> --held --preview`, 107 s): 1,133 orders read, giving 11,617 rules against 11,441 stored.
  - **It is not 0 before any edit:** 20 orders read rules that are not stored (`preview-differences.txt`). For example, SI 1994/571 stores 47 and reads 48; SI 1998/2886 stores 0 and reads 3.
  - This is today's code, so it predates the split. The split's test is therefore **the preview identical to this baseline**, not 0.
  - The re-read in todo 6 would write these 20 orders. That needs Jason's go, with its reach shown first.

## Red (todo 3)

13 test files in `test/sertantai_legal/scraper/commencement/order/`, one per new module (`Words`, `Dates`, `Purposes`, `Brackets`, `OtherLaw`, `Territory.head_territory`, `Items`, `ScheduleTables`, `ScheduleDate`, `Statements`, `WholeAct`, `AppointedFor`, `Identity`): 26 tests, all failing because the modules don't exist yet.

## Green (todo 4)

`order.ex` was cut by function into the planned modules. The moves were scripted, so no function body was retyped.
- **Shared patterns:** the 7 used by several modules (`cif`, `appointed`, `appointed_is`, `full`, `partial`, `entries_head`, `schedule_entries`) are held in `Words` and exposed by functions.
- **Public API:** every function called across modules is public, with `@doc` and `@spec`. `Order` keeps its public API and its delegates.
- **Nesting:** the 4 issues are fixed by named helpers (`Brackets.related/2`, `Purposes.subsection_refs/2`, `ScheduleTables.row_schedule/2`). Bracket and bare items shared one rule, from qualifier to purposes, which is now `Purposes.of_qualifier/1`.
- **Credo diff:** adds no issues.
- **Tests:** the 22 order test files are unchanged and pass. The 26 new tests pass. The targeted suites pass: 6,702 tests (commencement, architecture, change vocabulary, step procedures, order catalogue, mix tasks).
- **Stamps:** `ReadVersion.Orders` gains the 12 new files. The order catalogue's version globs `order/*.ex`, so it already held them.

| Module | Lines | Functions |
|---|---|---|
| `Order` | 181 | 11 |
| `Identity` | 98 | 6 |
| `Words` | 98 | 12 |
| `Dates` | 205 | 12 |
| `Statements` | 274 | 17 |
| `WholeAct` | 163 | 8 |
| `AppointedFor` | 71 | 2 |
| `Items` | 503 | 39 |
| `Brackets` | 124 | 8 |
| `Purposes` | 79 | 8 |
| `Territory` | 160 (was 145) | 13 |
| `OtherLaw` | 194 (was 58) | 10 |
| `ScheduleTables` | 388 | 30 |
| `ScheduleLists` | 105 | 7 |
| `ScheduleDate` | 127 | 11 |

`Items` (503 lines) is the largest. It holds one concept, a statement's items as refs, so it stays whole (the module-size rule).

## Pre-flight (todo 5)

Reports: `backend/data/reports/commencement-reader/order-split/after/`.

- **The orders catalogue** (cold, 35 s): its 4 generated files (`patterns`, `examples`, `leftover_groups`, `misread_groups`) are **identical** to the baseline.
- **The orders' re-read preview** (101 s): 1,133 orders, 11,617 rules. Its 20 differences are **identical** to the baseline's.
- **Dialyzer:** clean. My first spec for `WholeAct.apart/1` was wrong and is fixed.
- **Credo diff:** adds no issues.
- **Commits:** 206e1bf4 holds the new modules and tests. 37e19742 holds `order.ex`, `Territory`, `OtherLaw` and `ReadVersion.Orders`; I left them out of the first commit by mistake.

## Decision for Jason: the build's and the fold's stamps moved

**What happened.** `lat.stale` after the split shows:
- all 1,261 built laws stale by `code_version`;
- all 527 switched laws' labels stale by `fold_version`;
- `commencement_reader` stale at 284 laws, up from 109. That rise is expected: it is the orders' stamp.

The cause is that the build's stamp (`ChangeVocabulary.Version`) and the fold's (`FoldVersion`) both glob `commencement/read_version/*.ex`. Their code reaches those modules only to compare stamps (`Store.Inputs`, `OwnRead`, `AmendingRead`), never to read a law. So adding the new files to `ReadVersion.Orders`' list moved both stamps, though nothing the build or fold computes changed. The plan's "no rebuild, no relabel" was wrong on this point. Its check (that no order file enters those stamps) missed that the read stamps' own lists sit inside them.

**The aim it bears on:** a reader fix costs only its own re-read (the staleness session's aim). This fault makes every read path's file-list edit cost a full rebuild and relabel. The next session, the clause split, edits `ReadVersion.Clause` and would pay it again.

**Options:**
- **(a) Rebuild and relabel now, as things stand.** The build is about 42 min (1,261 laws), then the 527 switched laws are relabelled, with digests and labels expected identical. The fault stays.
- **(b) Fix the stamps first, then rebuild and relabel once.**
  - The fix takes `read_version/*.ex` out of both stamps (`except`).
  - An architecture test holds that a read stamp's file list never feeds the build's or fold's version.
  - The stamps move once more, so one rebuild and relabel are still needed (same cost as (a)), but no later reader split pays it.
  - This is the Commencement reader's own code (`commencement/read_version/`), small and TDD. It widens this session's scope, so it needs your go.
- **(c) Leave the builds and labels stale** until the next family build. This is cheap now, but it hides real staleness behind 1,261 false stale laws.

**Recommendation: (b).**

**With it, the orders' re-read (todo 6).** The re-read refreshes the orders' stamp and also writes the 20 orders whose rules today's code reads differently (+rules, for example SI 1994/571, 47 → 48). This was true before the split. Done before the one rebuild, those rules reach the build, and their digests are reviewed as the only expected change. Done without them, the 20 orders stay stale.

**Recommendation:** re-read all orders, then one rebuild. Explain each changed digest by the 20 orders, and relabel only after you have seen the label preview.

**Decided (Jason, 2026-11-24): (b).**

## The stamp fix (decision (b))

Commit b6d7e37d, done TDD:
- **Red:** a new test in `StageSplitTest`, "another stamp's file list feeds neither stage's version". It found 5 stamp files in the build's version (`ReadVersion.Clause`, `Orders` and `Effects`, `Extent.ReadVersion` and `Amendment.ReaderVersion`) and 3 in the fold's (the three `ReadVersion`s).
- **Green:**
  - `ChangeVocabulary.Version` drops its `read_version/*.ex` glob, and its `except` list gains the two other stamps;
  - `FoldVersion` drops its `read_version/*.ex` line;
  - the reach tests (`StageSplitTest`, `VersionCoverageTest`) stop at every other stamp, as they already did at `SourceVersion` itself.
- **Tests:** the targeted suites pass (6,686).

## The cycle (todo 6, Jason's go)

The script is `cycle.sh`. Its reports go to `backend/data/reports/commencement-reader/order-split/cycle/`. The steps:
1. the restore point `order-split-cycle` (`commencement_rules`, `provision_changes`, `provision_change_claims`, `lat_events`);
2. the digests before;
3. the orders' re-read over the 214 Acts (`--held`);
4. one rebuild of the 1,261 built laws;
5. the digests after, diffed;
6. `lat.stale`;
7. the relabel preview for all switched laws (`lat.wave_preview --all --relabel`).

The relabel itself waits for Jason to see the preview.

### Cycle results

- **Restore point:** `2026-11-24-order-split-cycle`, written in 20 s.
- **The orders' re-read:** 214 Acts, 1,133 orders, 11,617 rules, in 118 s. It wrote the 20 orders whose reading differs.
- **Rebuild:** 1,261 laws, 0 failed, in 6,012 s. The guard allowed only 1 worker this time, not 4.
- **Digests:** 6 of 1,261 changed. Each was diffed against the restore point's dump (`cycle/digest-explained.txt`): the same 18,907 changes before and after, and claims 112,499 → 112,502.
  - **2 changes newly dated by a re-read order:** the 1920 c.65 s.1(2) and the 1995 c.21 s.55(1), each dated 1998-10-01 by SI 1998/2212. That order went from 0 to 140 rules.
  - **3 commencement claims gained:** the 1984 c.55 s.4(1)(a)(ii)–(iv), with stages from SI 1998/2212 and SI 1999/120. The chosen date is unchanged (1999-09-01, from the feed).
  - **3 claims with same-day stages swapped:** the 1883 c.3 s.6(1), the 1988 c.52 s.192(1) and the 2004 c.21 s.62(1A). This is the parked "stage order follows store order", again set off by the re-write.
- **`lat.stale` after:**
  - the builds are fresh on the code version;
  - Commencement reader staleness is 109 and Extent reader staleness 768, as before (neither is this session's);
  - all 527 switched laws are stale on the fold version, as expected; 4 of them are also behind their changes.
- **Relabel preview** (`lat.wave_preview --all --relabel`):
  - it covered all 1,644 stale laws;
  - cut to the 527 switched laws (`cycle/relabel-preview-switched.diff.csv`), it shows **0 label changes**, 0 errors and 0 rows added or removed;
  - the relabel would only refresh the fold's stamp.
  - The other 1,117 laws (old-path `labels_version`, and parser staleness) were stale before this session and are not its own.

## Check and close (todo 7)

Reports: `backend/data/reports/commencement-reader/order-split/close/`.

- **Relabel:** the restore point `order-split-relabel`, then the 527 switched laws relabelled in 1,131 s, 0 failed. The preview had shown 0 label changes.
- **`lat.stale`:** switched families 0 of 527 stale. Commencement reader staleness is 109 and Extent reader staleness 768, both as before and neither this session's. The old path's `labels_version` (1,117) and parser staleness (552) also stand as before.
- **Commencement checks:** PASS for the round (Waste, Water and Climate) and for the four switched families. The round's report is identical to the decouple close apart from the date in a report path.
- **Label gates:** PASS on the four switched families.
- **Golden:** 27/27; extended 44/50, as before.
- **Module sizes:** in Green (todo 4). No function is over Credo's limits.
- **Pending session written:** `2026-11-24-commencement-reader-clause-split.md`.
- **Docs:** `DATA-ARCHITECTURE.md` gains the stamp rule (no stage's version holds another stamp). `RULES.md` is unchanged, since no reading rule was decided.
- **Parked bug seen again:** `stage-order-follows-store-order` (3 claims, from the orders' re-write). It is already open with the Commencement reader, so no new entry.
