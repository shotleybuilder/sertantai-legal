---
session: 'Commencement reader: staleness that follows what changed'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: staleness that follows what changed (ACTIVE)

## Problem

One version stamp (`Commencement.ReadVersion`, 63 files) covers the whole reader, so any fix stales all 72,043 stored rules, and usually every build (`ChangeVocabulary.Version`, 54 files shared) and every extent reading (`Extent.ReadVersion`) too. `Store.write` deletes and re-inserts, so even an identical re-read moves `read_at` and stales every build that reads those rules, in any family. In Waste, Water and Climate two late fixes cost a round re-read and rebuild of about an hour (1,088 laws). Retrospective Decision 1 (a). Spec: `docs/lat-change-pipeline/COMMENCEMENT-READER.md` §5.

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Pass rule: a re-read with unchanged code writes no rule and stales no build (after the cycle: a second re-read writes 0, commencement reasons 0); three read stamps (clause, orders, effects) test-held to exactly their paths' reach; `order.ex` and `order/*` outside the build's and the extent reader's stamps; round checks, yardstick, switched families and golden as at the close; suite and Dialyzer green, no new Credo issue; feed owners written only on Jason's go.

- ✅ 1. Write only what changed: `Store.write/3` compares rows; identical → stamp only, `read_at` kept
- ✅ 2. Three read stamps (clause, orders, effects), explicit lists, each = its path's reach (architecture test); per-group staleness
- ✅ 3. Build and extent stamps drop the order reader: `ClmlRef.ref`, `RefContext`, `LawStart.Sentences`; `Extent.ReadVersion` explicit
- ✅ 4. Feed-difference owners: `{"status","owner"}` entries, `FeedDifferences.owner/3`, yardstick by owner; owners dry-run for Jason
- ✅ 5. Pre-flight: targeted tests, Credo, Dialyzer; round `--preview` 0 changes; `lat.reread` dry runs for the cost
- ✅ 6. The one-time cycle on Jason's go: restore point; store-wide re-read; rebuild of every built law
- ✅ 7. Check: second re-read writes 0; stale reasons 0; round checks, yardstick, switched, golden as at close; suite
- ⬜ 8. Close: DATA-ARCHITECTURE row; RULES rule; session close; commits by path

## Dependencies

- ✅ Commencement reader: step procedures, feed figures and workflow rules closed

## 1. Write only what changed

`Commencement.Store.write_changed/3` compares the stored rules in the write's scope (source, treatments, law commenced) with the new ones, as multisets. If they are the same, it moves only the reader stamp and `read_at` stays, so no build goes stale. `write/3` keeps its `{:ok, n}` and goes through it. The read summary counts laws written, unchanged (stamp only) and with no reading. Three new store tests.

## 2. Three read stamps

`Commencement.ReadVersion` is now a router. `group/1` maps a treatment to a read path (`order_date`/`order_schedule` → orders, `feed_commencement` → effects, every other treatment → clause), and `current/1` returns that path's version. The three stamps each list their files by name:

| stamp | files | entry |
|---|---:|---|
| `ReadVersion.Clause` | 45 | `own_read.ex`, `amending_read.ex` |
| `ReadVersion.Orders` | 33 | `order_read.ex` |
| `ReadVersion.Effects` | 4 | `effects.ex` |

The old single stamp held 63 files by folder.

- The store stamps each row by its treatment. `Store.stale_condition/1`, the one SQL condition, is shared by `Store.Inputs.readers/3` and `RereadStale.for_laws/1`.
- The own and amending read caches key on the clause stamp.
- `CommencementReadStampsTest` holds each stamp to exactly its entry's reach, stopping at the store and the stamps (`ReadVersion.boundaries/0`).

## 3. The build's and the extent reader's stamps drop the order reader

