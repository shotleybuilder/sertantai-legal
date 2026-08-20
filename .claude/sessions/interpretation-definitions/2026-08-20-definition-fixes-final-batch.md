---
session: Definition Fixes Final Batch
status: active
opened: 2026-08-20
---

# Session: Definition Fixes Final Batch (ACTIVE)

## Problem

Fixing all 8 remaining open bugs (6 unique patterns) affecting 178 definitions across DefinitionParser, CitationExtractor, and Indexes. TDD approach — write failing tests first, then implement fixes.

## Bugs to Fix

- ✅ FRS abbreviation (2 affected) — expand abbreviations in extracted named law titles
- ✅ International conventions (12 affected) — new :international_convention diagnostic category
- ✅ Concatenated terms (72 affected) — code fix already in place (session #151), needs reparse only
- ✅ Continental Shelf Act 1964 (14 affected) — S3 "includes" verb + untagged defs overlap with section-level
- ✅ Section-level definitions — S3 "includes" verb fix done; broader untagged-term parsing deferred
- ⏸️ Consolidated Act mismatch (2 affected) — deferred, parent_revoked ceiling, not worth successor mapping for 2 items

## Todo

- ✅ Write failing tests for each bug (RED)
- ✅ Implement fixes (GREEN) — 841 scraper tests, 0 failures
- ⬜ Re-parse affected laws
- ⬜ Re-resolve with force
- ⬜ Re-run diagnostic to verify improvement
- ⬜ Log fixed bugs in frontmatter

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified most bugs
- ✅ Food & Gas Definition Investigation (2026-08-20) — identified EU regulation bugs (now fixed)
- ✅ Food & Gas Citation Fixes (2026-08-20) — fixed EU reg, plural internal ref, pronoun ref bugs
