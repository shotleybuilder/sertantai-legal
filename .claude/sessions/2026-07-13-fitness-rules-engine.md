---
session: "Applicability (fitness) rules engine"
project: sertantai-legal
status: closed
opened: 2026-07-13
closed: 2026-07-13
outcome: success
commits: [90286df]

summary: >
  Built the fitness applicability rules engine (Phase 2). GIN-indexed entity index
  narrows 3,532 making laws to ~141 candidates (96% reduction) for a typical profile.
  Wired through full stack: backend EntityIndex + ProfileQuery, vocabulary endpoint,
  admin grid column, PGLite/Electric sync, and customer screening scored matching.

decisions:
  - what: Use PostgreSQL GIN index on fitness_entities instead of ETS or separate table
    why: Only 654 laws × 12 avg entities = ~8K pairs. GIN index IS the inverted index — no extra infrastructure to maintain. Sub-millisecond queries proven.
    result: 0.167ms query time for array overlap, no GenServer or separate table needed
  - what: Combine all profile dimensions into single profileEntities array for fitness_entities matching
    why: fitness_entities contains canonical terms from all scope dimensions (personal, material, territorial). Matching the union against the flat array is simpler than dimension-by-dimension matching and catches cross-dimension hits.
    result: Single $8 parameter in scoring query, adds 1 point to match_score alongside legacy P-dimension checks
  - what: Keep legacy P-dimension scoring alongside fitness_entities in customer screening
    why: 534 laws have legacy fitness data, 654 have v0.3 entities. Not fully overlapping — removing legacy would lose coverage during transition.
    result: Max score 7 (was 6), both paths contribute independently

metrics:
  fitness_entities: { laws: 654, unique_entities: 1395, avg_per_law: 12, max: 100 }
  scope_dimensions: { material: 611, territorial: 553, personal: 468, conditional: 105 }
  candidate_reduction: { all_making: 3532, employer_construction: 141, reduction_pct: 96 }
  entity_distribution: { "1": 48, "2-5": 205, "6-15": 242, "16-30": 112, "31+": 47 }

lessons:
  - title: "Ecto cross_join with fragment generates invalid SQL alias — use raw SQL for unnest queries"
    detail: >
      Ecto's from(lr in "table", cross_join: e in fragment("unnest(?) as entity", lr.col))
      generates 'unnest(...) as entity AS f1' — double alias. For list_entities (unnest + group by),
      raw SQL via Ecto.Adapters.SQL.query! was the only clean option. find_candidates uses
      fragment("fitness_entities && ?::text[]") in WHERE which works fine.
    tag: tooling
  - title: "Customer profile schema already existed — check before building"
    detail: >
      OrgScreeningProfile already had regions, governed_actors, locations, materials, processes,
      sector — mapping directly to fitness scope dimensions. The vocabulary endpoint and screening
      query were already wired for the old P-dimension columns. Integration was a wiring change,
      not a new feature. Always check existing features before designing new ones.
    tag: data
  - title: "Separate admin and customer UI todos — they have different concerns"
    detail: >
      Initially combined "display and filter" as one todo. User corrected: admin grid column
      (filterable, data exploration) vs customer screening query (scored matching, applicability
      decisions) are distinct features with different integration points. Track separately.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/fitness/entity_index.ex
  - backend/priv/repo/migrations/20260713100001_add_fitness_entities_gin_index.exs
  - backend/lib/sertantai_legal/sync/profile_query.ex
  - backend/lib/sertantai_legal_web/controllers/screening_controller.ex
  - frontend/src/lib/components/parse-review/field-config.ts
  - frontend/src/lib/electric/uk-lrt-schema.ts
  - frontend/src/lib/pglite/schema.sql.ts
  - frontend/src/lib/pglite/sync.ts
  - frontend/src/lib/pglite/uk-lrt-columns.ts
  - frontend/src/routes/admin/lrt/+page.svelte
  - frontend/src/routes/app/screening/+page.svelte

depends_on:
  - 2026-07-13-fitness-schema-migration.md

enables:
  - Phase 3: compiled expression tree evaluation (when fractalaw publishes trees)
  - Hierarchy expansion (SIC codes, jurisdiction trees) for deeper matching
  - Retirement of legacy P-dimension fitness columns
---

# Title: Applicability (fitness) rules engine

**Started**: 2026-07-13

## Todo
- [x] Run fractalaw publish to populate fitness_entities + new v0.3 fields
- [x] Build inverted entity index (fitness_entities → law_names)
- [x] Customer profile schema — already exists (OrgScreeningProfile: regions, governed_actors, locations, materials, processes, sector)
- [x] Wire vocabulary endpoint to serve entities from fitness_entities (+ legacy fields kept)
- [x] Add fitness_entities filter path to ProfileQuery (3532 → 141 laws = 96% reduction)
- [x] Coarse filter: entity overlap via GIN index (hierarchy expansion is Phase 3)
- [x] Display fitness_entities in admin law detail view (field-config, PGLite schema, Electric schema, sync columns)
- [x] Admin LRT: add filterable Applicability Entities column to grid
- [x] Customer screening: wire fitness_entities into scored matching query ($8 profileEntities overlap)

## Notes
- Phase 2 from docs/controls/FITNESS-APPLICABILITY.md
- Schema ready: fitness_entities, fitness_scope_dimensions, fitness_mention_count, fitness_applies_count, fitness_disapplies_count (session 2026-07-13-fitness-schema-migration.md)
- 654 laws currently have fitness data
- Expression tree evaluator (Phase 3) is future — fractalaw not yet publishing compiled trees
