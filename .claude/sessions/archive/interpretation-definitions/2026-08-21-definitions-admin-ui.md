---
session: Definitions Admin UI
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Delivered the complete definitions admin UI across 7 phases in a single session.
  Backend API (4 endpoints, 13 tests), ElectricSQL sync (83K definitions + 2.8K links),
  and 4 SvelteKit pages — family dashboard, law browser with detail panel, action
  triggers, and diagnostic explorer. All type-checked, built, and pushed.

decisions:
  - what: 7-phase incremental delivery with per-phase sessions
    why: >
      Each phase is independently deployable and testable. Per-phase sessions
      enable clean commit boundaries and focused session close documentation.
      Dependencies flow naturally — backend API first, then data sync, then UI.
    result: 7 phases completed, 4 commits, all pushed to main
  - what: Diagnostic results via on-demand API, not ElectricSQL sync
    why: >
      Diagnostic findings are ephemeral — recomputed from current DB state each run.
      Persisting to a table and syncing via Electric would add staleness management
      complexity. The diagnostic endpoint runs Diagnostic.run/1 fresh each time.
    result: No persistence table needed, always-fresh results, history deferred
  - what: PGLite queries for browse page, backend API for dashboard + diagnostic
    why: >
      Browse page needs per-law definition lists — these work well as local PGLite
      queries on synced data (zero latency, offline-capable). Dashboard needs family
      aggregates with CTEs (better server-side). Diagnostic is compute-heavy (builds
      indexes, scans all cross-refs) so must run on the backend.
    result: Optimal data source per page — local for browsing, server for aggregation

metrics:
  phases:
    total: 7
    completed: 7
    commits: 4
  backend:
    endpoints: 4
    tests: 13
    test_failures: 0
  frontend:
    pages: 4
    routes: ["/admin/definitions", "/admin/definitions/browse", "/admin/definitions/diagnostic"]
    type_errors: 0
  data:
    definitions_synced: 83369
    definition_links_synced: 2814
    dependencies_updated: 106

lessons:
  - title: "Phased UI delivery with per-phase sessions enables rapid iteration"
    detail: >
      7 phases completed in a single conversation session. Each phase had its own
      session doc with focused todo, clean close with frontmatter, and independent
      commit. The meta-plan session tracked overall progress. This pattern works
      well for multi-page UI builds where each page is independently useful.
    tag: tooling
  - title: "ElectricSQL shapes for 83K rows work fine in PGLite with IndexedDB"
    detail: >
      Legislative definitions (83K rows, 50MB) sync without issues. Average
      definition is 161 chars. PGLite handles GROUP BY joins across definitions +
      laws tables locally in the browser. No column exclusions needed.
    tag: sync
  - title: "Fire-and-forget Tasks for admin operations simplify the API but complicate testing"
    detail: >
      Parse and resolve endpoints use Task.start for async execution. This means
      the HTTP response is instant but there is no way to track completion from
      the frontend. Ecto SQL Sandbox in tests produces noisy disconnection errors
      because the Task outlives the test process. Acceptable for admin tooling.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal_web/controllers/definitions_admin_controller.ex
  - backend/test/sertantai_legal_web/controllers/definitions_admin_controller_test.exs
  - frontend/src/lib/pglite/schema.sql.ts
  - frontend/src/lib/pglite/sync.ts
  - frontend/src/routes/admin/+layout.svelte
  - frontend/src/routes/admin/definitions/+page.svelte
  - frontend/src/routes/admin/definitions/browse/+page.svelte
  - frontend/src/routes/admin/definitions/diagnostic/+page.svelte

depends_on:
  - 2026-08-20-issue-153-substantive-section-defs
  - 2026-08-20-food-gas-citation-fixes

enables:
  - "Visual definition resolution workflow — replaces CLI-driven parse/resolve/diagnose"
  - "Browser-based definition quality monitoring without terminal access"
---

# Session: Definitions Admin UI (CLOSED)

## Problem

