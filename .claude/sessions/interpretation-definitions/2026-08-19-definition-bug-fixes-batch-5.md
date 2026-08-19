---
session: Definition Bug Fixes Batch 5
status: pending
opened: 2026-08-19
---

# Session: Definition Bug Fixes Batch 5 (PENDING)

## Problem

Citation edge cases — small CitationExtractor fixes for mangled EU citations, aggressive preamble stripping, consolidated act mismatches, and unresolvable abbreviations. Total: ~15 affected definitions.

## Todo

- ⬜ Fix mangled EU citation — extractor captures article ref as law title (9 affected)
- ⬜ Fix extract_named_law preamble strip too aggressive — loses leading words (2 affected)
- ⬜ Fix consolidated Act mismatch — pre-consolidation citations don't resolve (2 affected)
- ⬜ Fix FRS and common abbreviations not in title_index (2 affected)
- ⬜ Run tests
- ⬜ Re-run diagnostic

## Dependencies

- ⬜ Definition Bug Fixes Batch 4 (2026-08-19)
