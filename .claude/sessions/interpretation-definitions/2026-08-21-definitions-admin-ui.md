---
session: Definitions Admin UI
status: active
opened: 2026-08-21
---

# Session: Definitions Admin UI (ACTIVE)

## Problem

Definition resolution work (parsing, resolving, diagnosing) is entirely CLI-driven — mix tasks, Tidewave eval, SQL queries. There's no way to browse definitions, see diagnostic results in context, or trigger operations from the admin UI. After 5 days of intensive definition work hitting 90%+ across all safety families, the need for a visual tool is clear: seeing which definitions are unlinked, why they failed, and which laws need attention should not require a terminal session.

The UI must connect definition records (legislative_definitions + definition_links) with diagnostic results (computed failure classifications) and legal register metadata (family, title, parse status). It should also support triggering reparse and resolve operations.

## Todo

- ✅ Phase 1: Backend API — stats/diagnostic/parse/resolve endpoints (diagnostic history deferred — needs persistence table)
- ✅ Phase 2: ElectricSQL shape — 83K definitions + 2.8K links synced to PGLite, 106 deps updated
- ✅ Phase 3: Family dashboard — sortable stats table, summary cards, safety/environment filter, color-coded effective %
- ✅ Phase 4: Law definitions browser — split-pane with searchable law list + definitions table, PGLite-powered
- ⬜ Phase 5: Definition detail — cross-ref chain visualization (child → citation → parent → root)
- ⬜ Phase 6: Action triggers — reparse, resolve, diagnose buttons with status feedback
- ⬜ Phase 7: Diagnostic explorer — standalone drilldown by category with filtering

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
