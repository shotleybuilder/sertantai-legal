---
session: 'AR-04: Switch-over'
status: active
bugs:
  - pattern: 'Parent placement left the note''s row with no record: the label timeline saw a dated change by the law on an ancestor, dropped the row''s undated_change gap, and fell back to the law''s start — a confident wrong date (Electricity Act s.42(1)(b): 1989 for text changed in 2001)'
    category: amending-law
    module: Amendment.Collect
    affected: 'up to 165 rows (the parent placement class)'
    fix: 'the change lands on the provision named and on the note''s row inside it (Jason option a)'
    status: fixed
  - pattern: 'A rule reaching a row through an ancestor (bracket set semantics: a repeal of (1)(c) also targets (1)) wrote a whole "repealed" on the ancestor and the note''s row — the projection would mark both repealed'
    category: amending-law
    module: Amendment.Collect
    affected: 'caught in test before any write'
    fix: 'through an ancestor both records are words-level; a rule naming the row itself wins'
    status: fixed
  - pattern: 'A section named at the start of a sentence ("Section 42 of the 1989 Act is amended as follows.") gave no section number: the kind word matched lower case only (same in the deleted Target) — every sub-provision instruction under such a lead read no rules'
    category: amending-law
    module: Amendment.Reader.numbers
    affected: 'unknown until the corpus preview (2000 c.27 s.57(2) among them)'
    fix: 'kind word case-insensitive'
    status: fixed
  - pattern: 'The amending-law record of a repeal (no savings) beside the feed''s same repeal with savings won the projection''s tie-break (evidence string) — repealed_saved shown as repealed (Electricity Act s.41A(8)(b); Building Act s.51B(2), EPA s.78M(7) already wrong in today''s register)'
    category: label-projection
    module: LabelProjection
    affected: 'at least 3 in 4 laws'
    fix: 'a repeal is saved when any repeal of the row by the same law on the same date carries savings'
    status: fixed
  - pattern: 'Whole repeals read from an amending law on rows its revised text shows in force (corpus preview ar04_dry: 50 rows in force/unknown → repealed): a modification read as a repeal ("Section 173 shall have effect as if any reference to an order were omitted"), an emptied quote ("“” shall be omitted"), "each of the following is omitted—" (a list of words), a repeal by an NI instrument applied to a GB row'
    category: amending-law
    module: LabelProjection / Amendment.Reader
    affected: '50 rows in the corpus preview'
    fix: 'projection: an amending law''s whole repeal never repeals a row the markup shows in force (dates it only); reader: modifications no rule, emptied quotes and "each of the following" words'
    status: fixed
  - pattern: '"Sections 22 to 25 … are repealed" read as sections 22 and 25 only'
    category: amending-law
    module: Amendment.Reader.numbers
    affected: unknown
    fix: 'N to M is a range target (s.N..s.M)'
    status: fixed
  - pattern: 'An amending-law record carries no territory: a devolved instrument''s change (nisr / ssi / wsi, nia / asp / anaw) reads as UK-wide (NI SR 2009/248 repealing Explosives Act 1875 ss.53–76 for NI only)'
    category: amending-law
    module: Amendment.Collect
    affected: 'unknown; the projection guard stops its false repeals'
    fix: 'the record''s extent from a devolved amending law''s own jurisdiction'
    status: open
opened: '2026-10-19'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-04: Switch-over (ACTIVE)

## Problem

Amendment ruleset (AR-00 meta): labels still come from the old row matcher (`ChangeCollector.AmendingLaw` → `AmendingLaw.Target` / `RepealTable`), re-parsing every amending law per law collected. AR-03 built the reader, the stored rules and a store-backed collector (corpus gate: 0 lost, 101 relabels, 165 parent placement — Jason, 93 new). Switch the change register onto them, delete the old matching, one corpus run, Jason, apply.

## Todo

