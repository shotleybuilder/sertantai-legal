---
session: "AR-13: Repeals-Table Cells with Several Entries"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'AmendingLaw.Doc.lines matches only bare Para/Text/br: a document with prefixed elements (<leg:Para>, EReA 1999 Sch 9) runs every entry of a cell into one line'
    category: reader lines
    module: AmendingLaw.Doc
    affected: '72 stored CLML files with prefixed Para/Text; 26 glued repeals-table rules'
    fix: match the element's local name (fixed, doc_test)
    status: fixed
  - pattern: 'Repeals-table entries run together in the source text ("Sections 75 to 84.Section 103.In section 109(3)…", 1993 c.11 Sch 6) read as the first entry only'
    category: reader repeal table
    module: Amendment.Reader.repeal_table
    affected: '3 stored repeals-table rules outside the prefixed laws (1991 c.60, 1992 c.15, 1992 c.42, 1993 c.11)'
    fix: split a cell line at a full stop before Section(s)/Schedule(s) N / In Schedule, outside quoted words (fixed, reader_test)
    status: fixed
  - pattern: 'A repeals-table words line naming sibling subsections ("In section 117(2) and (3), the words …") read as words in (2) plus a provision (2)(3)'
    category: reader repeal table
    module: Amendment.Reader.line_targets
    affected: 'exposed by the split (EReA 1999 Sch 9 on ERA s.117)'
    fix: siblings after the section's brackets are each a place for the words (fixed, reader_test)
    status: fixed
---

# Session: AR-13: Repeals-Table Cells with Several Entries (ACTIVE)

## Problem

A repeals-table cell listing several entries ("In section 117, …. Section 118(2) and (3). Section 120(2). … Section 125. …") is read as its first entry only — EReA 1999 Sch 9 on ERA 1996: 5 cells, ~40 entries → 5 rules (AR-05 trace, open bug; `Amendment.Reader.repeal_table`).

## Todo

- ✅ Count: 29 stored repeals-table rules have glued text; 26 from documents with prefixed elements, 3 glued in the source (§1)
- ✅ Prefixed elements: `Doc.lines` by local name (doc test first)
- ✅ Glued source text: split a cell line into its entries, one rule each (reader test first)
- ✅ Siblings in a words line ("In section 117(2) and (3), the words"): words in each (found by the split; reader test first)
- ✅ Pilot: no-write re-read of 41 amending laws vs a control (§2); code `bdc6af07`
- ⬜ Batch into the AR measure run (the full `lat.amending --read` rewrites the stored rules)

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)

## 1. Cause and count (2026-10-21)

The bug is real: stored rules from EReA Sch 9 on ERA hold whole cells as one line ("…subsection (5)(b).In section 43, …"), so `line_targets` reads the first entry only. There are two causes:

- **Prefixed elements.** EReA 1999's schedules mark each entry `<leg:Para><leg:Text>`. The amending-law document is parsed with `namespace_conformant: false`, so the element names are `:"leg:Para"`. `Doc.lines` started a new line only for bare `:Para`/`:Text`/`:br`. 72 stored CLML files use the prefix.
- **Glued in the source.** Some tables have no markup between entries ("Sections 75 to 84.Section 103.In section 109(3), …", 1993 c.11 Sch 6; also 1991 c.60, 1992 c.15, 1992 c.42).

Stored rules whose text is glued: 29 repeals-table rules, 26 of them from prefixed documents. A further 4 instruction rules are glued as well; 3 of them are the 1979 c.2 Table instruction, which is not a repeals-table shape.

Fixes: `Doc.lines` matches the local name; `Reader.table_rows` splits a cell line at a full stop followed by "Section(s) N", "Schedule(s) N" or "In Schedule", never inside quoted words.

## 2. Pilot (2026-10-21)

No-write re-read (as `lat.amending --read`, one law per process) of 41 amending laws: those whose stored CLML uses prefixed elements, or which have a stored rule with glued text. Each run is diffed against the stored rules. The control is the same run with the two lib files stashed. Reports: `backend/data/reports/lat-refactor/ar13_{fix,ctl,net}.csv`.

- **Net of the control: 265 rule lines, all repeals-table, in 22 amending laws.** About 243 rules added and 22 removed. The biggest gains are 1994 c.39 (+68), EReA 1999 (+56), 2003 c.37 (+24), 1991 c.22 (+20), 2004 c.20 (+19) and 1993 c.43 (+17).
- **Every removed rule was a misreading of a glued cell:** for example `s.9(7)(1)`, `s.4(1)(b)(1)(c)`, `s.21(9)(1)`, and `s.18(1)|s.18(5)` where the cell says s.18(1) and s.47(5). Each is replaced by its entries read one at a time.
- **Control-only lines (7) are misreadings too** (`s.1(2)(6)`, `s.92(7ZB)(a)(7C)`), and the fix drops them.
- **Instruction rules change in both runs,** so that is drift since the stored read (e.g. the AR-10 reader), not this fix.
- **Not changed:** an entry with a qualifier ("Section 47(5), so far as relating to …") stays a whole-provision repeal, as the reader read it before.

The stored rules are rewritten by the AR measure run's full `lat.amending --read`.