- `Order.ref` → `ClmlRef.ref` (44 sites).
- `Order.context` → `RefContext.context` (8 sites).
- `LawStart.Clause.sentences/commences?/mention?` → `LawStart.Sentences`; the extent code calls it directly.
- `Order.Asides`, `ScheduleParts` and `Sibling` are text helpers that every reader shares. They moved to `Commencement.Text.*` (by `git mv`).
- Delegates stay on `Order` and `Clause`.

Results:

- `order.ex` and `order/*` are out of the build's version (194 files), the fold's version and `Extent.ReadVersion`. `Extent.ReadVersion` is now its own folder plus 10 named files (52 in all), test-held to exactly its reach.
- The catalogue versions follow the moved files.
- 34 of 34 architecture tests pass.

## 4. Feed-difference owners — decision for Jason

**Question:** which step owns each of the 28 statuses in `feed_differences.json`? The code reads `{"status", "owner"}` entries (a plain string is a status with no owner), and the feed yardstick in `mix lat.measures` now adds a "by owning step" line.

**Aim:** `binds-on-date`. Each difference the feed shows is routed to the step that can clear it, so a family's figures say whose work is left.

**Options:**

- (a) The owners proposed below.
- (b) Commencement reader for every entry. This is simpler, but the grouping then says nothing.
- (c) Leave the owners unset.

**Proposed** (dry run, nothing written). The table is at `backend/data/reports/commencement-reader/feed-owners/owners-dry-run.md` and the fixture as it would be written is at `feed_differences.proposed.json`. Rows are from the 2026-11-23 gate reports.

| owner | entries | rows | what |
|---|---:|---:|---|
| Commencement reader | 18 | 2,970 | its one-law wordings (RULES section 11), and its reading of the inserting laws' commencement (unread, appointed, rules not held, not reached, no text rules, the inserted "differ" check) |
| legislation.gov.uk | 6 | 1,742 | the feed is short and neither side is wrong: the feed holds only the first stage, gives the insertion no date, or neither the feed nor the note names the inserting law or provision |
| Sources | 4 | 87 | "fix: fetch": a document the reading needs is not held |

**Recommendation:** (a). The fixture is written on your go.

**Decided (Jason 2026-11-23): (a), with no legislation.gov.uk owner** ("we just consume what's given").

- A feed difference is a pattern. Where the feed holds the law's commencement (the practical cut: does the feed give the data?), the feed is the date unless proven wrong. Where it doesn't, the Reader is the truth. A pattern found only where the feed speaks is a known limit; one reaching laws without feed data is the Reader's to fix. Evidence takes the feed unless a proven feed error, then the Reader.
- Written: 24 entries owned by the Commencement reader, 4 by Sources. RULES `feed-differences-are-patterns-by-feed-coverage`.
- The pattern-by-coverage work is the new pending session `2026-11-23-commencement-reader-feed-differences-as-patterns.md`, placed after the order split and before the Extent readiness review. That session also checks the build against RULES §7, which today says the law's text comes first.

## 5. Pre-flight

- Code commits 6e22b7ed and cf6904fe, both through the hooks.
- Targeted tests: 11,560 pass. Architecture tests: 34 of 34. Credo diff adds no issue. Dialyzer passes.
- Round previews (Waste, Water and Climate), with the read caches cold under the new clause stamp:
  - own: 565 laws, 0 change, 14 s;
  - amending: 969 laws, 0 change, 62 s.

  Nothing was written: 72,043 rules, and the max `read_at` is still 06:51.

## 6. The one-time cycle (Jason's go, 2026-11-23)

Every stamp moved once, so every stored rule and every build is stale on the commencement reader. The extent readings are stale too, because `Extent.ReadVersion`'s files changed.

- **Re-read:** 72,043 rules (clause 9,744 in 4,137 sources; orders 10,750 in 851; effects 51,549 in 983). Identical rules now write only the stamp, so the re-read moves no `read_at` where nothing changed. Estimate: about 30 to 45 minutes, family by family (`mix lat.reread --run`).
- **Rebuild:** the builds' code version moved too (`ChangeVocabulary.Version`: files moved), so all 1,092 built laws need a rebuild. Estimate: about 32 minutes at 3 workers (the round took 982 s for 565 laws).
- **Before it:** a restore point of `commencement_rules`, `provision_changes`, `provision_change_claims` and `lat_events`.
- **Extent re-read:** left to the Extent reader step's first substep, as planned.

