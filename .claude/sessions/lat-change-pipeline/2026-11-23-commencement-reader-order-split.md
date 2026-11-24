---
session: 'Commencement reader: split the order reader'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: split the order reader (ACTIVE)

## Problem

`Commencement.Order` is 2,188 lines, 169 functions and 58 patterns, touched by 51 commits; changes to it are hard to track and review. `LawStart.Provisions` (1,823 lines) and `LawStart.Clause` (1,021) are next. Retrospective Decision 1 (c): split by the family of form each reads, as one or more sessions sized at the plan.

## Todo

Plan approved 2026-11-24 (`~/.claude/plans/gleaming-doodling-matsumoto.md`): `Order` split into 12 modules of one concept each under `commencement/order/`; `LawStart.Provisions` and `Clause` go to a pending session of their own.

- ✅ 1. Measure: the call graph (141 functions, 58 patterns), the cut lines, the stamps the move touches, the tests that hold behaviour
- ✅ 2. Baseline: the orders catalogue (`lat.order_patterns`) and the round preview of the orders' re-read (0 changes)
- ✅ 3. Red: one test file per new module
- ✅ 4. Green, module by module, leaves first; the orders' stamp and the catalogue's version lists updated
- ✅ 5. Pre-flight: tests, Credo diff, Dialyzer; the catalogue identical; the preview 0 changes
- ⬜ 6. The orders' re-read on Jason's go (orders substeps only): 0 written
- ⬜ 7. Check and close (checks, golden, module sizes, the pending clause-reader split session)

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