Definition resolution work (parsing, resolving, diagnosing) is entirely CLI-driven — mix tasks, Tidewave eval, SQL queries. There's no way to browse definitions, see diagnostic results in context, or trigger operations from the admin UI. After 5 days of intensive definition work hitting 90%+ across all safety families, the need for a visual tool is clear: seeing which definitions are unlinked, why they failed, and which laws need attention should not require a terminal session.

The UI must connect definition records (legislative_definitions + definition_links) with diagnostic results (computed failure classifications) and legal register metadata (family, title, parse status). It should also support triggering reparse and resolve operations.

## Todo

- ✅ Phase 1: Backend API — stats/diagnostic/parse/resolve endpoints (diagnostic history deferred — needs persistence table)
- ✅ Phase 2: ElectricSQL shape — 83K definitions + 2.8K links synced to PGLite, 106 deps updated
- ✅ Phase 3: Family dashboard — sortable stats table, summary cards, safety/environment filter, color-coded effective %
- ✅ Phase 4: Law definitions browser — split-pane with searchable law list + definitions table, PGLite-powered
- ✅ Phase 5: Definition detail — inline panel with full text, citation, root definitions, legislation.gov.uk links
- ✅ Phase 6: Action triggers — resolve button on dashboard, reparse button on browse, loading states + feedback
- ✅ Phase 7: Diagnostic explorer — category bars, findings table, top parents, family filter

## Dependencies

- ✅ ElectricSQL fully set up (shapes for uk_lrt, org_applicabilities working)
- ✅ GridLite data grid available (@shotleybuilder/svelte-gridlite-kit)
- ✅ PGLite + live queries pattern established
- ✅ Admin layout with nav, auth, country selector
- ✅ Definition pipeline stable (parser, resolver, diagnostic all working)
- ✅ All safety families >90% effective resolution (data quality baseline)
- ⏸️ Backend: diagnostic history persistence (deferred — on-demand API sufficient for now)

## Design

### Data Model

Three data sources converge in the UI:

```
┌─────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│   legal_register    │     │ legislative_definitions│     │  diagnostic_findings │
│   (via uk_lrt)      │     │  + definition_links   │     │  (NEW table)         │
│                     │     │                       │     │                      │
│ name ───────────────┼──→──┤ law_name              │     │ definition_id ──→────┤
│ family              │     │ term                  │     │ category             │
│ title_en            │     │ definition            │     │ citation             │
│ definitions_parsed_at│    │ references_other_law  │     │ target_law           │
│ live                │     │ citation              │     │ nearest_term         │
│ enacted_by          │     │ section_id            │     │ detail               │
└─────────────────────┘     │ scope                 │     │ run_at               │
                            │                       │     └──────────────────────┘
                            │ child_definition_id ──┤
                            │ root_definition_id  ──┤
                            └───────────────────────┘
```

**Decision: diagnostic results via API, not persisted.** The Diagnostic module returns `[%Finding{}]` in memory. Rather than persisting to a table and syncing via ElectricSQL, the diagnostic endpoint runs on-demand and returns fresh results. This avoids staleness and a persistence table. History/persistence deferred.

### Navigation

Add to admin nav as a dropdown:

```
Definitions
  ├── Dashboard       /admin/definitions
  ├── Browse           /admin/definitions/browse
  └── Diagnostic      /admin/definitions/diagnostic
```

### Page Layouts

