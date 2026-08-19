---
session: Definition Bug Fixes Batch 3
status: pending
opened: 2026-08-19
---

# Session: Definition Bug Fixes Batch 3 (PENDING)

## Problem

Remaining title normalisation bugs in the CitationExtractor pipeline. Small fixes where citation text doesn't match the title_index due to naming conventions. Total: ~25 affected definitions.

## Todo

- ⬜ Fix HSWA cited without 'etc.' — title_index has 'Health and Safety at Work etc. Act 1974' (19 affected)
- ⬜ Fix Scottish '(asp N)' suffix polluting title lookup key (6 affected)
- ⬜ Run tests
- ⬜ Re-run diagnostic

## Dependencies

- ✅ Definition Bug Fixes Batch 2 (2026-08-19) — (NI) fix pulled into batch 2
