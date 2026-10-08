---
session: "LH-03: LAT Rendering"
status: pending
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
---

# Session: LH-03 LAT Rendering (PENDING)

## Problem

QA run 1 rendering defects: whole-row territorial text is bracketed instead of using `excluded_extent` when the row has child provisions (1989/14 s.3(5), 1992/51 s.12(1ZA)(a)); complex tables lose cells (2003/20 table.1032) and a definitions table reads "[Repealed]" (1991/22 table.1059); «…» quotes drop Schedule/Part numbers (`Number`), list letters, tables and a trailing AppendText. Minor: "[elsewhere: …]", brackets equal to the row's whole extent, doubled commas in signatures.

## Todo

- ⬜ `excluded_extent` from the row's own text (subtree only when it has none); no bracket when the territory covers / misses the row's extent
- ⬜ Tables: cell markup variants; why table.1059 reads [Repealed]
- ⬜ «…»: `Number`, list numbering, tables, AppendText after the block
- ⬜ Signatures: no doubled punctuation
- ⬜ Offline measure; feeds LH-04

## Dependencies

- ✅ LAT = parser output (Coverage II wave 1)
