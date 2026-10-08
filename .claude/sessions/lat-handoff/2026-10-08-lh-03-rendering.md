---
session: "LH-03: LAT Rendering"
status: closed
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
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
