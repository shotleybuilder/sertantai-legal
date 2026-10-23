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
- ✅ #183 (code, `5275d2b0`; re-parse pending): CLML structure faults sensed as diagnostics (ids that contradict their nesting: 27 elements in 4 laws; levels skipped: 14 in 3 laws); decide one general repair rule, if any.
- ✅ #184 (code, `1a389d91`; re-parse pending): numbered items with no id get no row (1,652 ListItems in 114 laws; CLP Art. 2's definitions, REACH Art. 57 points)
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

## #184: measure (2026-10-23, OH&S stored body text, 149 laws, read-only)

Numbered `ListItem`s with no id, outside amendments, versions and schedules: **1,222** (1,864 unnumbered items not counted). The issue's 1,652 counted more widely.

| Where | EU | UK |
|---|---|---|
| Directly under a provision (points, numbered definitions) | 522 | 16 |
| Inside an unnumbered item (a definition's "means— (a) … (b)") | 18 | 666 |

- Direct items: 538 in 60 provisions of 17 laws (CLP 201, REACH 135, Directive 2013/35 59, Directive 92/57 33, …).
- Level they would take (all items): sub 388, paragraph 656, sub_paragraph 174, none left (below P4) 4.
- Parent rows whose text would change if items became rows: 156 (60 for direct items only).

## #184: the rule (agreed with Jason 2026-10-23)

- A numbered `ListItem` (NumberOverride, or an OrderedList with a Type) directly under a provision is a row: every item between it and the provision is a numbered item row too, and a level is free below the provision (P1 three, P4 none).
- **Aligned with legislation.gov.uk's addresses** (Jason: "Are we aligning our LAT rows with those with an XML id address the feed uses?"): the feed names these items by the id they would have (32 feed refs in REACH and CLP today, e.g. `article-3-10`, `article-2-10`, `article-1-5-e-i`; 344 implied ids in the 17 laws). The row is named as that id converts (`Ref.from_clml("article-57-a")` = `art.Article 57(a)`, tested); `source_xml_id` stays nil — the CLML has none.
- The parent's text stops where item rows begin (" … "), as at child provisions. An item row's text is its own, without its number (as P rows).
- Stay text: items inside a definition (an unnumbered item: 684 in OH&S, mostly UK interpretation clauses), and items with no level left (4).
- Code: `LatParser.Items` (pure: which items, their numbers), `Walker` (an item row typed as the level it takes), `Text` (gaps at item rows; shares `Items.list_number`). Two LH-03 rendering tests updated to the rule, keeping number rendering covered inside a definition. Full suite 3,131 passed.

## #183: decisions and the pattern-2 check (2026-10-23)

- Pattern 1 (an id contradicting its nesting): **diagnose only** (Jason agreed). Our names come from nesting and printed numbers, so they are already right; the reader's tie-break handles the wrong id.
- Pattern 2 (a level skipped): checked the loose P3/P4s in HSWA 1974, Factories Act 1937 and NISR 1997/455 against a sequence rule — does the loose number continue the last item of the sibling just before it?
  - **Continues: only HSWA s.28(f)**, in its 3 versions ((3)'s last is (e)). Its feed ref is `section-28-3-f-i`.
  - Does not continue: the other 31 (HSWA s.11(4)(i)–(ii), s.50(a)–(c); Factories Act s.39(1), s.101(1), s.151(1) (i)–(xiii); NISR 1997/455 reg.3(1)(i)–(ii)). Their own ids agree with where they sit (`section-11-4-i` → s.11(4)(i)), so legislation.gov.uk addresses them as we name them: legitimate structures, not faults.

## #183: built (2026-10-23)

- Rule agreed with Jason: pattern 1 diagnosed only; pattern 2 diagnosed, and a loose P3/P4 whose number continues the last item of the sibling just before it is adopted into that sibling. Nothing else moves.
- **Why the CLML closes the subsection early** (Jason, from the printed law): WSI 2025/1321 reg.39(2) has an unnumbered closing line ("or, where regulation 12(3) applies, …") between (d) and (e); the CLML ends the P2 there, leaving (e)–(g) loose. In print they are (2)'s. Parsing the stored law in memory: `reg.39(2)(e)`–`(g)`, (f)(i)–(ii) under it, the closing line in (2)'s text; reg.44 and reg.46 the same shape. HSWA s.28's feed addresses `section-28-3-f` / `-f-i`, never the id `section-28-f`.
- **Supersedes** the 2026-09-26 decision (LAT sync manifest session: "legal's ids mirror the official ones regulation-39-e … no id churn"): the law text is primary, and the feed follows it. The 2026-09-27 sort-break report lists 63 such items in 43 laws; the re-parse dry run counts which the rule adopts.
- Code: `LatParser.Structure` (pure: `faults/1`, `adoptions/1`); `Walker` applies adoptions; `Diagnostics.structure_faults/1`; `mix lat.audit --structure` reports them from the stored CLML. The LH sort-key test for reg.39 now expects `reg.39(2)(e)`. Full suite green bar that test before its update.

## Re-parse dry run (2026-10-23)

`mix lat.text_diff --all --store only` (offline, 1,066 laws, nothing written; report in the session scratchpad). **4,613 rows changed in 128 laws** (18 of them OH&S). Every removed row pairs with a renamed row: none lost.

| Cause | Rows | Laws |
|---|---|---|
| #184 new item rows | 2,091 | 81 |
| #184 parent text shortened (items moved to their rows) | 256 | 76 |
| #182/#185/label-word renames | 722 | 30 |
| #183 adoptions (a level added: `s.28(c)` → `s.28(1)(c)`) | 128 | — |
| Positional ids shifted by inserted rows (`signed.45` → `signed.51`, one `note.`, one `table.`) | 46 | — |
| Territory / text drift, not these fixes | 472 | 4 |

- The drift: `UK_ukpga_1967_10` (443 rows `excluded_extent` nil → S), `UK_uksi_2010_2215`, `UK_uksi_2010_404`: their feeds were refetched on 2026-10-21 (CV-S01) after their last parse (2026-10-19). `UK_ukpga_1990_8` (9 rows): feed unchanged; it has 3 lowercase "other" qualifications, read since CV-S02 NEW-D. Real source changes the re-parse should carry.
- Positional ids: signature, note and table rows are named by position, so inserted item rows renumber them. Churn for fractalaw, not a fault of these fixes.
- Territory checks: 25 findings (23 child_live_where_parent_excluded, 2 markup_effect_conflict); the checks run on every parsed law, so not attributable to these fixes without a baseline.
