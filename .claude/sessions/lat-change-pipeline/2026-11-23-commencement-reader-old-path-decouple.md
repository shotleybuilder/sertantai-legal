---
session: 'Commencement reader: decouple the new path from the old dater'
status: closed
opened: 2026-11-23
closed: 2026-11-23
outcome: success
lane: build

summary: >
  The commencement reader's round-wide modes now pick their amending Acts and cited orders from the
  change register (Commencement.AmendingPicks), never the old label path's register, and no-flag
  --effects reads the store only, with a --preview. The build's stamp no longer holds the old
  collector or dater (Amendment.ProvisionRead; OldPathFenceTest), so an old-path edit stales no build.
  On Jason's (a) the new picks' rules were written (11,404 feed rules, 100 orders), the 1,261 built
  laws rebuilt, and 15 changes in three laws became dated; every check, gate and golden figure holds.

decisions:
  - what: Keep --effects (the feed's commencement rules), approved with the plan
    why: the build's last gap-filler (AmenderStart) dates 12 changes only from them and 50 earlier; the feed yardstick and RULES feed-differences-are-patterns-by-feed-coverage rest on them
    result: kept; no-flag --effects now reads the store only (never fetches) and writes a law at a time through Store.write_changed
  - what: The picks come from the change register (AmendingPicks.acts/0 via HeldAmenders, cited_orders/1 via text-change notes and Pointer.parse)
    why: DATA-ARCHITECTURE borrowing 3; the old register's 288 Acts covered only laws the old collector had seen
    result: 522 Acts with feeds held (265 more not held, listed for Sources); all 149 old (Act, order) pairs before 2002 kept, 242 more
  - what: Collect.read/3 moved to Amendment.ProvisionRead, Collect delegating
    why: naming Collect put Collect.records/7, the old dater (Commencement.Amending) and ChangeCollector.Record in the build's stamp by static reach
    result: none of the six new-path stamps holds the old collector or dater (OldPathFenceTest)
  - what: Write the new picks' rules now (Jason, decision (a); recommendation was (b), leave to each family's step)
    why: Jason chose to write them in the cycle before the rebuild
    result: 211 feed writes (+11,404 rules, −0), 100 orders (1,568 rules); 5 of 1,261 digests changed, all explained; EPA 1990 relabelled with 52 label changes

metrics:
  previews: { effects_acts: 522, effects_writes_changed: 211, effects_writes: 915, effects_rules_added: 11404, effects_rules_dropped: 0, feeds_not_held: 265, orders_read: 100, order_rules: 1568 }
  rebuild: { laws: 1261, seconds: 2497, workers: 4, failed: 0, digests_changed: 5, changes_dated: 15, stage_order_claims: 3 }
  relabel: { laws: 3, label_changes: 52, laws_changed: 1 }
  checks: { round_check: "PASS, identical to the staleness close", switched_checks: "4 PASS", label_gates: "4 PASS", golden: "27/27", golden_extended: "44/50" }
  tests: { targeted: 7304, architecture: 41 }

lessons:
  - title: A digest diff is explained from the restore point's own dump
    detail: pg_restore --data-only -t provision_changes -f - on the NAS dump gives the before-rows without restoring anything into the DB; joining by (law, key, target) explained all 5 changed digests (15 dated changes, 3 reordered stage claims) in minutes.
    tag: tooling
  - title: Re-writing rules unchanged can still move a build when order leaks through
    detail: the orders' re-write (delete and insert) reordered the stored rules, and two same-day stages swapped a field in 3 claims; the build should not depend on the store's row order (raised, stage-order-follows-store-order).
    tag: data
  - title: A round-wide mode no step runs can still drift from the round
    detail: no-flag --effects had fetched and written for the old register's 288 Acts while the families moved to --family and --law; the change register's picks found 211 orders' feeds never read, which dated 15 changes once written.
    tag: tooling

bugs:
  - pattern: "Two stages of one commencement on the same day come out in the stored rules' order, so a re-write of the same rules can swap which stage carries 'in relation to' (Merchant Shipping Act 1995 s.117 and s.311, SI 2004/827; 1883 c.3 s.6(1), SI 1999/2657)"
    category: stage-order-follows-store-order
    module: ChangeVocabulary.Readers.AmendingCommencement (stages/1)
    affected: 3 claims in 2 laws
    fix: "order same-day stages by a stable key (date, then territory, purposes, source ref) before they are claimed"
    step: Commencement reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/amending_picks.ex
  - backend/lib/sertantai_legal/scraper/amendment/provision_read.ex
  - backend/lib/sertantai_legal/scraper/amendment/collect.ex
  - backend/lib/sertantai_legal/scraper/amendment/read_law.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/lib/mix/tasks/lat.commencement.ex
  - backend/lib/mix/tasks/lat.amending.ex
  - backend/test/sertantai_legal/architecture/old_path_fence_test.exs
  - backend/test/sertantai_legal/scraper/commencement/amending_picks_test.exs
  - backend/data/reports/commencement-reader/decouple/
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md

