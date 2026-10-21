---
session: "AR-13: Repeals-Table Cells with Several Entries"
status: closed
opened: '2026-10-20'
closed: '2026-10-21'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md

summary: >
  A repeals-table cell was read as one line, so only its first entry became a rule: AmendingLaw.Doc.lines matched only bare
  Para/Text (EReA 1999 Sch 9 uses <leg:Para>), and some sources run entries together with no markup. Both are fixed, plus the
  sibling words line ("In section 117(2) and (3), the words") the split exposed. A no-write pilot of 41 amending laws, net of a
  control, changes only repeals-table rules (+243 / -22 in 22 laws); every removed rule was a glued misreading.

decisions:
  - what: Fix the line splitter at the source (Doc.lines by local name), not by splitting glued text only
    why: 26 of the 29 glued stored repeals-table rules came from documents with prefixed elements; the markup already separates the entries
    result: EReA 1999 on ERA 1996 goes from 6 table rules to ~60
  - what: Also split a cell line at a full stop before Section(s)/Schedule(s) N or In Schedule, outside quoted words
    why: 3 stored rules (1991 c.60, 1992 c.15, 1992 c.42, 1993 c.11) are glued in the source text itself, with no markup between entries
    result: each entry its own rule; a full stop inside quoted words never splits (test)
  - what: The rules reach labels through the AR measure run, not a pilot write
    why: batch changes into one corpus run (Jason); the full lat.amending --read rewrites amendment_rules
    result: batching item deferred to the measure run

metrics:
  glued_stored_rules: { repeal_table: 29, from_prefixed_docs: 26, glued_in_source: 3, instruction: 4 }
  prefixed_clml_files: 72
  pilot_41_laws_net_of_control: { lines: 265, added: 243, removed: 22, amending_laws: 22, instruction_changes: 0 }
  pilot_top_gains: { ukpga_1994_39: 68, ukpga_1999_26: 56, ukpga_2003_37: 24, ukpga_1991_22: 20, ukpga_2004_20: 19, ukpga_1993_43: 17 }
  suite: { passed: 2928, skipped: 2 }

lessons:
  - title: xmerl with namespace_conformant false keeps the prefix in element names — match local names
    detail: 'A document that declares xmlns:leg and writes <leg:Para> gives the atom :"leg:Para"; a guard on :Para silently misses it and every paragraph joins into one line. 72 stored CLML files do this.'
    tag: data
  - title: Diff a re-read against a control on the old code, not against the stored rules
    detail: 'The stored rules were read by an older reader; a fix-vs-stored diff showed instruction changes (EReA s.31(7), s.199) that the control showed were drift since the stored read, not this fix. Net of the control only repeals-table rules moved.'
    tag: tooling
  - title: Splitting glued text exposes the next reader fault behind it
    detail: '"In section 117(2) and (3), the words …" was hidden inside a glued cell; once split it read as a provision (2)(3). Inspect the new rules a fix produces, not only the count.'
    tag: data
  - title: Do not edit code while a background pilot is running against it
    detail: 'mix run recompiles per process, so a loop that spans an edit mixes two code versions; stop it, compile, and restart (fix then stash-control in one script).'
    tag: tooling

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
  - pattern: 'A repeals-table cell listing several entries ("In section 117, …. Section 118(2) and (3). Section 120(2). … Section 125. …") is read as its first entry only'
    category: reader repeal table
    module: Amendment.Reader.repeal_table
    affected: '29 stored glued repeals-table rules; pilot +243 / -22 rules in 22 amending laws'
    fix: Doc.lines by local name; split glued source entries; sibling words line (bdc6af07)
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/doc.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/test/sertantai_legal/scraper/amending_law/doc_test.exs
  - backend/test/sertantai_legal/scraper/amendment/reader_test.exs
  - backend/data/reports/lat-refactor/ar13_fix.csv
  - backend/data/reports/lat-refactor/ar13_ctl.csv
  - backend/data/reports/lat-refactor/ar13_net.csv

depends_on:
  - 2026-10-19-ar-05-amending-schedule-blocks
  - 2026-10-20-ar-04-switch-over

enables:
  - AR measure run (full lat.amending --read rewrites the repeals-table rules)
---

# Session: AR-13: Repeals-Table Cells with Several Entries (CLOSED)

## Problem

A repeals-table cell listing several entries ("In section 117, …. Section 118(2) and (3). Section 120(2). … Section 125. …") is read as its first entry only — EReA 1999 Sch 9 on ERA 1996: 5 cells, ~40 entries → 5 rules (AR-05 trace, open bug; `Amendment.Reader.repeal_table`).

## Todo

- ✅ Count: 29 stored repeals-table rules have glued text; 26 from documents with prefixed elements, 3 glued in the source (§1)
- ✅ Prefixed elements: `Doc.lines` by local name (doc test first)
- ✅ Glued source text: split a cell line into its entries, one rule each (reader test first)
- ✅ Siblings in a words line ("In section 117(2) and (3), the words"): words in each (found by the split; reader test first)
- ✅ Pilot: no-write re-read of 41 amending laws vs a control (§2); code `bdc6af07`
- ⏸️ Batch into the AR measure run (deferred — to the AR-00 measure run: its full `lat.amending --read` rewrites the stored rules)

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
