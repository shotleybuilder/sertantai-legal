---
session: 'Commencement reader: decouple the new path from the old dater'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: decouple the new path from the old dater (ACTIVE)

## Problem

The old label path's dater (`Commencement.Amending`, effects first) dates the same amending provision the build dates from the text first. Two of the reader's modes pick their laws from the old register (`lat_change_log`): `--effects` and the no-flag `--read-orders`. `--effects` writes 51,549 of the 72,043 rules, which the build uses only in `AmenderStart`'s last gap. The old dater cannot be deleted until every family has switched (DATA-ARCHITECTURE, "When every family has switched", G1). Retrospective Decision 1 (b).

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`).

- ✅ 1. Measure: the two picks, the build's reach, `AmenderStart`'s use of the feed's rules; decision: keep `--effects`
- ✅ 2. The picks from the change register (`Commencement.AmendingPicks`); no-flag `--effects` reads the store only
- ✅ 3. `--preview` for `--effects`; preview the round-wide `--effects` and `--read-orders` for Jason
- ✅ 4. The old dater fenced out of the build's stamp (`Amendment.ProvisionRead`, `Collect` delegating); architecture test
- ✅ 5. Pre-flight (tests, Credo diff, Dialyzer, fix-reach previews, golden digests, `lat.stale`)
- ⬜ 6. The one-time cycle on Jason's go (rebuild the built laws; relabel preview, then relabel the switched laws)
- ⬜ 7. Check and close

## Dependencies

- ✅ Commencement reader: staleness that follows what changed closed (2026-11-23)

## Measures (todo 1)

- **Two picks read the old register** (`lat.commencement.ex`):
  - `amending_acts/0`: 288 Acts from `lat_change_log` (`amending_law`). It feeds no-flag `--effects` (which fetches missing feeds), `--orders` and no-flag `--read-orders`.
  - `cited_orders/0`: joins `lat_change_log` to `amendment_annotations`.
  - No step runs the no-flag modes: `lat.reread` and the step procedures use `--law` and `--family`.
- **New picks from the new tables:**
  - The change register's amenders give 607 Acts. The old 288 hold 222 of them; the other 66 amend only laws not yet built.
  - The notes alone (`Pointer.parse/1`'s `affecting_law`) give all 149 of the old (Act, order) pairs before 2002, and 242 more.
- **The build's stamp holds the old dater** (`commencement/amending.ex`, with `amendment/collect.ex` and `amendment/evaluator.ex`). The build only calls `Collect.read/3`, but naming `Collect` reaches `Collect.records/7`, which is the old collector. The fold, the three read stamps and the extent stamp hold none of these.

## Decision: keep `--effects` (approved with the plan)

- **Question:** drop the feed's commencement rules (`--effects`, 51,549 rules) now that the build reads them only in its last gap-filler?
- **Aim:** `binds-on-date`.
- **Measured:** `AmenderStart` dates 1,477 changes: 12 would lose their date without the feed's rules, 50 would move later, and 1,355 keep the same date. The feed yardstick (the two-way gate) and the pending "feed differences as patterns" session compare against them, and RULES `feed-differences-are-patterns-by-feed-coverage` makes the feed the date where it holds the law.
- **Options:** keep; or drop.
- **Recommendation and decision:** keep.

## The picks and the fence (todos 2–4)

- **`Commencement.AmendingPicks`:**
  - `acts/0`: the built laws' amending Acts (`HeldAmenders`);
  - `cited_orders/1`: the orders cited by the text-change notes (`F:`) on the built laws' rows, through `Pointer.parse/1`;
  - `acts/1` and `cited/2` are pure and tested.
- **`lat.commencement`:**
  - `amending_acts/0` and `cited_orders/0` now come from `AmendingPicks`;
  - no-flag `--effects` reads the store only, a law at a time (`effects_scope([])` = `{:amending_acts, :only, :per_law}`);
  - writes go through `Store.write_changed/3`;
  - the `--compare` input uses `LawStart.Input.of/2` directly.
  - `--compare` still compares against the old register's labels by design (`LabelTimeline`): it is an old-versus-new report, retired with the old path.
- **`--effects --preview`:** compares each write with the stored rules it replaces (`effects_scoped/2`, `RuleDiff`).
- **`Amendment.ProvisionRead`:** `read/3` with its own memo of defined terms. `Collect.read/3` delegates to it, and `Collect.clear/0` clears both. `ReadLaw` and `lat.amending` call it.
- **`ChangeVocabulary.Version`:** excepts `commencement/amending.ex`, `amending_picks.ex`, `amendment/collect.ex` and `amendment/evaluator.ex`, and drops `change_collector/record.ex`.
- **`OldPathFenceTest`** (new):
  - none of the six new-path stamps holds the old collector or dater;
  - no module in `change_vocabulary`, `commencement`, `step_procedures` or `lat.commencement.ex` names `lat_change_log`.
- **`NoteReadTest`'s allow list:** `amending_picks.ex` replaces `lat.commencement.ex` as the pointer reader.
- **Tests:** targeted 7,304 pass; architecture 41/41. The Credo diff adds no issue. Dialyzer passes.

## Previews with the new picks (todo 3)

Reports: `backend/data/reports/commencement-reader/decouple/`.

- **Round-wide `--effects --preview`** (186 s):
  - 522 amending Acts and 912 commencing instruments: 51,173 rules read;
  - 265 feeds are not held (listed for the Sources step);
  - **211 of 915 writes change, +11,404 rules, −0.** For example, SI 2006/2603 on the Companies Act 2006: +94; WSI 2021/231 on the Senedd and Elections (Wales) Act 2020: +103; the 2025 c.18 Act's own feed: +319.
  - No stored rule is dropped. The additions are feed rules for Acts the old pick never read.
- **Round-wide `--read-orders --preview`** (43 s): 100 orders read, 1,568 rules. This mode prints totals only, with no stored-versus-read comparison.

## Pre-flight (todo 5)

- **Code:** commit 420b4b3c (hooks passed). Targeted tests 7,304 pass; architecture 41/41; the Credo diff adds no issue; Dialyzer passes.
- **Golden from inputs:** 27/27 (1,055 s).
- **`lat.stale`:** all 1,261 builds are stale on the code version alone (the build's stamp moved once, as planned). Commencement reader 109 and extent reader 768 were already stale; neither is this session's.
- **Labels:** the switched laws stay fresh (0 of 527). Their labels don't read the old label stamp, which the `collect.ex` edit moved.

## Decision for Jason: write the new picks' rules?

- **Question:** write the 11,404 feed rules (and the 100 orders' 1,568 rules) that the change register's picks find and the old pick never read?
- **Aim:** `binds-on-date`. These are the feed's own dates for the amending Acts of built laws. They feed `AmenderStart`'s last gap and the feed yardstick, so some changes' dates and the yardstick figures would move.
- **Options:**
  - (a) write them now, in the one-time cycle, before the rebuild;
  - (b) leave them for each family's Commencement reader step, which picks a family's amending laws already (`--family`).
- **Recommendation:** (b). The pass rule here is "digests unchanged": this session changes where the picks come from, not what is read. A family's step re-reads its own amending laws with the gates around it. The round-wide modes now pick correctly for whenever they are next run.
