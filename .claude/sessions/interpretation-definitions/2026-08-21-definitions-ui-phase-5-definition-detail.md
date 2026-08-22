---
session: Definitions UI Phase 5 — Definition Detail
status: pending
opened: 2026-08-21
---

# Session: Definitions UI Phase 5 — Definition Detail (PENDING)

## Problem

Need a detail view showing the full cross-reference chain for a single definition: child definition → extracted citation → parent law → root definition. This is the key insight view — understanding *why* a definition is linked or unlinked.

## Todo

- ⬜ Create slide-over or bottom panel component for definition detail
- ⬜ Show: term, full definition text, section_id, scope, citation flag, source
- ⬜ If cross-ref with citation: show extracted citation text, resolved target law name + title
- ⬜ If linked: show root definition(s) with their text, law name, section
- ⬜ If unlinked: show diagnostic category + detail (nearest_term for normalisation issues)
- ⬜ Visual chain diagram: child → citation → parent → root
- ⬜ Link to parent law in LRT browser
- ⬜ Link to legislation.gov.uk source

## Dependencies

- ⬜ Phase 4 — Law Browser (detail opens from definition row click)
- ⬜ Phase 2 — ElectricSQL Shape (definition_links for root lookups)
- ⬜ Phase 1 — Backend API (diagnostic detail per definition)
