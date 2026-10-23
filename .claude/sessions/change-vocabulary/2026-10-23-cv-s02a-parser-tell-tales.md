---
session: CV-S02a Parser tell-tales
status: closed
opened: 2026-10-23
closed: 2026-10-23
outcome: success

summary: >
  The four parser faults the CV-S02 feed check sensed were fixed as general rules: numbers named the same
  whatever form the CLML prints them in (#182, #185, label words), numbered list items directly under a
  provision as rows named as legislation.gov.uk addresses them (#184), and CLML structure faults sensed with
  one repair — a loose item continuing the sibling before it belongs in it (#183). 128 laws re-parsed after a
  corpus dry run; the OH&S feed check kept 0 reader faults with tell-tales 16 → 5 (all genuinely absent), golden 27/27.

decisions:
  - what: One naming rule in LatParser.Ids — Unicode spaces ordinary, brackets round a number dropped, the label word stripped however spaced, a number holding a space after a dash split is a heading numbered by the id
    why: The DB showed the fault wider than #182/#185 (640 Unicode-space rows, 79 bracket rows incl. "1)", 26 label-word rows incl. a heading as a chapter number); one rule, not one per issue
    result: 0 / 0 / 0 such row names after the apply (722 rows renamed in 30 laws)
  - what: A numbered ListItem directly under a provision is a row (next free level), named as legislation.gov.uk's address for it converts; items inside a definition and items with no level left stay text; the parent's text stops where item rows begin; source_xml_id stays nil
    why: Jason asked whether rows align with the ids the feed uses — 32 feed refs in REACH/CLP already address id-less items (article-3-10, article-2-10); the measure split direct items (538) from items inside definitions (684), which have no number to name from
    result: 2,091 item rows in 81 laws; REACH Art. 57(a)–(f), CLP Art. 2's 53 definitions
  - what: "#183 pattern 1 (id contradicts nesting) diagnosed only; pattern 2 (level skipped) diagnosed, and a loose P3/P4 whose number continues the last item of the sibling before it is adopted into it"
    why: Rows are named by nesting, so pattern 1's names are already right; for pattern 2 only HSWA s.28(f) continued a sequence in the 3 laws checked (its feed says section-28-3-f), the other 31 have ids agreeing with where they sit
    result: 128 rows adopted corpus-wide (s.28(3)(f), wsi 2025/1321 reg.39(2)(e)–(g)); Diagnostics.structure_faults/1 and mix lat.audit --structure report them
  - what: Supersede the 2026-09-26 decision that row names mirror the official ids (regulation-39-e)
    why: Jason's screenshot of wsi 2025/1321 — an unnumbered closing line between (d) and (e) makes the CLML close the P2 early; in print (e)–(g) are (2)'s; the law text is primary and HSWA's feed follows it, not the id
    result: The LH sort-key test now expects reg.39(2)(e)
  - what: Force the enrichment gate only for dots-only signature rows (UK_eur_2006_561, UK_eur_2012_649, UK_eur_2016_425); raise position-named rows as #186
    why: Inserted item rows renumber signed./note./table. rows (named by position); text matching can't carry "..." rows; only that row's enrichment is lost
    result: 3 laws forced, the other 125 gate on; #186 pending session
  - what: The feed reader reads EU finer forms down to every row the law holds (Feed.read takes :rows), not only rows with an XML id
    why: After the apply, item rows (no XML id) were still flagged unheld — the reader's held set was the XML-id map's values
    result: Tell-tales 15 → 5, naming 0, no_ids 0
  - what: No message to fractalaw about the renamed rows
    why: Jason — fractalaw isn't running; the renames are in lat_section_id_renames for its next pull
    result: Not sent

metrics:
  dry_run: { laws_diffed: 1066, rows_changed: 4613, laws_changed: 128, item_rows: 2091, parent_text_shortened: 256, naming_renames: 722, adoptions: 128, positional_renumbered: 46, source_drift_rows: 472, source_drift_laws: 4 }
  apply: { laws: 128, rows_before: 116578, rows_after: 118669, enriched_before: 99385, enriched_after: 99377, renamed: 880, orphaned_mappings: 0, forced_laws: 3 }
  ohs_feed_check: { effects: 6568, our_faults: 0, placed: 3549, placed_was: 3483, not_in_text: 128, not_in_text_was: 159, placed_by_markup: 5, placed_by_markup_was: 42, tell_tales: 5, tell_tales_was: 16 }
  golden: { pass: 27, total: 27 }
  ohs_list_items: { numbered_idless: 1222, direct: 538, in_definition: 684, no_level_left: 4, feed_refs_on_item_ids: 32 }
  tests: { full_suite: 3141 }

lessons:
  - title: Measure the fault in the DB before fixing the issue as filed
    detail: "#182 and #185 were filed from two examples; a query over section_ids found the same cause (number taken with its decoration) in label words, a figure space and a heading used as a chapter number — one rule fixed all three instead of three issues."
    tag: data
  - title: legislation.gov.uk's XML ids are not its last word — the printed law and the feed are
    detail: "HSWA s.28(f) has the id section-28-f but the feed addresses section-28-3-f; wsi 2025/1321 reg.39's (e)–(g) carry regulation-39-e etc. because an unnumbered closing line ends the P2 in the CLML. An earlier decision to mirror official ids was overturned on the printed text (Jason's screenshot). Check print and feed before trusting an id."
    tag: data
  - title: A new kind of row needs every consumer's notion of "held rows" checked
    detail: "Item rows have no source_xml_id; the feed reader built its held set from the XML-id map, so after a correct re-parse it still flagged them unheld. Look for code that derives the row set from source_xml_id when adding id-less rows."
    tag: tooling
  - title: Position-named rows turn any row insertion into renames that the enrichment gate catches
    detail: "signed./note./table. citations use position; inserting 2,091 item rows renumbered 46 of them, and dots-only signature text can't be matched to carry enrichment. The gate stopped the run twice — the gate worked; the naming is the weakness (#186)."
    tag: data
  - title: Separate source drift from the change in a corpus dry run
    detail: "472 territory/text row changes in 4 laws came from feeds refetched in CV-S01 after the laws' last parse (and one law's lowercase 'other' qualifications), not from the parser fixes. Compare last-parse time with the stored sources' fetch time before attributing a diff."
    tag: data
  - title: The re-parse tag becomes a table name
    detail: "mix lat.reparse --tag cv-s02a failed before writing (invalid snapshot table name lat_reparse_cv-s02a); use underscores."
    tag: tooling

bugs:
  - pattern: Non-breaking space in EU article section_ids (#182)
    category: LAT parse
    module: LAT parse (lat_parser/ids.ex)
    affected: 640 rows / 16 laws
    fix: Ids.clean — every Unicode space ordinary (84ea7ffb); re-parsed
    status: fixed
  - pattern: Row names with doubled brackets "art.Article 77(2)((e))" (#185)
    category: LAT parse
    module: LAT parse
    affected: 79 rows / 9 laws
    fix: Brackets printed round a number dropped (84ea7ffb); re-parsed
    status: fixed
  - pattern: Part/Chapter names keep their label word (pt.PART15, ch.CHAPTER V) or a heading as the number
    category: LAT parse
    module: LatParser.Ids.number/2
    affected: 26 rows
    fix: Prefix stripped however spaced; a spaced number after a dash split is a heading (84ea7ffb)
    status: fixed
  - pattern: Numbered list items with no id get no row (#184)
    category: LAT parse
    module: LAT parse
    affected: 1,652 ListItems / 114 laws
    fix: LatParser.Items — direct numbered items are rows (1a389d91); 2,091 rows corpus-wide
    status: fixed
  - pattern: legislation.gov.uk CLML structure faults — ids contradicting nesting, levels skipped (#183)
    category: LAT parse
    module: LAT parse
    affected: 27 + 14 elements in the OH&S family
    fix: LatParser.Structure senses both; a loose item continuing the sibling before it is adopted (5275d2b0)
    status: fixed
  - pattern: Feed reader's held set only rows with an XML id — id-less item rows flagged finer_unheld
    category: change vocabulary
    module: ChangeVocabulary.Readers.Feed
    affected: 10 tell-tales in OH&S
    fix: Feed.read takes the law's rows (19196e8d)
    status: fixed
  - pattern: Position-named rows (signed., table., note.) renumbered by inserted rows lose enrichment (#186)
    category: LAT parse
    module: LatParser.Rows / LatReparse carry
    affected: 46 rows renumbered; 3 laws forced
    fix: Stable names or carry by kind and order (pending session 2026-10-23-issue-186.md)
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/lat_parser/ids.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/items.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/structure.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/walker.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/text.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/diagnostics.ex
  - backend/lib/mix/tasks/lat.audit.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary.ex
  - backend/lib/mix/tasks/lat.feed_check.ex
  - backend/test/sertantai_legal/scraper/lat_parser/ids_test.exs
  - backend/test/sertantai_legal/scraper/lat_parser/items_test.exs
  - backend/test/sertantai_legal/scraper/lat_parser/structure_test.exs
  - backend/test/sertantai_legal/scraper/lat_parser_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/feed_targets_test.exs
  - backend/data/reports/lat-reparse/cv_s02a.csv (+ _force, _rest, _force2, _rest3)
  - NAS snapshots/restore-points/2026-10-23-cv-s02a-reparse
  - .claude/sessions/2026-10-23-issue-186.md

depends_on:
  - 2026-10-22-cv-s02-feed-reader

enables:
  - CV-S02b feed pattern catalogue
  - CV-S03 markup reader
  - "#186 position-named rows"
---

# Session: CV-S02a Parser tell-tales (CLOSED)

## Problem

The CV-S02 feed-reader check senses markup faults the LAT parse passes on faithfully. Jason (2026-10-23): they are raised against the parser, fixed in this sub-session straight after CV-S02, as general patterns, never as one-law fixes. Then back to the workflow (CV-S03).

## Todo

- ✅ What good looks like, agreed with Jason (2026-10-23)
- ✅ #182 (code, `84ea7ffb`; re-parse pending): a non-breaking space in EU section_ids (639 rows, 15 laws); the spelling is unstable within a law. Name from the number, normalised.
- ✅ #183 (code, `5275d2b0`; re-parse pending): CLML structure faults sensed as diagnostics (ids that contradict their nesting: 27 elements in 4 laws; levels skipped: 14 in 3 laws); decide one general repair rule, if any.
- ✅ #184 (code, `1a389d91`; re-parse pending): numbered items with no id get no row (1,652 ListItems in 114 laws; CLP Art. 2's definitions, REACH Art. 57 points)
- ✅ #185 (code, `84ea7ffb`; re-parse pending): row names with doubled brackets, `art.Article 77(2)((e))` (79 rows in 9 laws)
- ✅ Note: `ParserVersion` already moved with CV-S02 NEW-D (`ChangesFeed` reads lowercase "other"); the re-parse plan covers it
- ⏸️ The shared namer (`Commencement.Order.ref/1`) drops nested schedule ids: `schedule-N-part-P-paragraph-M` → `sch.N.pt.P`; unnumbered `schedule-paragraph-1` → `sch.paragraph`. 48 collisions in the family's feeds, none in the body (CV-S02 NEW-C). Deferred until schedules are parsed (no schedule rows in v0.1); fix it with the schedule naming decision
- ✅ Re-parse of the affected laws only (128): dry run → Jason → restore point → apply (2026-10-23)
- ❌ Tell fractalaw of the renamed rows — not sent: fractalaw isn't running (Jason 2026-10-23); the renames are in `lat_section_id_renames` for its next pull

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

## Apply (2026-10-23)

- Restore point: `snapshots/restore-points/2026-10-23-cv-s02a-reparse` (legal_register_uk, legal_articles_uk, amendment_annotations, lat_change_log, lat_label_timeline, lat_events, lat_changes, lat_section_id_renames, control_mappings).
- `mix lat.reparse --laws <the dry run's 128> --store only`, reports `data/reports/lat-reparse/cv_s02a*.csv`.
- The enrichment gate stopped on signature rows renumbered by the new item rows whose text is only dots (no text match to carry by): `UK_eur_2006_561` `signed.114`, `UK_eur_2012_649` `signed.181`, and `UK_eur_2016_425` `signed.264` ahead of its turn. Forced with Jason's agreement (only those rows' enrichment lost); the rest ran gate on. Raised as **#186** (position-named rows), pending session `2026-10-23-issue-186.md`.
- Apply complete: **128 laws** re-parsed (`cv_s02a`, `_force`, `_rest`, `_force2`, `_rest3` reports). Rows 116,578 → 118,669 (+2,091, the dry run's item rows exactly); enriched 99,385 → 99,377 (8 lost: 3 dots-only signature rows, the rest parents whose text changed); renamed 880; orphaned control mappings 0.

## Results after the apply (2026-10-23)

- DB measures: Unicode spaces in section_ids 0 (was 640), doubled/extra brackets 0 (79), label words 0 (26). HSWA `s.28(3)(f)`(i)(ii) in all 3 versions; WSI 2025/1321 `reg.39(2)(e)`–`(g)`; REACH Art. 57(a)–(f); CLP Art. 2 53 rows under it.
- The feed reader saw only rows with an XML id (its held set was the XML-id map), so item rows were flagged unheld. Fixed: `Feed.read` takes every row of the law (`19196e8d`, test added).
- OH&S feed check: our faults 0; placed 3,483 → 3,549, not in text 159 → 128, placed by markup 42 → 5; **tell-tales 16 → 5**, all `not_found` and genuinely absent from today's text (REACH Art. 77(3) and CLP Art. 54 repealed ("…"), REACH 14(2) holds only (a)–(b), REACH 76(1) no row). naming 0, no_ids 0.
- Golden 27/27.
