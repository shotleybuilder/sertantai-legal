---
session: Substantive Section Definition Parsing
status: pending
opened: 2026-08-20
---

# Session: Substantive Section Definition Parsing (PENDING)

## Problem

UK Acts define many terms in substantive sections, not interpretation sections. 1,235 term_not_found corpus-wide have section refs in citations. Food Safety Act 1990 alone has 18 missing terms. This is the single largest remaining gap for definition resolution. See #153.

## Todo

- ⬜ Analyse section XML for top affected parent laws (Food Safety Act, Criminal Justice Act)
- ⬜ Design approach: demand-driven (fetch cited section) vs proactive (scan all sections)
- ⬜ Write failing tests with section-level definition fixtures
- ⬜ Implement section-level definition extraction
- ⬜ Parse affected parent laws
- ⬜ Re-resolve and verify improvement across all families

## Dependencies

- ✅ Definition Fixes Final Batch (2026-08-20) — S3 includes verb fix
- ⬜ EU Regulation Annex Parsing (2026-08-20, #152) — related parser enhancement
