---
session: Definition API
status: pending
opened: 2026-08-13
---

# Session: Definition API (PENDING)

## Problem

Compliance (and other services) need to query definitions by term and/or law. This session adds REST API endpoints, Zenoh queryable for fractalaw, and includes definitions in the delta sync pipeline so compliance can access them.

## Todo

- ⬜ Create `DefinitionController` with endpoints:
  - `GET /api/definitions?term=workplace` — all definitions of a term across laws
  - `GET /api/definitions?law=UK_uksi_1999_3242` — all definitions in a law
  - `GET /api/definitions?term=workplace&law=UK_uksi_1999_3242` — specific lookup
- ⬜ Add routes to `router.ex`
- ⬜ JSON serialisation (term, term_display, definition, scope, law_name, section_id, references_other_law)
- ⬜ Add Zenoh queryable: `fractalaw/@{tenant}/data/legislation/definitions/{law_name}`
- ⬜ Include `legislative_definitions` in delta sync export/import (`mix data.export_delta` / `mix data.apply_delta`)
- ⬜ Controller tests with Req.Test stubs (no live DB needed for endpoint tests)
- ⬜ Verify delta sync round-trip: export → import → query returns same data

## Dependencies

- ⬜ Definition Schema & Storage session (table + resource must exist with data)
- ✅ Router and controller patterns established in existing codebase
- ✅ Zenoh DataServer pattern exists for LRT/LAT
- ✅ Delta sync pipeline exists

## Acceptance Criteria

`curl http://localhost:4003/api/definitions?term=workplace` returns JSON with all laws defining "workplace", including definition text, scope, and the law name. Definitions appear in delta sync exports.
