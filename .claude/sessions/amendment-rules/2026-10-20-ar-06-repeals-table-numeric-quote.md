---
session: "AR-06: Repeals-Table Line Quoting a Number"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'A repeals-table line quoting a number only ("In section 53(1)(a) “114”.") is read as a whole-provision repeal, not words'
    category: amendment reader
    module: Amendment.Reader.repeal_table
    affected: '67 provision-level repeals-table rules in 28 amending laws quoted words; 55 now words'
    fix: 'a quote, definition or entry is words unless a provision is named beside it; "in subsection (1)" is the words'' place (914384d6, and the follow-up)'
    status: fixed
  - pattern: 'Found and fixed in the pilot: words in two places joined into one path (s.30(1)(2)), and a definition beside "and subsection (2)" dropped the subsection''s repeal'
    category: amendment reader
    module: Amendment.Reader.repeal_table
    affected: '1982 c.16 s.30(1)–(2), 1980 c.45 s.109(1)(b)(i)–(ii) went in force → unknown in the first pilot'
    fix: a target per place; the named-provision guard covers definitions and entries
    status: fixed
---

# Session: AR-06: Repeals-Table Line Quoting a Number (ACTIVE)

## Problem

A repeals-table line quoting a number only ("In section 53(1)(a) “114”.", 1991 c.34 Sch 19 on 1982 c.16) is read as a whole-provision repeal, not words (AR-03 open bug; `Amendment.Reader.repeal_table`).

## Todo

- ✅ A repeals-table line whose quote is a number reads as words-level (reader test first)
- ✅ Count the rules it changes (`mix lat.amending --read` on the affected laws); batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)

## Fix and pilot (2026-10-20)

- **Count:** 67 provision-level repeals-table rules in 28 amending laws quote words. Most are "the definition of “x”" or "the entry relating to …", plus quoted words with no "words" ("In section 206(3)(a), “I or”.").
- **Fix (`Reader.line_targets`):**
  - A line is words-level when it says "words", or quotes words or names a definition or entry with no provision named beside it.
  - "In subsection (1)" / "in paragraph (b)" is where the words are, and gives their row; each place is its own target.
  - A line with words beside a provision named ("the definitions of …; and subsection (2)") stays provision-level. That's AR-08's mixed level.
  - Reader tests first; suite 2,899 pass.
- **First pilot (`ar06_pilot`):** 51 label changes, with two regressions I'd introduced:
  - 1982 c.16 s.30(1)–(2): "in subsection (1) … and, in subsection (2)" was read as the path s.30(1)(2).
  - 1980 c.45 s.109: "the definitions …; and subsection (2)" lost the subsection's repeal.
  - Both fixed; tests added.
- **Re-read:** the 28 amending laws. Repeals-table rules there: provision 241 → 186, words 87 → 142.
- **Second pilot (`ar06_pilot2`, 27 laws, no write):** 36 label changes, 0 errors, no losses of AR-06's own (the 8 emptied dates are AR-14's on RTSA 2003).
  - 13 rows gain a date and changed_by (e.g. 1968 c.73 s.137(7)/(8), s.44(1)(b)(ii), s.9(5)[S]; 1988 c.52 s.98(3); 1991 c.57 s.21(3)(e), s.24(1)).
  - 1986 c.31 s.63(8)[S] unknown → in force 1996-04-01.
  - A false whole repeal from a table had blocked their own later changes.
