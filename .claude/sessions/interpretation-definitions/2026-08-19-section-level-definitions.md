---
session: Section-Level Definition Extraction
status: pending
opened: 2026-08-19
---

# Session: Section-Level Definition Extraction (PENDING)

## Problem

72 OH&S term_not_found failures reference terms defined in specific sections of parent Acts (e.g. "health and safety executive" defined in HSWA section 10, not the interpretation section 53). The parser only extracts definitions from interpretation sections and `<UnorderedList Class="Definition">` elements. Section-level definitions like "the Executive established under section 10" are substantive provisions, not traditional interpretation entries, and require a different extraction approach.

This is the structural ceiling for definition resolution — without it, OH&S maxes out at ~69%. With it, 93.9% is achievable.

## Todo

- ⬜ Quantify: how many section-level definitions exist corpus-wide (not just OH&S)?
- ⬜ Categorise: are these "X is established under section Y" definitions extractable from XML?
- ⬜ Evaluate approaches: (a) new parser strategy for section-level defs, (b) child-driven extraction (use child's citation to find parent section, extract from there), (c) accept as resolution ceiling
- ⬜ Plan chosen approach with Gemini review
- ⬜ Implement and test
- ⬜ Reparse and verify

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the gap
- ⬜ Stale Citation Cleanup (2026-08-19) — clean data baseline first
- ⬜ HSWA Blob Parser Fix (2026-08-19) — HSWA blob fix interacts with section-level parsing
- ⬜ Diagnostic & Internal Ref Accuracy (2026-08-19) — accurate metrics needed to measure impact
