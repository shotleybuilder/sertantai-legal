---
session: CV-S02a Parser tell-tales
status: active
opened: 2026-10-23
---

# Session: CV-S02a Parser tell-tales (ACTIVE)

## Problem

The CV-S02 feed-reader check senses markup faults the LAT parse passes on faithfully. Jason (2026-10-23): they are raised against the parser, fixed in this sub-session straight after CV-S02, as general patterns, never as one-law fixes. Then back to the workflow (CV-S03).

## Todo

- ✅ What good looks like, agreed with Jason (2026-10-23)
- ✅ #182 (code, `84ea7ffb`; re-parse pending): a non-breaking space in EU section_ids (639 rows, 15 laws); the spelling is unstable within a law. Name from the number, normalised.
- ⬜ #183: CLML structure faults sensed as diagnostics (ids that contradict their nesting: 27 elements in 4 laws; levels skipped: 14 in 3 laws); decide one general repair rule, if any.
- ⬜ #184: numbered items with no id get no row (1,652 ListItems in 114 laws; CLP Art. 2's definitions, REACH Art. 57 points)
- ✅ #185 (code, `84ea7ffb`; re-parse pending): row names with doubled brackets, `art.Article 77(2)((e))` (79 rows in 9 laws)
- ⬜ Note: `ParserVersion` already moved with CV-S02 NEW-D (`ChangesFeed` reads lowercase "other"); the re-parse plan covers it
- ⏸️ The shared namer (`Commencement.Order.ref/1`) drops nested schedule ids: `schedule-N-part-P-paragraph-M` → `sch.N.pt.P`; unnumbered `schedule-paragraph-1` → `sch.paragraph`. 48 collisions in the family's feeds, none in the body (CV-S02 NEW-C). Deferred until schedules are parsed (no schedule rows in v0.1); fix it with the schedule naming decision
- ⬜ Re-parse plan for the affected laws only: dry run → Jason → restore point → apply; tell fractalaw (renamed rows).

## Dependencies

- ✅ CV-S02 Feed reader closed PASS (2026-10-23)

## What good looks like (agreed 2026-10-23)

1. #182 and #185: no row name in the corpus carries a Unicode space or `((`; a parser test per pattern; the reader's tolerance (`Ref.canonical`) stays as a guard.
2. #184: a numbered list item with no id gets a row named from its parent and its own number; the count of numbered items without a row goes to 0, or the remainder is measured and explained.
3. #183: sensed as diagnostics (counts match 27 / 14); repair or not discussed with Jason.
4. Re-parse of the affected laws only (dry run → Jason → restore point → apply); renamed rows to fractalaw; OH&S feed check still 0 reader faults with fewer tell-tales; golden 27/27.

## #182 / #185: one naming rule

Measured in the DB (2026-10-23): the number is taken from the text with its decoration, wider than the two issues:
- Unicode spaces: 640 rows in 16 laws (639 non-breaking, 1 figure space U+2007 in `UK_ukpga_1996_18` `ch.Chapter 4`), including Part/Chapter names (`pt.PART 4`, `ch.CHAPTER V`).
- Brackets: 79 rows in 9 laws, including a single extra one (`UK_ukpga_2006_46` `s.445(1))`, CLML `<Pnumber PuncAfter="">1)</Pnumber>`).
- Prefix word left on: 26 rows (`pt.PART15`, `pt.PART3A`), and a heading as a number (`UK_nisr_2016_366` `ch.SUB-PART A: MAKING AVAILABLE ON THE MARKET`).

The rule (`LatParser.Ids`): spaces cleaned (`Ids.clean/1`), brackets round a number dropped (one inside it stays), the prefix word stripped whatever space follows or none (not before a letter), a number holding a space after a dash split is a heading numbered by the id. Tests in `ids_test.exs`. Takes effect on the re-parse.
