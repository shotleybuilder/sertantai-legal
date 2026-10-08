---
session: 'LH-03: LAT Rendering'
status: closed
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
closed: '2026-10-08'
outcome: success
summary: Prefixed XHTML tables, numbered lists, «…» numbers/lists/tables/AppendText, excluded_extent from own text, plain text where a territory covers/misses the row, signature commas.
bugs:
- pattern: Whole-row territorial text bracketed instead of excluded_extent when the row has child provisions
  category: LAT territory
  module: SertantaiLegal.Scraper.LatParser (excluded_extent over the subtree)
  affected: QA 3 rows (1989/14 s.3(5), 1992/51 s.12(1ZA)(a))
  fix: decide on the row's own text; subtree only when it has none
  status: fixed
- pattern: Complex tables lose cells; a definitions table reads [Repealed]; tables inside «…» lost
  category: LAT text
  module: SertantaiLegal.Scraper.LatParser (table_text, mark_repealed_provisions, quoted_text)
  affected: QA 3 rows (ukpga 2003/20 table.1032, 1991/22 table.1059, 2017/3 s.173(2))
  fix: investigate cell markup; quoted_text renders tables
  status: fixed
- pattern: «…» quotes drop Number (Schedule/Part), list letters, trailing AppendText
  category: LAT text
  module: SertantaiLegal.Scraper.LatParser (quoted_child)
  affected: QA 3 rows
  fix: render Number, ListItem numbering, AppendText after the block
  status: fixed
---

# Session: LH-03 LAT Rendering (CLOSED)

## Problem

QA run 1 rendering defects: whole-row territorial text is bracketed instead of using `excluded_extent` when the row has child provisions (1989/14 s.3(5), 1992/51 s.12(1ZA)(a)); complex tables lose cells (2003/20 table.1032) and a definitions table reads "[Repealed]" (1991/22 table.1059); «…» quotes drop Schedule/Part numbers (`Number`), list letters, tables and a trailing AppendText. Minor: "[elsewhere: …]", brackets equal to the row's whole extent, doubled commas in signatures.

## Todo

- ✅ `excluded_extent` from the row's own text (subtree only when it has none); no bracket when the territory covers / misses the row's extent
- ✅ Tables: cell markup variants; why table.1059 reads [Repealed]
- ✅ «…»: `Number`, list numbering, tables, AppendText after the block
- ✅ Signatures: no doubled punctuation
- ⏸️ Offline measure → LH-04's combined dry run

## Dependencies

- ✅ LAT = parser output (Coverage II wave 1)

## Work (2026-10-08)

- Tables: both QA table defects were prefixed XHTML (`xhtml:tr`/`xhtml:td`) — XPath `name()` gives `{ns}td`; matched by local name. Cells read as text blocks (paragraphs, lists). The s.106 definitions table was empty → "[Repealed]" by the empty-row-with-notes rule; now has its cells.
- Lists: `ListItem@NumberOverride`, else an OrderedList's Type + Decoration, numbers each item ("(a) …", "(i) …"); lists without either stay unnumbered. Applies in text, table cells and «…». A list after an open child still belongs to the child (#174).
- «…»: `Number` / `Reference` ("Schedule 4A", "Part 1", "Section 25"), lists, tables; `AppendText` joins the quote inside its closing » ("…and”.»").
- Territory: `excluded_extent` from the row's own text (subtree only when it has none); a substitution covering the row's extent shows the new words only, one missing it the old; words repealed only outside the row's extent stay plain.
- Signatures: parts trimmed of trailing commas; "… of the" runs into the department without a comma.
- Tests: 11 new; older list tests updated to numbered items where the source numbers them.
