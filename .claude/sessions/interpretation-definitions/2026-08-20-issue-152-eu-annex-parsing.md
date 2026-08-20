---
session: EU Regulation Annex Definition Parsing
status: active
opened: 2026-08-20
---

# Session: EU Regulation Annex Definition Parsing (ACTIVE)

## Problem

EU Regulations define key terms in Annex I (and other annexes), not in main articles. Parser only extracts from body XML, missing annex definitions. Reg 853/2004 has 2 definitions extracted but 22 children need terms like "meat", "poultry", "fresh meat" from Annex I. See #152.

## Todo

- ⬜ Fetch and examine Annex I XML structure for Reg 853/2004
- ⬜ Design parser strategy for annex definitions (new S4 or extension)
- ⬜ Write failing tests with annex XML fixture
- ⬜ Implement annex definition extraction
- ⬜ Parse annexes for affected EU regulations
- ⬜ Re-resolve and verify FOOD family improvement

## Dependencies

- ✅ Food & Gas Citation Fixes (2026-08-20) — EU reg citations now extracted
- ✅ Definition Fixes Final Batch (2026-08-20) — S3 includes verb, other fixes
