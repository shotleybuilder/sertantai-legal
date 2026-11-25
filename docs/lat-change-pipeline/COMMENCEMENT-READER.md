# The Commencement reader: what it does (accepted, Jason 2026-11-23; revised 2026-11-25)

The step's spec: its aim, its scope, its boundary with the Amending-law reader, its substeps, and what makes them loop. The forms it reads are in `COMMENCEMENT-GUIDE.md` §3; the rules it follows are in `RULES.md`. From the Waste, Water and Climate retrospective (`.claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-retrospective.md`). Revised on 2026-11-25, after the retrospective's follow-on sessions closed:
- step procedures;
- staleness;
- the old path's decouple;
- the order split;
- the clause split;
- feed differences as patterns.

It describes the reader as it stands after them. The traps met in its code are in `backend/lib/sertantai_legal/scraper/commencement/CLAUDE.md`.

## 1. Aim

**For every provision we hold, and for every amending provision that changes one, say when it came into force: the date, whether partly or fully, and for where. It reads this from the law's own words and its commencement orders.** It serves `binds-on-date` (AIMS): on the date the user picks, is this provision in force?

The reader records claims; it does not label. The Label fold turns its claims into status and dates (`readers-carry-meaning-later`).

## 2. Scope

**In scope:**
1. **A law's own commencement:** its commencement clause, its metadata, and a provision's own words ("This section comes into force on …"). This covers whole-law starts, staged starts, purposes, territories, a day relative to making or laying, named days, and EU apply-from days.
2. **Its commencement orders:** the orders that commence it, read for the provisions, dates, purposes and places they name.
3. **When an amending provision came in:** the amending law's own clause and its orders, read for the provision that makes the change. The amending law is read for **when only**. What it changed is the Amending-law reader's (§3).
4. **The check against the feed:** every row's reading compared with legislation.gov.uk's commencement record, the differences grouped by cause, and feed errors proven from the words (RULES `commencement-feed-gate-is-two-way`).

**Out of scope:**
- **What an amendment changed and who made it** (operation, level, text): the Amending-law reader.
- **Where a law or a change applies** (extent and application): the Extent reader. A commencement rule's territory says only *where the date applies*.
- **Which source wins** when the law, its orders and the feed disagree: Evidence (the source order) and the Label fold (the label).
- **Fetching documents:** Sources. A missing order or Schedule found by this step is a fetch for Sources to own, listed by Find.
- **The register's making flag and a law's family:** Making laws.
- **Standard figures from the feed comparison:** Measures (§6).

## 3. The boundary with the Amending-law reader

For a change law B makes to law A:

| Question | Who answers | From | Stored as |
|---|---|---|---|
| What changed (operation, level, words) | Amending-law reader (`Amendment.Reader`) | B's amending instructions | `amendment_rules` |
| Who made it | Amending-law reader | B itself, the note's citation | `amendment_rules`, claim `by` |
| **When it took effect** | **Commencement reader** | **B's own commencement clause and B's orders** | `commencement_rules` (commences: B) |
| Where it applies | Extent reader | B's extent and application words | `extent_rules` |

- **They don't duplicate work:** each question has one owner. The Amending-law reader reads no dates (`Amendment.Reader.Commencing` only skips a lead-in; `architecture/commencement_read_test.exs`).
- **How the build joins them:** `Readers.AmendingLaw` takes the change from `amendment_rules`, then asks `AmendingCommencement.claims/3` for its date from B's commencement rules. If there is none, `NoteDate` and then `AmenderStart` fill the gap (the earliest start, the feed's included).
- **Why the step felt like amending-law work:** the feed gate compares every row, inserted rows included, so differences in *when an insertion took effect* fell to this step. That was right by the table above, but the work was never planned as a phase. Decisions 7, 8, 13, 16 and 19 were all of this kind.
- **Overlaps** (point 4 of the retrospective), as they stand:
  - **The old dater is fenced, not deleted.** `Commencement.Amending.evaluate/4` still serves the old label path (`Amendment.Collect` for `lat_change_log`) for every unswitched family. The new path picks its laws from the change register, never `lat_change_log` (`AmendingPicks`), and the build's and readers' stamps leave the old dater out (`OldPathFenceTest`). It is deleted when every family has switched (DATA-ARCHITECTURE G1).
  - **B's document parsed by up to four passes**, each with its own cache (`ClmlRows`/`AmendingRead`, the amendment index, `Extent.ReadCache`, `Primary.fresh_rules/3`): still open.
  - **Shared helpers** are their own modules, outside the readers (`ClmlRef`, `RefContext`, `LawStart.Sentences`, `commencement/text/*`). So an edit to a reader no longer stales the Extent reader's stamp.

## 4. The substeps

