---
session: 'Commencement reader: staleness that follows what changed'
status: closed
opened: 2026-11-23
closed: 2026-11-23
outcome: success
lane: build

summary: >
  A commencement re-read now writes only rules that changed (an identical reading moves only the
  reader stamp and keeps read_at), and each rule carries its own read path's stamp (clause 45
  files, orders 33, feed 4, against one 63-file stamp), each test-held to exactly its path's reach;
  the build's, the fold's and the extent reader's versions no longer hold the order reader. The
  one-time cycle re-read and rebuilt every built law; a second re-read of the round wrote 0 rules,
  and the round check, feed figures, switched families and label gates match or pass.

decisions:
  - what: Identical re-reads write only the stamp (Store.write_changed/3), keeping write/3's result shape
    why: delete and re-insert moved read_at, which stales every build reading the rules (Store.Inputs max(read_at))
    result: the round re-read with unchanged code, 1,534 laws, 0 written, 29 s, max read_at unmoved
  - what: Three read stamps by treatment (ReadVersion.Clause, .Orders, .Effects), explicit lists, exact reach
    why: one folder-globbed stamp let an order fix stale the 51,549 feed rules, and a tool module beside the readers stale all
    result: CommencementReadStampsTest; an orders-only edit moves only the orders stamp
  - what: Shared helpers moved out of the order and clause readers (ClmlRef.ref, RefContext, LawStart.Sentences, Commencement.Text.*), delegates kept
    why: naming Order (for 44 ref and 8 context calls) pulled the whole order reader into the build's and extent stamps
    result: order.ex and order/* in neither ChangeVocabulary.Version, FoldVersion nor Extent.ReadVersion; Extent.ReadVersion explicit, 52 files
  - what: Feed-difference statuses name an owning step, ours only (Jason, Decision 1)
    why: 'Jason: "legislation.gov.uk as an owner doesn''t work because we just consume what''s given"'
    result: 24 entries Commencement reader, 4 Sources; RULES feed-differences-are-patterns-by-feed-coverage; the patterns-by-coverage work is a pending session
  - what: Keep the 156 builds the cycle added in small families (Jason, Decision A)
    why: 'Jason: "doesn''t do any harm"; built because lat.reread builds the whole family'
    result: 109 of them stale on the commencement reader until those families reach Store and build
  - what: Relabel the 527 switched laws, gated (Jason, Decision B (a))
    why: the file moves staled FoldVersion and LabelVersion; the preview showed 3,132 label changes in 40 laws, the Waste, Water and Climate Commencement reader step's fixes reaching labels last refreshed 2026-11-17
    result: relabelled, 0 failed; label gate PASS for Fire and OH&S, OH&S Occupational, Environmental Protection, Maritime (groups not named 0)

metrics:
  stamps: { clause_files: 45, orders_files: 33, effects_files: 4, old_single_stamp_files: 63, extent_files: 52, build_files: 194 }
  store: { rules: 72371, clause_rules: 9744, orders_rules: 10750, feed_rules: 51549 }
  cycle: { reread_and_rebuild_s: 3510, built_before: 1105, rebuilt: 1105, new_builds: 156, new_build_failures: 5 }
  second_reread: { own_laws: 565, amending_laws: 969, written: 0, seconds: 29 }
  checks: { round_check: PASS, switched_checks: "4 PASS", golden: "27/27", golden_extended: "44/50 (was 43; 1963 c.41 s.91 by design)", label_gates: "4 PASS" }
  relabel: { laws: 527, label_changes: 3132, laws_changed: 40, failed: 0 }
  tests: { targeted: 11560, architecture: 34 }

lessons:
  - title: A family chain run outside its round builds the whole family
    detail: lat.reread's build step is lat.vocabulary --build --family F, right for a family in the step but not for families that hold only incidental builds; it built 156 never-built laws (5 failed, no CLML) and left 109 stale, because the chain picks stale rules from the laws already built when it starts. Rebuild incidental builds by --laws instead.
    tag: tooling
  - title: A staleness refactor can surface earlier steps' unapplied work
    detail: the cycle's re-read of long-stale rules and the relabel brought the Waste, Water and Climate step's commencement fixes into switched families' labels (3,132 changes, last relabelled 2026-11-17). "No change expected" held for this session's code (previews 0) but not for the store; preview the relabel before applying, and gate it.
    tag: data
  - title: Static reach, not calls, decides a version's files
    detail: the build called only two small functions of Order, but naming the module put all of the order reader in its stamp; moving shared helpers to their own modules is what shrinks a stamp, and an exact-reach test holds it.
    tag: tooling
  - title: Splice by path, not by name-status, when committing moves
    detail: git diff --name-only cannot combine with --name-status, so the moved files' old paths were missed and HEAD briefly held both copies; cf6904fe committed the deletions.
    tag: tooling

bugs:
  - pattern: "Shared amending-law document readers (amending_law/text.ex, doc.ex) sit in 5–8 reader versions, so an amendment-only reading change stales commencement and extent rules too"
    category: version-over-reach
    module: Commencement.ReadVersion, AmendingLaw.Extent.ReadVersion
    affected: every commencement and extent rule on each edit
    fix: "each read stamp lists only its path's reach (CommencementReadStampsTest): the feed stamp holds neither file, text.ex is out of the clause and extent stamps"
    step: Commencement reader
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/store.ex
  - backend/lib/sertantai_legal/scraper/commencement/read_version.ex
  - backend/lib/sertantai_legal/scraper/commencement/read_version/clause.ex
  - backend/lib/sertantai_legal/scraper/commencement/read_version/orders.ex
  - backend/lib/sertantai_legal/scraper/commencement/read_version/effects.ex
  - backend/lib/sertantai_legal/scraper/commencement/ref_context.ex
  - backend/lib/sertantai_legal/scraper/commencement/text/
  - backend/lib/sertantai_legal/scraper/law_start/sentences.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_version.ex
  - backend/lib/sertantai_legal/scraper/commencement/review/feed_differences.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/feed_yardstick.ex
  - backend/test/sertantai_legal/architecture/commencement_read_stamps_test.exs
  - backend/test/fixtures/commencement_check/feed_differences.json
  - backend/data/reports/commencement-reader/staleness-cycle/
  - backend/data/reports/commencement-reader/feed-owners/
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md

depends_on:
  - 2026-11-23-commencement-reader-step-procedures
  - 2026-11-23-commencement-reader-retrospective

enables:
  - 2026-11-23-commencement-reader-old-path-decouple
  - 2026-11-23-commencement-reader-order-split
  - 2026-11-23-commencement-reader-feed-differences-as-patterns
---

# Session: Commencement reader: staleness that follows what changed (CLOSED)

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
- ✅ 8. Close: DATA-ARCHITECTURE row; RULES rule; session close; commits by path

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
- **Decided (Jason 2026-11-23): (a), keep them** ("doesn't do any harm").

**B. Relabel the switched families.**
- The file moves changed `FoldVersion` and `LabelVersion`, so all 527 switched laws are stale on the labels (`fold_version` 527; `labels_version` 1,117 across all families, against 565 at the close).
- *Options:*
  - (a) relabel the switched families now, with `mix lat.relabel`, a preview then an apply;
  - (b) leave it to the Label fold step's next run.
- *Recommendation:* (a), so the switched labels match the code. The preview first shows whether any label changes; none should, as the moved code reads the same.
- **Decided (Jason 2026-11-23): (a), run it.** The 527 switched laws stale on the labels: preview `mix lat.wave_preview --laws … --relabel --tag staleness_relabel_dry` (rolled back), then a restore point, then `mix lat.relabel --laws …`.

## Relabel (Decision B, a)

- Restore point `staleness-relabel` (`lat_change_log`, `lat_label_timeline`, `lat_events`).
- `mix lat.relabel --laws …` over the 527 switched laws: 0 failed. Switched laws stale on the labels: 0 of 527.
- Label gate (`mix lat.label_check --gate --all`): PASS for all four families, groups not named 0 (Fire and OH&S, OH&S Occupational, Environmental Protection, Maritime).

## Close

- **Docs changed:**
  - RULES: `a-re-read-writes-only-changed-rules`, `feed-differences-are-patterns-by-feed-coverage`, and the two-way gate's statuses.
  - DATA-ARCHITECTURE: the `commencement_rules` row and the reader-version paragraph.
  - `COMMENCEMENT-READER.md`'s revision stays the readiness review's todo.
- **No step close (`lat.step_close`):** this is a follow-on session across the round, not a pipeline step.
- **Bugs:** the shared-reader version bug is marked fixed. Nothing left in a parking list.
