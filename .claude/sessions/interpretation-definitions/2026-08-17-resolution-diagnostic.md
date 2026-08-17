---
session: Resolution Diagnostic
status: active
opened: 2026-08-17
---

# Session: Resolution Diagnostic (ACTIVE)

## Problem

5,766 cross-reference definitions can't be linked to their root definitions. Ad-hoc investigation (HSWA deep-dive) revealed multiple failure categories — term normalisation mismatches, citation disambiguation bugs, unparsed parent laws — but we don't know the proportions. Without a systematic diagnostic, we can't tell whether we're fixing the 5% or the 80%. We need a diagnostic module that classifies every failure, generates actionable metrics, and is suitable for a future admin dashboard.

## Todo

- ⬜ Design diagnostic categories and output struct
- ⬜ Build `RootResolver.Diagnostic` module — classifies all unlinked cross-refs
- ⬜ Run diagnostic, capture baseline category breakdown
- ⬜ Fix systemic patterns revealed by the diagnostic (prioritised by category size)
- ⬜ Add mix task or Phoenix endpoint for running the diagnostic
- ⬜ Re-run diagnostic after fixes to measure improvement

## Dependencies

- ✅ Root Resolver Architecture — 6-module decomposition (2026-08-17)
- ✅ Definition Data QA — re-parse + re-resolve complete, 1,995 links (2026-08-17)
- ✅ Definition Parser Architecture — 6 modules, section_id bug fixed (2026-08-17)