**Run.**
- Restore point `staleness-cycle` on the NAS (10 s).
- `mix lat.reread --family F --run`, one family at a time, for the 2 rounds and 11 families with built laws: about 59 minutes in all (Waste, Water and Climate alone 1,112 s). Logs in `backend/data/reports/commencement-reader/staleness-cycle/`.
- UK_ukpga_2018_16 has no family; its stale sources were re-read and it was rebuilt by hand.
- **All 1,105 laws built before the cycle are rebuilt, and none is stale on the commencement reader.**

**More was built than planned: 156 laws never built before.** `lat.reread`'s build step builds the whole family (`lat.vocabulary --build --family F`). That is right for a family in the step. But I also ran it for the small families that held only a few incidental builds (Building Safety, Town & Country Planning, Road Safety, Nuclear, Coronavirus, Consumer, Plant Health, Trees).
- 5 of those builds failed with "no stored CLML body". These are laws in families never through Sources.
- 109 of the new builds are stale on the commencement reader: their sources were never re-read, because the chain picks its rules from the laws already built when it starts.
- No label reads them, since these families are not switched. The question for Jason is below.

## 7. Check

- **Pass rule, re-read.** A second re-read of the round, writing, with unchanged code: 565 own laws and 969 amending laws, 0 written, all "unchanged (stamp only)", in 29 s. The max `read_at` did not move.
- **The round's staleness is as at the close:** 565 stale laws (`labels_version`), and 263 builds stale only on the extent reader (the Extent reader step's first substep).
- **Orders-only trial:** a comment added to `order/entries.ex` moved only the orders stamp (clause, effects, build, fold, extent and labels unchanged). Reverted.
- **The round's commencement check is PASS:** our faults 0, leftovers not named 0, stale feed errors 0, groups with no status 0. The feed figures equal the close on every class. By owning step: Commencement reader 2,929 rows (21 groups), Sources 87 (2).
- **The four switched families' checks are PASS:** Fire and OH&S, OH&S Occupational, Environmental Protection, Maritime.
- **Golden 27/27. Extended golden 44/50, one more than the close's 43:** UK_ukpga_1963_41 s.91 went from FAIL to PASS.
  - Its order, SI 1964/191, had been stale since before the Waste, Water and Climate step. The cycle read it with the current order reader: Part I "Section 91(1), (2) and (3)" (18 February and 1 May 1964), Part III "Section 91(4) and Schedule 2" (1 August 1964).
  - The old rule had brought the whole of s.91 in on 1 August 1964. The new reading follows the words, so the pass is right by design.

## Decisions for Jason (after the cycle)

**A. The 156 builds the cycle added.**
- *Aim:* `binds-on-date`. A build no label reads gives figures without a purpose, and shows as stale.
- *Options:*
  - (a) keep them. They are rebuilt when those families reach the Store and build step, and 109 stay stale meanwhile.
  - (b) remove them (their `provision_changes`, `provision_change_claims` and `changes_built` events), back to the 1,105 built before.
- *Recommendation:* (b). They were built by my running the chain beyond the families in the round, not by any step.

**B. Relabel the switched families.**
- The file moves changed `FoldVersion` and `LabelVersion`, so all 527 switched laws are stale on the labels (`fold_version` 527; `labels_version` 1,117 across all families, against 565 at the close).
- *Options:*
  - (a) relabel the switched families now, with `mix lat.relabel`, a preview then an apply;
  - (b) leave it to the Label fold step's next run.
- *Recommendation:* (a), so the switched labels match the code. The preview first shows whether any label changes; none should, as the moved code reads the same.
