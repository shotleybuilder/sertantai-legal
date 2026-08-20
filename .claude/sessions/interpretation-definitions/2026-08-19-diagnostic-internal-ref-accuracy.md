---
session: Diagnostic & Internal Ref Accuracy
status: pending
opened: 2026-08-19
---

# Session: Diagnostic & Internal Ref Accuracy (PENDING)

## Problem

The Diagnostic module classifies 53 OH&S internal refs as `:no_citation` because it doesn't check `internal_ref?` before reporting. The `internal_ref?` regex also misses `paragraph (5)` and `subsection (4)` patterns (parenthesized section numbers). Minor citation extraction bugs (semicolons before years, year-prefix SI abbreviations, hyphen normalisation) affect another ~8 definitions. Combined, these code fixes would correct classification for ~65 OH&S definitions and ~1,100 corpus-wide.

## Todo

- ⬜ Add `internal_ref?` check to `Diagnostic.classify` before reporting `:no_citation`
- ⬜ Extend `@internal_ref_re` to allow parenthesized section numbers: `paragraph\s+\(?\d`
- ⬜ Also add "subsection" to the regex alternatives if missing
- ⬜ Strip stray semicolons from definition text in CitationExtractor or normalise_title ("Regulations ;2015")
- ⬜ Add pattern for year-prefix SI abbreviations ("the 2014 Acetylene Regulations")
- ⬜ Normalise hyphens in `normalise_term/1` ("dual-purpose" → "dual purpose")
- ⬜ Add tests for each fix
- ⬜ Run diagnostic and verify impact

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the bugs
