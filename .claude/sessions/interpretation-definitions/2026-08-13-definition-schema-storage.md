---
session: Definition Schema & Storage
status: pending
opened: 2026-08-13
---

# Session: Definition Schema & Storage (PENDING)

## Problem

Extracted definitions need a database table and Ash resource. This session creates the `legislative_definitions` table, the Ash resource with CRUD actions, and wires the definition parser into the LAT parse pipeline so definitions are extracted and stored automatically.

## Todo

- ⬜ Create `LegislativeDefinition` Ash resource (`lib/sertantai_legal/legal/legislative_definition.ex`)
- ⬜ Generate migration with `mix ash_postgres.generate_migrations --name add_legislative_definitions`
- ⬜ Register resource in the domain (`api.ex`)
- ⬜ Add upsert action (unique on `law_name + term`) to handle re-parsing
- ⬜ Add read actions: `by_term`, `by_law`, `by_term_and_law`
- ⬜ Wire definition extraction into LAT parse pipeline (after LAT parse, before/alongside taxa)
- ⬜ Create `mix definitions.backfill` task to extract from all existing LAT data
- ⬜ Run backfill against a sample set (e.g. OH&S family) and verify counts
- ⬜ Integration tests: parse a law → definitions appear in DB with correct fields

## Dependencies

- ⬜ Definition Parser session (provides the extraction logic)
- ✅ LAT data in `legal_articles` table
- ✅ Ash/AshPostgres infrastructure

## Acceptance Criteria

After running the backfill task against OH&S laws, `legislative_definitions` contains definitions with correct terms, definition text, scopes, and cross-reference flags. Re-running the backfill is idempotent (upserts, no duplicates).
