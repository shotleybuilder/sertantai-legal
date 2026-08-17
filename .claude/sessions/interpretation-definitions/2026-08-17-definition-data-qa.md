---
session: Definition Data QA
status: suspended
opened: 2026-08-17
---

# Session: Definition Data QA (SUSPENDED)

## Problem

The definition parser and resolver have been refactored (parser: 766→6 modules, resolver: 541→6 modules, both Gemini Grade A). The refactored parser fixes the section_id fingerprint bug and has cleaner text extraction. Time to re-parse affected laws and clean up outstanding data quality issues inherited from the pre-refactor era: 1,541 empty-definition records across 133 laws, 28,754 null-scope definitions (42%), 3 UTF-8 encoding errors, and a string table name in definition_persister.

## Todo

- ✅ Fix string table name in `definition_persister.ex` (`"legislative_definitions"` → `LegislativeDefinition`)
- ✅ Fix UUID format in persister (`Ecto.UUID.dump!` → `Ecto.UUID.generate` — Ash resource requires string UUIDs, not pre-dumped binary)
- ✅ Re-parse 658 targeted laws in 7 batches of 100 (5 test + 653 bulk, 6 fetch errors, 4 no-defs, +11,380 defs, empties 1,541→565)
- ✅ Re-run resolver after re-parse — links 942→1,695 (+80%), citations extracted: 6,663, 745 missing parents identified
- ✅ Fix NaiveDateTime → DateTime in resolver persister (Ash UtcDatetimeUsec type mismatch)
- ⬜ Investigate 1,541 empty-definition records across 133 laws — categorise: parser bug vs genuinely empty in source XML
- ⬜ Fix 3 UTF-8 encoding errors in persister (truncated multi-byte sequences)
- ⬜ Run CSV scope backfill (`mix definitions.backfill --scope csv`) — 28,754 null-scope defs (42%)
- ⬜ Update ElectricSQL shape to include definition_links junction table
- ✅ Update NAS snapshot (previous archived, 79,381 defs backed up)
- ⬜ Evaluate: migrate mix tasks to Phoenix LiveDashboard / admin routes

## Dependencies

- ✅ Definition Parser Architecture — 6-module decomposition, section_id bug fixed (2026-08-17)
- ✅ Root Resolver Architecture — 6-module decomposition, Gemini Grade A (2026-08-17)
- ✅ Definition Backfill & QA — bulk parsing done, junction table in place (suspended 2026-08-13)

## Current Data State

| Metric | Value |
|--------|-------|
| Total definitions | 68,001 → 79,381 |
| Empty definitions (non-citation) | 1,541 → 565 (-63%) |
| Null scope | 28,754 → 31,408 |
| Definition links | 942 → 1,995 (+112%) |
| UTF-8 errors | 3 |

## Resume Notes

**Status (2026-08-17)**: Re-parse and re-resolve complete. Persister Ash type bugs fixed (UUID format, NaiveDateTime). normalise_title now strips leading "the" for citation matching. HSWA 1974 re-parsed (1→59 defs). OH&S parent laws parsed (NI Order, MHSWR, App Order). NAS snapshot updated.

**Remaining work**: empty-def investigation, UTF-8 errors, CSV scope backfill, ElectricSQL shape, mix task → admin UI evaluation. The unlinked cross-ref problem (5,766 remaining) needs systematic diagnosis — moved to new session (Resolution Diagnostic).
