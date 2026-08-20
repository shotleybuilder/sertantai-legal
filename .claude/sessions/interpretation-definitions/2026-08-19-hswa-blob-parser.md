---
session: HSWA Blob Parser Fix
status: pending
opened: 2026-08-19
---

# Session: HSWA Blob Parser Fix (PENDING)

## Problem

HSWA 1974 section 53 (interpretation) is parsed as a single giant blob per definition — the "employee" entry is 4,833 chars containing the ENTIRE interpretation section from that term to the end. The parser correctly extracts each `<Term>` element but includes all subsequent text up to the section boundary. This causes: (a) 27 HSWA definitions flagged as cross-refs when they're substantive definitions, (b) citation extractor picks up wrong law references from other definitions embedded in the blob, (c) Offshore Installations Regs 1996 (UK_uksi_1996_913) has the same issue.

The root cause is that HSWA's interpretation section uses inline `;`-separated definitions without `<UnorderedList Class="Definition">` XML structure, so Strategy S1 doesn't match and S2/S3 grab the full text.

## Todo

- ⬜ Examine XML structure of HSWA section 53 on legislation.gov.uk
- ⬜ Examine XML structure of UK_uksi_1996_913 regulation 2
- ⬜ Plan parser enhancement (new strategy or S3 improvement for `;`-separated terms)
- ⬜ Implement and test
- ⬜ Reparse affected laws
- ⬜ Re-run resolver and diagnostic

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the bug
- ⬜ Stale Citation Cleanup (2026-08-19) — should be done first so reparsed defs start clean