**Dashboard** (`/admin/definitions`) — Family-level overview
```
┌─────────────────────────────────────────────────────────────────┐
│ Definitions Dashboard                        [Resolve] [Diagnose]│
├─────────────────────────────────────────────────────────────────┤
│ Summary cards: Total defs | Cross-refs | Linked | Effective %  │
├─────────────────────────────────────────────────────────────────┤
│ GridLite: Family stats                                          │
│ ┌──────────┬───────┬────────┬────────┬──────┬───────┬─────────┐│
│ │ Family   │ Defs  │ X-refs │ Linked │ Eff% │ NoCit │ NotFound││
│ ├──────────┼───────┼────────┼────────┼──────┼───────┼─────────┤│
│ │ 💙 OH&S  │ 3137  │  381   │  349   │ 98.4 │   7   │   25   ││
│ │ 💚 ENV   │ 1842  │  290   │  268   │ 96.2 │   5   │   17   ││
│ │ ...      │       │        │        │      │       │         ││
│ └──────────┴───────┴────────┴────────┴──────┴───────┴─────────┘│
│                                        Click row → law list     │
└─────────────────────────────────────────────────────────────────┘
```

**Browse** (`/admin/definitions/browse`) — Law-level + definition-level
```
┌─────────────────────────────────────────────────────────────────┐
│ Definitions Browser                    Family: [OH&S ▼] [Reparse]│
├────────────────────┬────────────────────────────────────────────┤
│ Law List (left)    │ Definitions (right)                        │
│                    │                                            │
│ ▸ HSWA 1974        │ GridLite: definitions for selected law     │
│   382 defs, 98.4%  │ ┌──────┬────────────────┬──────┬────────┐ │
│ ▸ MHSWR 1999      │ │ Term │ Definition     │ Type │ Diag   │ │
│   24 defs, 100%    │ ├──────┼────────────────┼──────┼────────┤ │
│ ▸ CDM Regs 2015   │ │ work │ has the meani..│ xref │ linked │ │
│   18 defs, 94.4%   │ │ site │ means any pla..│ subst│   —    │ │
│                    │ │ act  │ the Food Safe..│ cite │   —    │ │
│                    │ └──────┴────────────────┴──────┴────────┘ │
│                    │                                            │
│                    │ Click row → detail panel                   │
├────────────────────┴────────────────────────────────────────────┤
│ Detail Panel (bottom or slide-over)                             │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Term: "workplace"                                           │ │
│ │ Definition: "has the meaning given in regulation 2(1) of   │ │
│ │             the Workplace Regulations 1992"                 │ │
│ │ Citation: Workplace (Health Safety and Welfare)             │ │
│ │           Regulations 1992                                   │ │
│ │ Status: ✅ Linked                                           │ │
│ │ Root: workplace → "any premises or part of premises which   │ │
│ │       is not domestic premises..."                           │ │
│ │       (Workplace Regulations 1992, regulation 2)            │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Diagnostic** (`/admin/definitions/diagnostic`) — Category drilldown
```
┌─────────────────────────────────────────────────────────────────┐
│ Diagnostic Explorer            Family: [All ▼]  [Run Diagnostic]│
├─────────────────────────────────────────────────────────────────┤
│ Category breakdown (horizontal bar or donut)                    │
│ ████████████ term_not_found (38)                                │
│ ██████ no_citation (14)                                         │
│ ███ parent_not_in_lrt (9)                                       │
│ █ parent_revoked (3)     ← greyed as ceiling                   │
│ █ internal_ref (2)       ← greyed as ceiling                   │
├─────────────────────────────────────────────────────────────────┤
│ GridLite: findings for selected category                        │
│ ┌──────────────┬───────┬──────────────┬────────────┬──────────┐│
│ │ Law          │ Term  │ Citation     │ Target Law │ Detail   ││
│ ├──────────────┼───────┼──────────────┼────────────┼──────────┤│
│ │ UK_uksi_2013 │ food  │ Food Safety  │ UK_ukpga.. │ nearest: ││
│ │   _2996      │ auth..│ Act 1990     │   1990_16  │ food_aut ││
│ └──────────────┴───────┴──────────────┴────────────┴──────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### ElectricSQL Shapes

Two new shapes needed (following existing `sync.ts` pattern):

| Shape | Table | Columns | Where | Actual rows |
|-------|-------|---------|-------|-------------|
| `definitions` | `legislative_definitions` | all 13 | — | 83,369 |
| `definition-links` | `definition_links` | all 3 | — | 2,814 |

