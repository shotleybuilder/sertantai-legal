# The Commencement reader: what it does (DRAFT for Jason, 2026-11-23)

The step's spec: its aim, its scope, its boundary with the Amending-law reader, its substeps, and what makes them loop. The forms it reads are in `COMMENCEMENT-GUIDE.md` §3; the rules it follows are in `RULES.md`. From the Waste, Water and Climate retrospective (`.claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-retrospective.md`).

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
- **Overlaps to remove** (point 4 of the retrospective):
  - **A second dater:** `Commencement.Amending.evaluate/4`, the old label path, dates the same amending provision effects first. The build dates it from the text first. It is used only by `Amendment.Collect` for `lat_change_log`, and DATA-ARCHITECTURE marks it to retire.
  - **B's document parsed by up to four passes**, each with its own cache:
    - `ClmlRows`/`AmendingRead`;
    - the amendment index;
    - `Extent.ReadCache`;
    - `Primary.fresh_rules/3`.
  - **Shared files:** seven files are shared between `Commencement.ReadVersion` and `Amendment.ReaderVersion` (the document reader, text, defined terms, refs). An edit there stales both readers and the extent reading.

## 4. The substeps

| Substep | Task | Reads | Writes | Stale when |
|---|---|---|---|---|
| Own clause | `lat.commencement --read` | the law's LAT rows (or its whole CLML when its LAT is a scope), the register, the store | `commencement_rules` (own treatments of that law) | the reader's code changes (`ReadVersion`, 63 files) |
| Orders | `--read-orders --family F` / `--law X --held` | the order lists kept (`data/cache/commencement-orders/`), the orders held, **the Act's own rules** | `commencement_rules` (`order_date`, `order_schedule`) | the reader's code changes; the Act's own rules change |
| Amending laws' own clause | `--read-amending --family F --workers 1` | the amenders of the family's **stored changes** (`HeldAmenders`), their CLML | `commencement_rules` (commences: the amender) | the reader's code changes; the build changes which amenders it lists |
| Feed effects | `--effects` | the stored changes feed of amending Acts named in the old register (`lat_change_log`) | `commencement_rules` (`feed_commencement`, 51,549 of 72,043 rules) | the feed is fetched again; the reader's code changes |
| Build | `lat.vocabulary --build` | `commencement_rules` for the law **and every law whose changes it holds**, `amendment_rules`, the feed, the markup | `provision_changes`, `provision_change_claims` | `ChangeVocabulary.Version` (198 files, **54 shared with ReadVersion**); any rule it reads re-written (`max(read_at)`) |
| Check | `lat.commencement_check` | rules, LAT rows, **the stored changes** (gaps and the feed comparison), the status and feed-error fixtures | reports only | it reads the last build, so it is only as fresh as that build |
| Catalogues | `lat.commencement_patterns`, `lat.order_patterns` | every law's own clause and every order held | dry-run files; the fixtures only with `--accept` | their own version hashes (44 and 55 files) |

## 5. Why the substeps loop

1. **One reader edit stales everything.**
   - `ReadVersion` covers all the reader's code, so any fix makes every stored rule (72,043) out of date.
   - The same edit usually changes `ChangeVocabulary.Version` (every build) and `Extent.ReadVersion` (95 files, which include `order.ex` and `law_start/*`).
   - Clearing it means re-reading own clauses, then orders, then amending laws, then the source laws, then the rebuild: about an hour for a round.
2. **Any re-write stales the readers of those rules, even when the rules are unchanged.** `Store.write` deletes and re-inserts, so `read_at` moves, and every build that reads the rules goes stale, in any family.
3. **Builds read other laws' rules.** A round's builds stay stale until the source laws' rules (amenders with LAT in other families, feed instruments, orders) are re-read (`a-step-re-reads-its-sources-rules`). Re-reading those then stales other families' builds (2).
4. **Orders need the Act first.** An order's "appointed for" is resolved against the Act's own rules, so own clauses are read before orders.
5. **The amender list comes from the last build.** `HeldAmenders` reads the stored changes, which gives build → `--read-amending` → build.
6. **Two modes still pick their laws from the old register.** `--effects` and the no-flag `--read-orders` use `lat_change_log`, which only `LabelRefresh` writes.

What this means for a step: fix in a batch, then **one** re-read and rebuild after the last reader commit. Any commit after it costs the whole cycle again (Waste, Water and Climate ran it three times).

## 6. The feed as a yardstick

The check compares each row with the feed's commencement record:
- agree;
- differ;
- feed only;
- feed partly only;
- ours only;
- neither.

Every difference group is statused, and a feed error is claimed only with proof in the law's words.
- **Standard figures from it** belong to Measures: the six counts per family and round, the feed errors proven, and the groups by owner. They should be printed every run (retrospective point 5).
- **Which source to take when they differ** is not this step's to decide: Evidence (the source order) and the Label fold.

## 7. Open questions for the retrospective

- Narrow the staleness:
  - a version per substep (own clause, orders, amending), rather than one for the whole reader;
  - rules re-written only when their content changes (the amendment read pass already does this).
- Retire the old path's dater (`Commencement.Amending`) and the `lat_change_log` inputs (§5.6).
- Is `--effects` still needed? The build uses its rules only in `AmenderStart`'s last gap.
- Split `Commencement.Order` (2,188 lines, 169 functions, 58 patterns) by the family of form it reads.
