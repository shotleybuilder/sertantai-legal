---
session: "Fitness legacy cleanup — drop P-dimension columns"
project: sertantai-legal
status: closed
opened: 2026-07-13
closed: 2026-07-13
outcome: success
commits: [de6c2c6, f44d368]

summary: >
  Removed all legacy P-dimension fitness columns from both law-level (legal_register,
  7 columns) and provision-level (legal_articles, 7 columns) tables. Updated 13 backend
  + 11 frontend files, 3 test files, 4 migrations. Zero legacy fitness references remain.

decisions:
  - what: Provision-level fitness columns also removed (legal_articles + lat view)
    why: Fractalaw confirmed it no longer publishes provision-level fitness data. The provision subscriber field_atoms and legal_article attributes were dead code.
    result: 7 columns dropped from legal_articles, lat view recreated (simple view, no triggers)
  - what: has_fitness generated column simplified to only check fitness_entities
    why: Old expression referenced fitness_person through fitness_sector (all dropped). Must drop has_fitness before dropping the columns it depends on.
    result: "\"ALTER TABLE legal_register DROP COLUMN has_fitness\" then re-add with simple expression"
  - what: FitnessRulesRenderer.svelte kept as dead code (not deleted)
    why: Component is no longer imported anywhere but deletion is a separate concern. Import was removed from RecordDetailPanel.
    result: File exists but unused — can be deleted in a future cleanup

metrics:
  columns_dropped: { legal_register: 7, legal_articles: 7, sync_profiles: 5, total: 19 }
  files_updated: { backend: 13, frontend: 11, tests: 3 }
  migrations: 4

lessons:
  - title: "Drop generated columns BEFORE dropping columns they reference"
    detail: >
      ALTER TABLE legal_register DROP COLUMN fitness_person fails with
      "column has_fitness depends on column fitness_person". Must drop
      has_fitness first, then drop the referenced columns, then recreate
      has_fitness with the new expression. This ordering constraint is
      not obvious from the /db-schema-changes skill template.
    tag: schema
  - title: "Ash codegen crashes when removing many columns at once"
    detail: >
      mix ash_postgres.generate_migrations with 7 columns removed from
      multiple resources triggers rename prompts and RuntimeError
      "Could not get matching name after 3 attempts". Run the manual
      migration first so columns are already gone, then generate codegen.
    tag: schema
  - title: "Scoring query parameter renumbering is error-prone"
    detail: >
      The screening page's scored matching SQL used $1-$9 positional
      parameters. Removing $3-$6 (legacy fitness) required renumbering
      all subsequent params. Easy to miscount. The simplified query
      went from 9 params to 4, which is much cleaner.
    tag: tooling

artifacts:
  - backend/priv/repo/migrations/20260713140001_drop_legacy_fitness_columns.exs
  - backend/priv/repo/migrations/20260713150001_drop_provision_fitness_columns.exs
  - docs/fitness/FITNESS-APPLICABILITY.md
  - docs/zenoh/ZENOH-SPEC.md

depends_on:
  - 2026-07-13-fitness-schema-migration.md
  - 2026-07-13-fitness-rules-engine.md
  - 2026-07-13-fitness-phase3-expression-trees.md

enables:
  - Clean codebase for fitness v2 features (SIC codes, hierarchy expansion, expression tree refinement)
  - Delete FitnessRulesRenderer.svelte (dead code)
---

# Title: Fitness legacy cleanup — drop P-dimension columns

**Started**: 2026-07-13

## Todo
- [x] Remove legacy fitness attributes from LegalRegister Ash resource
- [x] Remove legacy fitness from TaxaSubscriber (@field_atoms + normalize_taxa)
- [x] Remove legacy fitness from ProfileQuery (apply_fitness_filter calls)
- [x] Remove legacy fitness from screening controller (vocabulary queries)
- [x] Remove legacy fitness from customer screening scored matching query
- [x] Remove legacy fitness from frontend (PGLite schema, Electric schema, sync, columns, field-config, screening page)
- [x] Migration: drop columns + update has_fitness + view/trigger rebuild
- [x] Update remaining backend references (sync_profile, field_tiers, change_detector, etc.)
- [x] Drop provision-level fitness columns (legal_articles + lat view)
- [x] Update FITNESS-APPLICABILITY.md and ZENOH-SPEC.md (remove stale references)

## Notes
- Legacy columns: fitness_person, fitness_process, fitness_place, fitness_plant, fitness_property, fitness_sector, fitness (7 law-level + 7 provision-level)
- has_fitness generated column simplified to only reference fitness_entities
- Must drop has_fitness BEFORE dropping columns it depends on
- Ash codegen crashes with RuntimeError on mass column removal — run manual migration first