Diagnostic findings served via API (computed, not synced) — ephemeral, re-generated on each diagnostic run.

### Backend API Additions

| Method | Endpoint | Purpose | Status |
|--------|----------|---------|--------|
| `GET` | `/api/definitions/admin/stats` | Family-level aggregated stats | ✅ |
| `GET` | `/api/definitions/admin/diagnostic` | Run diagnostic, return findings (optional `?family=` filter) | ✅ |
| `POST` | `/api/definitions/admin/parse` | Trigger definition parse for a law or family | ✅ |
| `POST` | `/api/definitions/admin/resolve` | Trigger root resolver | ✅ |
| `GET` | `/api/definitions/admin/diagnostic/history` | Past diagnostic runs + summaries | ⏸️ Deferred |

## Phase Details

### Phase 1: Backend API

**Goal**: Expose definition stats, diagnostic, and operations via authenticated admin endpoints.

Work:
- Add `DefinitionsAdminController` with stats/diagnostic/parse/resolve actions
- Stats endpoint: aggregate query joining `legislative_definitions` with `legal_register` grouped by family
- Diagnostic endpoint: wraps `Diagnostic.run/1` + `summarise/1`, returns JSON
- Parse endpoint: wraps `DefinitionParser.parse` + `DefinitionPersister.persist` for single law or `mix definitions.backfill` for batch
- Resolve endpoint: wraps `RootResolver.resolve_all/1` (async via Task, return job ID)
- Add routes under `/api/admin/definitions/*` (authenticated)

### Phase 2: ElectricSQL Shape

**Goal**: Sync definitions and links to PGLite for offline-first browsing.

Work:
- Add `definitions` and `definition_links` tables to PGLite schema (`schema.sql.ts`)
- Add shape subscriptions in `sync.ts` (following the `laws` pattern)
- Bump `SCHEMA_VERSION`
- Verify 66K definitions sync performantly (may need column subset)

### Phase 3: Family Dashboard

**Goal**: At-a-glance view of definition resolution health per family.

Work:
- Create route: `frontend/src/routes/admin/definitions/+page.svelte`
- Add nav item to admin layout
- Summary cards: total definitions, cross-refs, linked, effective %
- GridLite table: one row per family, columns for each metric
- Click family → navigates to browse page filtered by family
- Data: PGLite live query joining `definitions` with `laws` (grouped by family)

### Phase 4: Law Definitions Browser

**Goal**: Browse definitions per law with diagnostic context.

Work:
- Create route: `frontend/src/routes/admin/definitions/browse/+page.svelte`
- Left panel: law list (filtered by family), showing def count + resolution %
- Right panel: GridLite of definitions for selected law
- Definition type column: substantive / cross-ref / citation / internal-ref
- Diagnostic column: linked / term_not_found / no_citation / etc. (from API)
- Click definition → opens detail panel

### Phase 5: Definition Detail

**Goal**: Show the full cross-reference chain for a single definition.

Work:
- Slide-over or bottom panel component
- Shows: term, full definition text, section_id, scope, citation flag
- If cross-ref: extracted citation, target law name + title, diagnostic category
- If linked: root definition(s) with their text and law context
- Visual chain: child → citation → parent → root

### Phase 6: Action Triggers

**Goal**: Trigger parse/resolve/diagnose from the UI.

Work:
- Reparse button on law list (single law) and family dashboard (batch)
- Resolve button on dashboard (global)
- Diagnose button on dashboard and diagnostic page
- Status feedback: loading spinner → success/error toast
- Last-run timestamps displayed

### Phase 7: Diagnostic Explorer

**Goal**: Standalone category-based drilldown for diagnostic findings.

Work:
- Create route: `frontend/src/routes/admin/definitions/diagnostic/+page.svelte`
- Category breakdown visualization (bar chart or summary cards)
- Actionable vs ceiling category distinction (visual)
- GridLite: findings filtered by category
- Family filter
- Link to browse page for specific laws/definitions