| Substep | Task | Reads | Writes | Stale when |
|---|---|---|---|---|
| Own clause | `lat.commencement --read [--preview]` | the law's LAT rows (or its whole CLML when its LAT is a scope), the register, the store | `commencement_rules` (own treatments of that law), only where they changed | its stamp `ReadVersion.Clause` moves (63 files: the clause reader, `law_start/**`) |
| Orders | `--read-orders --family F` / `--law X --held` `[--preview]` | the order lists kept (`data/cache/commencement-orders/`), the orders held, **the Act's own rules** | `commencement_rules` (`order_date`, `order_schedule`), only where they changed | `ReadVersion.Orders` moves (50 files: `commencement/order/*`); the Act's own rules change |
| Amending laws' own clause | `--read-amending --family F --workers 1 [--preview]` | the amenders of the family's **stored changes** (`HeldAmenders`), their CLML | `commencement_rules` (commences: the amender), only where they changed | `ReadVersion.Clause` moves; the build changes which amenders it lists |
| Feed effects | `--effects [--law A,B] [--preview]` | the stored changes feed of the amending Acts the change register names (`AmendingPicks`) | `commencement_rules` (`feed_commencement`, 62,953 of 84,554 rules) | the feed is fetched again; `ReadVersion.Effects` moves (4 files) |
| Build | `lat.vocabulary --build` | `commencement_rules` for the law **and every law whose changes it holds**, `amendment_rules`, `extent_rules`, the feed, the markup | `provision_changes`, `provision_change_claims` | `ChangeVocabulary.Version` (it holds `law_start/**` and the shared helpers, never the order or clause readers); a rule it reads re-written; a reading on an old stamp (`Store.Inputs`, `:commencement_reader`) |
| Check | `lat.commencement_check [--coverage]` | rules, LAT rows, **the stored changes** (gaps and the feed comparison), the status, feed-error and feed-difference fixtures | reports; the feed yardstick (`data/reports/commencement-reader/yardstick/<family>.json`) | it reads the last build, so it is only as fresh as that build |
| Catalogues | `lat.commencement_patterns`, `lat.order_patterns`, `lat.difference_patterns` | every law's own clause and every order held | dry-run files; the fixtures only with `--accept` | their own version hashes |

**The step's procedures are tasks** (`step_procedures/`, outside every stamp):
- `mix lat.reread --family F [--run --tag T]` runs the re-read chain in order;
- `mix lat.stale --family F --reasons` counts what is stale and why;
- `mix lat.held_moves` writes held catalogue moves.

## 5. Why the substeps loop

What the follow-on sessions changed, and what still loops:

1. **One stamp per read path** (clause, orders, effects), each an explicit list held to its path's reach (`CommencementReadStampsTest`, `StageSplitTest`). An orders fix stales only the orders' rules and the builds that read them.
2. **An identical re-read writes nothing but the stamp** (`Store.write_changed/3`, RULES `a-re-read-writes-only-changed-rules`). `read_at` stays, so no build goes stale through it: the round re-read with unchanged code wrote 0 of 1,534 laws in 29 s.
3. **Still: a change to `law_start/**` stales every build.** The build calls `LawStart` itself, so even a type-only edit needs a stamp-only cycle (rebuild, relabel the switched laws).
4. **Still: builds read other laws' rules.** A round's builds stay stale until the source laws' rules are re-read (`a-step-re-reads-its-sources-rules`). `lat.reread` lists and runs that chain.
5. **Still: orders need the Act first,** and the amender list comes from the last build (build → `--read-amending` → build).
6. **Still: a tie to a tied law needs a second pass** (SI 2020/1460 → SI 2020/852). After a tied-path fix, re-read the tied laws until nothing is written.
7. **Gone:** the two modes that picked their laws from `lat_change_log` now pick from the change register (`AmendingPicks`).

What this means for a step:
- fix in a batch;
- run `lat.reread --run` after the last reader commit;
- read `lat.stale --reasons`.

A commit after the last re-read needs the chain again, but now only for the path it touched (WORKFLOW "How a step is run").

## 6. The feed as a yardstick

The check compares each row with the feed's commencement record:
- agree;
- differ;
- feed only;
- feed partly only;
- ours only;
- neither.

Every difference group is statused, and a feed error is claimed only with proof in the law's words.
- **Standard figures:** `Measures.FeedYardstick`, recorded by every `lat.commencement_check --family F` run and printed by `lat.measures`.
- **Feed coverage** (RULES `feed-differences-are-patterns-by-feed-coverage`): a law is covered when its stored feed holds a dated coming-into-force record (`Commencement.FeedCoverage`; 559 of 1,644 laws with LAT). A difference is a pattern (`Review.DifferencePatterns`, `mix lat.difference_patterns`):
  - held where the feed is silent: the Reader's to fix;
  - held only where the feed speaks: a known limit.
- **Which source to take when they differ** is not this step's: the build still takes the Reader's date on a known-limit row. That is Merge's to design (issue #200).

## 7. Open questions

Settled by the follow-on sessions:
- a version per substep;
- rules re-written only when they change;
- the old path's inputs fenced off;
- `Commencement.Order` (12 modules) and `LawStart.Provisions` and `LawStart.Clause` (18) split.

Still open:
- **`Commencement.Amending`** is deleted only when every family has switched (Store and build, DATA-ARCHITECTURE G1).
- **Is `--effects` still needed?** The build uses its rules only in `AmenderStart`'s last gap.
- **One amending law parsed by four passes** (§3).
- **The feed's date on covered laws** (Merge, #200).
- **Same-day stages follow the store's row order** (`stage-order-follows-store-order`, Store and build): a rebuild can swap them, which is expected in a digest diff.