depends_on:
  - 2026-11-23-commencement-reader-staleness

enables:
  - 2026-11-23-commencement-reader-order-split
---

# Session: Commencement reader: decouple the new path from the old dater (CLOSED)

## Problem

The old label path's dater (`Commencement.Amending`, effects first) dates the same amending provision the build dates from the text first. Two of the reader's modes pick their laws from the old register (`lat_change_log`): `--effects` and the no-flag `--read-orders`. `--effects` writes 51,549 of the 72,043 rules, which the build uses only in `AmenderStart`'s last gap. The old dater cannot be deleted until every family has switched (DATA-ARCHITECTURE, "When every family has switched", G1). Retrospective Decision 1 (b).

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`).

- ✅ 1. Measure: the two picks, the build's reach, `AmenderStart`'s use of the feed's rules; decision: keep `--effects`
- ✅ 2. The picks from the change register (`Commencement.AmendingPicks`); no-flag `--effects` reads the store only
- ✅ 3. `--preview` for `--effects`; preview the round-wide `--effects` and `--read-orders` for Jason
- ✅ 4. The old dater fenced out of the build's stamp (`Amendment.ProvisionRead`, `Collect` delegating); architecture test
- ✅ 5. Pre-flight (tests, Credo diff, Dialyzer, fix-reach previews, golden digests, `lat.stale`)
- ✅ 6. The one-time cycle on Jason's go (rebuild the built laws; relabel preview, then relabel the switched laws)
- ✅ 7. Check and close

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
- **Decided (Jason, 2026-11-23): (a), write them now**, in the cycle before the rebuild. The digests will differ where the new rules reach; each difference is explained at the check.
- **Recommendation was:** (b). The pass rule here is "digests unchanged": this session changes where the picks come from, not what is read. A family's step re-reads its own amending laws with the gates around it. The round-wide modes now pick correctly for whenever they are next run.

## The cycle (todo 6, Jason's go; decision (a))

- **Restore points:**
  - `decouple-cycle`: `commencement_rules` and the three build tables;
  - `decouple-relabel`: `lat_change_log`, `lat_label_timeline` and `lat_events`.
- **Writes:**
  - round-wide `--effects`: 522 Acts; 211 writes written, 704 unchanged (stamp only); 265 feeds not held (165 s);
  - round-wide `--read-orders`: 100 orders, 1,568 rules (32 s).
- **Rebuild:** 1,261 laws in 2,497 s with 4 workers, 0 failed.
- **Digests:** 5 of 1,261 laws changed, and every difference is explained. The changes were diffed field by field against the restore point's dump, with the same 21,039 changes before and after:
  - **15 changes became dated, by the newly written rules:**
    - Building Act 1984: 3 (for example s.4(1)(a)(ii), 1999-09-01 by SI 1999/2323);
    - Copyright, Designs and Patents Act 1988: 8, 7 with their order named (for example s.61(2)(a), 1992-07-01 by SI 1992/1286);
    - EPA 1990: 12, 7 with their order named (for example s.98(3)(cc) by the 1992 c.37 Sch.9, 1993-04-01 by SI 1992/817), and 5 by new feed rules through `AmenderStart`.
  - **3 claims in 2 laws** (1883 c.3 s.6(1); Merchant Shipping Act 1995 s.117 and s.311) only swapped which of two same-day stages carries "in relation to". The stages follow the stored rules' order, which the orders' re-write moved. Raised, owned by the Commencement reader: `stage-order-follows-store-order`.
- **`lat.stale` after:** the builds are fresh on the code version. Commencement reader 109 and extent reader 768 are as before. Three switched laws are behind their changes (1883 c.3, EPA 1990, Merchant Shipping Act 1995) and are relabelled.

## Check and close (todo 7)

- **Relabel** of the three switched laws behind their changes:
  - restore point `decouple-relabel`;
  - the preview: 52 label changes, all in EPA 1990 (49 `effective_from` moved, 2 gained, 1 `changed_by`), from its 12 newly dated changes; 0 in the other two laws;
  - then applied, 0 failed. The preview was not stopped for Jason: the changes follow from decision (a), and the gates below hold.
- **Checks:**
  - the commencement checks PASS for the round (Waste, Water and Climate) and the four switched families. The round's report is identical to the staleness close, yardstick included (agree 36,261, differ 1,030, feed error 690, feed only 684, feed partial only 298, own only 61,245, neither 9,497);
  - the label gates PASS for the four switched families (groups not named 0);
  - golden 27/27; extended golden 44/50.
- **Docs changed:** DATA-ARCHITECTURE: borrowing 3 is done, and G1 is noted as fenced. RULES: none written. The rule that the new path picks from its own tables is held in code (`OldPathFenceTest`); a RULES entry is offered to Jason.
- **Bugs:** one raised and parked: `stage-order-follows-store-order` (Commencement reader). The order-split session, which rebuilds anyway, can take it. No parking list.
- **No step close:** this is a follow-on session, not a pipeline step.
