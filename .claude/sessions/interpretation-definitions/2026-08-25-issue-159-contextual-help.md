---
session: "Contextual Help & Glossary (#159)"
status: pending
opened: 2026-08-25
github_issue: 159
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
---

# Session: Contextual Help & Glossary (#159) (PENDING)

## Problem

The three definitions admin pages use domain terms (Effective, Resolved, Cross-reference, Citation, Substantive, Actionable, Ceiling, etc.) without any in-context explanation. New users or returning users have no way to know what these mean without reading source code.

## Todo

- ⬜ Create glossary module (`DefinitionGlossary`) or ExDoc section as single source of truth
- ⬜ Add API endpoint `GET /api/definitions/admin/glossary` to serve terms
- ⬜ Design UI integration pattern (tooltip, help panel, or inline popover)
- ⬜ Implement consistent help across all three pages (dashboard, browse, diagnostic)
- ⬜ Document terms: Substantive, Cross-reference, Citation, Linked, Root, Effective, Resolved, Actionable, Ceiling, Scope
- ⬜ Ensure adding new terms doesn't require frontend changes

## Dependencies

- ✅ All three definitions admin pages built
- ✅ ExDoc documentation exists on parser/resolver modules
