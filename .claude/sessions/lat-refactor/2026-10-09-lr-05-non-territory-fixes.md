---
session: 'LR-05: Non-territory QA3 Fixes'
status: pending
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-05 Non-territory QA3 Fixes (PENDING)

## Problem

QA3 pattern 2 (#174 trailing content when the open child has sub-provisions), 5 (changed_by from Citation URI: wsi vs uksi), 6 (EU "by Regulation (EC) No N/YYYY"), minors ("..»", U+200D, edge spaces, P3 numbers in table cells, "PART 2B - WALES").

## Todo

- ⬜ Build out when started (see meta)
- ⬜ From LR-03 checks: two composition edges — 1990/43 s.153(1)(z7)(ii) (markup-only, child live NI where parent excluded); uksi 2011/988 reg.13 (parent with no own text takes its exclusion from the subtree, child reg.13(1) live E)
- ⬜ uksi 1979/791: 58 DB rows not produced by the parse (`removed`, every diff since LR-02) — find why
- ⬜ Open LH-06 bug (territory edge cases), rechecked at LR-03 close: 2004/20 s.10(2)(b) nested repeal in a pair is now bracketed; still open — uksi 2010/2214 reg.2(6) versions: #n ids on (c)/(d) rows, and wholly W- or E-inserted definition rows (`[W: …]` on an E+W row) with no excluded_extent (check whether these are substitutions, which only bracket)

## Dependencies

- ⬜ See meta session table
