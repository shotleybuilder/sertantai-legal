---
session: Section-Level Definition Extraction
status: closed
opened: 2026-08-19
closed: 2026-08-20
outcome: deferred

summary: >
  Superseded by #153 session. The 93.9% ceiling estimate was wrong — the real blocker
  was citation misclassification (law-name definitions with citation=false), not section-level
  parsing. OH&S now at 98.4% without section-level extraction. Remaining term_not_found
  is a future enhancement, not a blocker.
---

# Session: Section-Level Definition Extraction (CLOSED)

## Problem

72 OH&S term_not_found failures reference terms defined in specific sections of parent Acts (e.g. "health and safety executive" defined in HSWA section 10, not the interpretation section 53). The parser only extracts definitions from interpretation sections and `<UnorderedList Class="Definition">` elements. Section-level definitions like "the Executive established under section 10" are substantive provisions, not traditional interpretation entries, and require a different extraction approach.

This is the structural ceiling for definition resolution — without it, OH&S maxes out at ~69%. With it, 93.9% is achievable.

## Todo

- ⏸️ Quantify (deferred — superseded by #153 which found 1,235 corpus-wide)
- ⏸️ Categorise (deferred — #153 revealed citation misclassification was the real blocker)
- ⏸️ Evaluate approaches (deferred — all families now >90% without section-level parsing)
- ❌ Plan, implement, verify (abandoned — not needed for 90% target)

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the gap
- ⬜ Stale Citation Cleanup (2026-08-19) — clean data baseline first
- ⬜ HSWA Blob Parser Fix (2026-08-19) — HSWA blob fix interacts with section-level parsing
- ⬜ Diagnostic & Internal Ref Accuracy (2026-08-19) — accurate metrics needed to measure impact