- ✅ Read-pass index carries the reader version and the laws read for; the read pass re-reads a stale or missing index (not just a missing one)
- ✅ `ChangeCollector.amending_law/4` onto `Amendment.Collect`: stored source when the index is current and covers the law, else the document read as before (no silent loss for an amending law not yet read)
- ✅ Delete `ChangeCollector.AmendingLaw`, `AmendingLaw.Target`, `RepealTable` (its `reference/2` into the reader), `RowRef`; port the LR-08 collector tests onto `Amendment.Collect`
- ✅ Architecture test: only `Amendment.Reader` reads instructions into changes (no row matcher)
- ✅ `Commencement.Evaluator` onto `LatRef` (chain / covers?) — behaviour-preserving, its tests unchanged
- ✅ `LabelVersion`: `scraper/amendment/*.ex`, `lat_ref.ex`; `provision_qualified` catalogue text (AR-00)
- ✅ Full suite (2,880); commit `dab2ea1a`
- ✅ Read pass under the new reader version (every index stale) — and again after the "Section" fix (`9db8483b`)
- ✅ Dry run: relabel preview on a few laws (pilots 1–7), then the corpus (`ar04_dry`, `ar04_dry2`); label diff classified
- ✅ Jason ("go ahead, restore point then apply"); restore point `2026-10-20-ar04_pre_relabel` (lat_change_log, lat_label_timeline, lat_events); `mix lat.relabel --all` applied — 0 failed, 0 stale
- ⬜ Tell compliance / fractalaw — only when Jason says

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)
- ✅ AR-03 reader, store-backed collector, read pass (closed 2026-10-20)

## Design (2026-10-20)

**Stored rules or the document.** The read pass reads each amending law once for the LAT laws its notes point to *at that time*. A law LAT-parsed later, an amending law first cited later, or rules read by an older reader would silently lose records if the collector only read the store. So the index records `reader` (a hash of the reader's code) and `laws` (the laws read for); the collector uses the stored rules only when both hold, else reads the document as the old collector did (parsed once per law's collection). The read pass re-reads an index whose reader is stale (AR-03 lesson: it skipped by file existence).

## Switch-over (2026-10-20, `dab2ea1a`)

- `Reader.read/4`, `references/1`, `reference/2` moved into the reader (`Collect.read/3` memoises terms only), so `ReaderVersion` counts what a rule depends on (reader, rule, `Doc` / `Text` / `Operation` / `DefinedTerms` / `Locator` / `Pointer`), not the collector.
- Ported, not dropped: the `Target` / `RepealTable` cases run on `Reader.of_text/5` + the evaluator in the matcher's shape; the LR-08 collector tests on `Collect` (`collect_records_test.exs`); the old collector's records on the fixtures pinned (`collect_test.exs`). Three assertions changed — a row inside the provision named now reaches that provision (Jason "Parent"): NRSWA s.148(3)(a), EPA s.6(2)(a), Electricity Act s.11A(7)(b). One caught a reader bug: "at the end of the subsection there shall be added the following paragraph—" is a provision, not words (fixed: the at-the-end rule needs no kind of provision named).
- `provision_qualified` catalogue entry: starts its rows partly (CR-03), text and flag corrected.

**Streaming XML after AR-04** (Jason 2026-10-20: "agree to finish ar-04 first"): LR-45 would save minutes on AR-04's remaining runs (read pass, one preview, apply) for days of work; memory is flat one law at a time; an XML-layer change in the same corpus run would confound the label diff; LR-45 Phase 1's gate (identical rules for every amending law) needs the reader settled. LR-45 starts after the apply.

## Pilot preview (2026-10-20, 4 laws: EPA 1990, Electricity Act 1989, FEPA 1985, Building Act 1984)

