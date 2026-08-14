---
session: Definition API
status: closed
opened: 2026-08-13
closed: 2026-08-14
outcome: success

summary: >
  Added legislative_definitions to the delta sync pipeline, built REST API endpoints
  (4 routes, 11 tests), and a Zenoh queryable for definitions per law. Compliance already
  queries the shared DB directly — these additions serve production delta sync, future
  non-DB consumers, and fractalaw enrichment via Zenoh.

decisions:
  - what: REST endpoints in public API scope (no auth)
    why: Definitions are public reference data like laws — same access pattern as /api/laws. Compliance doesn't call legal's API (queries shared DB directly), so auth adds no value for the primary consumer.
    result: 4 endpoints in public scope, matching /api/laws pattern

  - what: Delta sync is the priority deliverable, REST endpoints secondary
    why: User clarified compliance queries shared DB directly via its own backend. Delta sync is needed for production deployments. REST endpoints are future-proofing for non-DB consumers.
    result: Delta sync verified with 34,483 rows, REST endpoints built as a bonus

  - what: Search endpoint uses LIKE prefix matching, not full-text search
    why: Simple prefix search (term LIKE 'work%') is sufficient for autocomplete. Full-text search adds complexity with minimal benefit for a 12K-term dataset. Compliance can build more sophisticated search on its own backend if needed.
    result: GET /api/definitions/search?q=work returns matching terms with law counts

  - what: Zenoh queryable returns definitions per law, not per term
    why: Follows the existing pattern (LAT, amendments are per-law). Fractalaw processes one law at a time. Per-term lookup would require a different key expression pattern.
    result: fractalaw/@{tenant}/data/legislation/definitions/{law_name} — JSON + Arrow IPC

metrics:
  delta_sync: { rows_exportable: 34483 }
  rest_api: { endpoints: 4, tests: 11 }
  zenoh: { queryables_added: 1, formats: "json + arrow_ipc" }
  total_tests: { count: 1412, failures: 0 }

lessons:
  - title: Compliance queries the shared DB directly — legal API endpoints are not the primary integration path
    detail: >
      Initially assumed compliance would call legal's Phoenix API for definitions.
      User corrected: compliance's own backend queries the shared sertantai_legal_dev DB
      directly (ScreeningController.definitions/2 runs SQL JOINs). Legal's API endpoints
      serve future consumers, not the current compliance integration. This reframed the
      session priorities: delta sync first (production need), REST endpoints second.
    tag: infrastructure

  - title: Test DB (sertantai_legal_test) is empty — controller tests need seed data
    detail: >
      Controller tests using ConnCase run against the test DB, not dev DB. The
      34K definitions imported via mix definitions.import_csv only exist in dev.
      Tests must insert their own legal_register + legislative_definitions rows
      in the setup block. Also discovered legal_register requires jurisdiction
      (NOT NULL) and uses created_at not inserted_at.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/sync/delta/config.ex
  - backend/lib/sertantai_legal_web/controllers/definition_controller.ex
  - backend/lib/sertantai_legal_web/router.ex
  - backend/lib/sertantai_legal/zenoh/data_server.ex
  - backend/test/sertantai_legal_web/controllers/definition_controller_test.exs

depends_on:
  - 2026-08-13-definition-schema-storage.md
  - 2026-08-13-definition-parser.md

enables:
  - Production deployment of definitions (delta sync ready)
  - Fractalaw definition enrichment (Zenoh queryable ready)
  - Compliance Legal Glossary page (shotleybuilder/sertantai-compliance#11)
---

# Session: Definition API (CLOSED)

## Problem

Compliance already queries `legislative_definitions` via the shared DB — its own backend (`ScreeningController.definitions/2`) runs SQL JOINs directly. No call to legal's Phoenix server. The immediate need is delta sync so production deployments get the definitions data. REST endpoints on legal are for future consumers (external clients, services without shared DB access).

## Todo

- ✅ Include `legislative_definitions` in delta sync export/import (`mix data.export_delta` / `mix data.apply_delta`)
- ✅ Verify delta sync: export generates correct idempotent SQL (INSERT ... ON CONFLICT DO UPDATE)
- ✅ Create `DefinitionController` with endpoints:
  - `GET /api/definitions?term=workplace` — all definitions of a term across laws
  - `GET /api/definitions?law=UK_uksi_1999_3242` — all definitions in a law
  - `GET /api/definitions?term=workplace&law=UK_uksi_1999_3242` — specific lookup
  - `GET /api/definitions/search?q=work` — partial match / autocomplete
- ✅ Add routes to `router.ex` (public API scope, no auth)
- ✅ Controller tests (11 tests, seed data in setup)
- ✅ Zenoh queryable: `fractalaw/@{tenant}/data/legislation/definitions/{law_name}` (JSON + Arrow IPC)

## Dependencies

- ✅ Definition Schema & Storage session (34K rows in table)
- ✅ Definition Parser session (pipeline integration complete)
- ✅ Router and controller patterns established
- ✅ Delta sync pipeline exists

## Context: compliance integration

Compliance queries the shared DB directly — no call to legal's API:
```
Frontend (5176) → Compliance Phoenix (4004) → Shared DB (5436)
                  ScreeningController.definitions/2
                  → SQL JOIN legislative_definitions + legal_register
```

- Issue #10: profiler tooltips — shipped, sidebar shows term across N laws with title, year, scope, section_id
- Issue #11: standalone Legal Glossary page — search/autocomplete, built on compliance's own backend
- Compliance also has a read-only `Legal.LegislativeDefinition` Ash resource registered in its domain

## Acceptance Criteria

Delta sync includes `legislative_definitions` — export from dev and import to production works. REST endpoints return correct JSON for term/law queries (future consumers). `curl http://localhost:4003/api/definitions?term=workplace` returns JSON.
