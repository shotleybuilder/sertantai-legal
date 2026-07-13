---
session: "Fitness schema migration — v0.3 fields from ZENOH-SPEC"
project: sertantai-legal
status: closed
opened: 2026-07-13
closed: 2026-07-13
outcome: success
commits: [e5c152e]

summary: >
  Added 5 new fitness v0.3 columns to legal_register from fractalaw ZENOH-SPEC v2.2:
  fitness_entities, fitness_scope_dimensions, fitness_mention_count, fitness_applies_count,
  fitness_disapplies_count. Full uk_lrt view+trigger rebuild, TaxaSubscriber wired up,
  1476 tests pass. Legacy P-dimension columns retained for future retirement.

decisions:
  - what: Add new columns alongside old ones rather than replacing
    why: 14 backend + 13 frontend files reference legacy fitness_person/process/place/plant/property/sector columns. Replacing in one session would be too large a blast radius.
    result: Both old and new columns coexist. has_fitness triggers on fitness_entities OR any legacy column.

metrics:
  columns_added: 5
  files_referencing_legacy_fitness: { backend: 14, frontend: 13 }
  tests: { total: 1476, failures: 0 }

lessons:
  - title: "Jason.encode! crashes on raw binary UUIDs from schemaless Ecto queries"
    detail: >
      Raw Ecto queries (from(x in "table_name")) return UUID columns as 16-byte binary,
      not string UUIDs. Jason.encode! raises "invalid byte 0xAA" on these. Fix: use
      type(field, Ecto.UUID) in the select to get string form. This bit us on the
      customer list Zenoh queryable — the Demo org UUID aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
      was returned as raw bytes.
    tag: schema
  - title: "Ash codegen migrations still fire for view-backed columns added manually"
    detail: >
      After adding columns via manual migration (with view+trigger rebuild),
      mix ash_postgres.generate_migrations creates a codegen migration for the
      snapshot sync. Make it a no-op with a comment — the columns already exist.
      Same pattern as the explanatory_note migration.
    tag: schema

artifacts:
  - backend/priv/repo/migrations/20260713000001_add_fitness_v03_columns.exs
  - backend/priv/repo/migrations/20260713071809_add_fitness_v03_codegen.exs
  - backend/lib/sertantai_legal/legal/legal_register.ex
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex

depends_on:
  - 2026-07-02-significance-signals.md

enables:
  - Fractalaw can publish fitness_entities and sertantai persists them
  - Phase 2 fitness rules engine (entity index + expression tree evaluator)
  - Retirement of legacy P-dimension fitness columns
---

# Title: Fitness schema migration — v0.3 fields from ZENOH-SPEC

**Started**: 2026-07-13

## Todo
- [x] Add new columns to legal_register: fitness_entities, fitness_scope_dimensions, fitness_mention_count, fitness_applies_count, fitness_disapplies_count
- [x] Update TaxaSubscriber to extract new fields from Arrow IPC
- [x] Migration (manual — legal_register is a view with INSTEAD OF triggers)
- [x] Verify round-trip: Arrow decode → persist → read back
- [x] Update has_fitness generated column to include fitness_entities
- [x] Ash codegen migration (no-op)
- [x] All 1476 tests pass

## Notes
- New fields defined in docs/zenoh/ZENOH-SPEC.md v2.2 (lines 575-579)
- legal_register is a view-backed table — needs manual migration with trigger rebuild
- TaxaSubscriber in backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex
- LegalRegister resource in backend/lib/sertantai_legal/legal/legal_register.ex
- Commit e5c152e pushed to main
- Old fitness fields (fitness_person/process/place/plant/property/sector, fitness) retained — 14 backend + 13 frontend files reference them, retire in future session
- has_fitness generated column updated to trigger on fitness_entities OR any legacy P-dimension column
- docs/controls/FITNESS-APPLICABILITY.md describes Phase 2 (rules engine) and Phase 3 (compiled expression trees) as future work
