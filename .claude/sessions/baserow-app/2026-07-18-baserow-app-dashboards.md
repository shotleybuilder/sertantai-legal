---
session: Baserow App / Dashboard Architecture — scoping
project: sertantai-legal
status: closed
opened: 2026-07-18
closed: 2026-07-18
outcome: success
commits: [e00780e]

summary: >
  Scoped Baserow App Builder and Dashboard capabilities. Designed the Assessment App
  (2-page: queue + form) with law-level grain, simple risk scoring, linked personnel.
  Single_select filter fix applied. Research and design absorbed into meta session.

decisions:
  - what: Law-level assessment grain, not provision-level
    why: Maps to Enhesa's structure, simpler for initial migration. Provision-level is a future drill-down.
    result: 488 rows per customer (QQ), manageable queue

  - what: Apps are generic, not customer-specific
    why: What we build for QQ is the standard onboarding pipeline for all customers.
    result: Design doc and implementation are reusable

lessons:
  - title: Baserow App Builder is fully API-driven — programmatic app creation is viable
    detail: >
      Every element (pages, data sources, forms, tables, events, actions) is API-creatable.
      Apps can be part of the onboarding pipeline alongside table creation via templates.apply.
    tag: baserow

  - title: Dashboards need data to dashboard — sequence matters
    detail: >
      Dashboard was initially the "quick win" recommendation but there's no assessment data
      yet. The App (which creates the data) must come before the Dashboard (which visualises it).
    tag: baserow

artifacts:
  - docs/compliance/l2-risk-prioritisation/ASSESSMENT-APP-DESIGN.md

depends_on:
  - 2026-07-18-sync-snagging-list.md

enables:
  - baserow-app/2026-07-18-meta.md
---

# Baserow App / Dashboard Architecture

**Started**: 2026-07-18 10:15

## Scope
Options and architecture for Baserow App / Dashboards to workflow Assessments, Hierarchy, and Actions tables for QQ.

## Research Findings

### Baserow Application Builder
- 30+ visual elements: forms, tables, buttons, inputs, repeaters, columns, menus
- **CRUD capable**: Form element creates/updates rows, Table element displays with inline edit
- Data sources connect pages to tables with filtering
- Actions on events (button click → update row, navigate, etc.)
- Multi-page apps with login, shared headers/footers
- Custom Code element for JS/CSS
- Can be published as standalone web apps
- **API-driven**: everything UI-doable is API-creatable

### Baserow Dashboards
- 5 widget types: Summary, Bar Chart, Line Chart, Pie Chart, Doughnut
- Aggregations: count, sum, average
- Multi-table: widgets from different tables on one dashboard
- Auto-refresh when data changes
- Good for KPIs / overview, NOT for workflow

### What each table needs

**Assessments** (workflow-heavy):
- Customer reviews each law's compliance status
- Needs: kanban (Compliance Board), calendar (Review Calendar), form for updates
- Current views: All, Non-Compliant, Overdue, By Family, Kanban, Calendar
- **App Builder fit**: Form for assessment entry, table for review queue, kanban for status

**Hierarchy** (reference data, setup):
- Customer builds org structure, sites, cost centres
- Self-referential parent-child (adjacency list)
- Needs: tree view (BR doesn't have one), form for adding nodes
- **App Builder fit**: Form for node creation with parent selector, filtered views by hierarchy_type

**Actions** (workflow-heavy):
- Track remediation tasks from assessments/gaps
- Needs: kanban (Action Board), calendar (timeline), overdue filter
- Current views: All, Action Board (kanban), By Priority, By Type, Overdue, Timeline
- **App Builder fit**: Form for action creation, dashboard for overdue/priority KPIs

## Todo
- [x] Review current Assessments, Hierarchy, Actions template schemas
- [x] Research Baserow Application Builder capabilities
- [x] Research Baserow Dashboard features
- [x] Views — fixed in snagging session (`e00780e`) + single_select filter fix
- [x] Assessment App design doc: `docs/compliance/l2-risk-prioritisation/ASSESSMENT-APP-DESIGN.md`
- [x] Decisions: law-level grain, simple risk scoring, linked personnel, workspace member auth
- [ ] Phase 1: Seed Assessments table (moved to meta session)
- [ ] Phase 2: Build App in Baserow (moved to meta session)
- [ ] Phase 3: Enhesa migration (moved to meta session)
- [ ] Hierarchy App design (moved to meta session)
- [ ] Actions App design (moved to meta session)

## Recommendation (draft)

### Layer 1: Views — DONE
Fixed in snagging session (`e00780e`). All views have working filters, sorts, and groups. Kanban, Calendar, and filtered Grid views are functional.

### Layer 2: Dashboard (quick win, API-creatable)
Create a compliance dashboard with:
- Summary widget: total assessed, % compliant, overdue count
- Pie chart: compliance status distribution
- Bar chart: assessments by family
- Summary widget: open actions count, overdue actions

### Layer 3: App Builder (bigger investment, higher value)
Build a "Compliance Workbench" app with pages:
1. **Assessment Review** — form + table for working through the assessment queue
2. **Action Management** — form for creating actions, kanban for tracking
3. **Org Setup** — form for adding hierarchy nodes with parent selector
4. **Dashboard page** — embedded KPIs

### Order of work
1. Fix view filters (snagging item — already identified)
2. Create Dashboard via API (can be done programmatically)
3. Scope App Builder pages (needs UX decisions with user)

## Notes
- Baserow App Builder is no-code but API-driven — we can create apps programmatically
- Dashboard is the lowest-effort, highest-visibility win
- App Builder forms would replace manual row creation in grid view
- Tree view for Hierarchy is not natively supported — adjacency list + filtered views is the workaround