- **Pilot 1:** 9 label diffs, 8 right (gains: dated changes now read). 1 wrong: s.42(1)(b) took the law's start, 1989 (bug 1 above) → **Jason: option (a)**, the change on the provision named and on the note's row.
- Tracing (b) found bug 3 (no rules under "Section 42 … is amended as follows"); writing (a)'s test found bug 2 (whole repeals through an ancestor) before any write.
- **Pilot 2** (option (a) only): 380 diffs, almost all gains (191 changed_by, 190 effective_from); Electricity Act undated_change 390 → 216.
- **Pilot 3** (option (a) + guard + "Section" fix): heading rows with no text (s.6, s.15, s.25 …) took the latest change anywhere inside them (s.6: 2024 from "omit the “or” after paragraph (e)") — the parent placement versions rows that didn't change. My "Parent" recommendation was wrong.
- **Jason: option (c)** — reached through an ancestor, the change lands on the note's row only, words-level; the ancestor is never versioned by a change inside it (`ad942d03`). The markup marks the row that changed; the instruction is only less specific.
- **Pilot 5/6:** a per-note ask (skip a note where the feed dates its law) lost real dates — the feed's record can be an "excluded" effect (Building Act s.51A(1)(a)) or not date a single-territory row (EPA s.78A(7)(b)(i)[S]). Reverted; the savings loss it targeted fixed in the projection instead (bug 4).
- **Pilot 7** (`78a04d3a`): 4 laws, 0 errors — 276 changed_by / 275 effective_from gained; 3 repealed → repealed_saved; 5 repealed rows lose a stale territory (a repealed row is nowhere); 9 heading rows with no text lose a changed_by from a child, 11 move back to their own start (option c). Every row moved or emptied has no text of its own.
- **Whole-corpus preview `ar04_dry`** (`78a04d3a`): 1,066 laws, 0 errors; unknown today 16,359 → 16,179; undated_change 15,189 → 14,321; insertion_not_in_register 8,567 → 8,386; markup_conflict 8,180 → 8,137; 2,751 label diffs (~1,040 rows gain a date and changed_by). **50 rows in force / unknown → repealed with the markup showing them in force** — false whole repeals (bug 5) → fixed (`ee12fe50`); read pass and preview `ar04_dry2` re-run.

## Second corpus preview `ar04_dry2` (2026-10-20, `ee12fe50`, read pass re-run)

1,066 laws, 0 errors, labels ok for all. **unknown today 16,359 → 16,159; undated_change 15,189 → 14,259 (−930); insertion_not_in_register 8,567 → 8,366; markup_conflict 8,180 → 8,125**; commenced_by_order 17,440 (unchanged). 2,997 label diffs: changed_by gained 1,120, effective_from gained 1,116, unknown → in_force 198, territory gained 216.

At-risk classes, each traced:
- **in_force / unknown → repealed with markup in force: 0** (was 50).
- **repealed → in_force 36:** the markup shows them in force with text; today's "repealed" was the old matcher's misreading (RTA s.118(4A): the caption verb; Mines and Quarries Act s.70). Corrections.
- **unknown → repealed 10:** markup repealed. Correct.
- **effective_from emptied 17 / changed_by emptied 82:** the old date rode on a false repeal (the rows above: T1 — undated markup change — now applies to an in-force row), or option (c): a change from a child's note no longer placed on the heading / parent and carried to children without notes (WCA s.49 by 2006 c.16: notes only on the rows changed), or heading rows with no text (66).
- **in_force → unknown 8:** 7 heading rows with no text; 1 interpretation section (1984 c.22 s.74) whose words change came from a child's note and whose law has no start of its own.

## Applied (2026-10-20)

Restore point `restore-points/2026-10-20-ar04_pre_relabel` (lat_change_log 135,272, lat_label_timeline 583,410, lat_events 36,424 rows) → `mix lat.relabel --all`: 1,066 laws, 0 failed, 0 stale (labels `e03ac10a312e`). Unknown today 16,159 (= the preview). Spot checks as previewed: Electricity Act s.42(1)(b) in force 2001-10-01 by 2000 c.27; s.41A(8)(b) repealed_saved; Mines and Quarries Act s.173 and RTA s.118(4A) in force (no false repeal); Building Act s.51A(1)(a) 2023-10-01 by 2022 c.30.
