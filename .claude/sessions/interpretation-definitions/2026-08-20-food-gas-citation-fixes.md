---
session: Food & Gas Citation Fixes
status: pending
opened: 2026-08-20
---

# Session: Food & Gas Citation Fixes (PENDING)

## Problem

Fixing 3 bugs discovered in FOOD (74 unresolved) and Gas & Electrical (7 unresolved) definition investigation. All are CitationExtractor/Matcher gaps — EU short-form citations, plural paragraph internal refs, and pronoun ref fallback. Combined: 78 definitions affected.

## Bugs to Fix

- ⬜ EU Regulation short-form citations (47 affected) — `Regulation 853/2004`, `Article 3(49) of Regulation 2017/625`, `Annex I to Regulation 853/2004`
- ⬜ Plural paragraph/subsection internal refs (12 affected) — `paragraphs (2) to (4)`, `subsections (3) and (4)`
- ⬜ Pronoun ref fallback to enacted_by (19 affected) — `that Act`, `those Regulations` when sibling_index has no entry

## Todo

- ⬜ Add EU short-form patterns to CitationExtractor
- ⬜ Extend internal_ref? for plural paragraphs/subsections with ranges
- ⬜ Add enacted_by fallback to Matcher.resolve_pronoun_ref
- ⬜ Add tests for each fix
- ⬜ Re-resolve with force (`/definition-resolve force`)
- ⬜ Re-run diagnostic for FOOD and Gas & Electrical (`/definition-diagnose`)
- ⬜ Log fixed bugs in frontmatter

## Dependencies

- ⬜ Food & Gas Safety Definition Investigation (2026-08-20) — identified the bugs
