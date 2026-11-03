---
session: Dashboards — First Use Case
status: closed
opened: 2026-07-21
closed: 2026-07-21
---
# Dashboards — First Use Case

**Started**: 2026-07-21
**Meta**: `baserow-app/2026-07-18-meta.md`
**Related**: `baserow/2026-07-21-hierarchy-models.md`

## Context

Baserow Dashboards were deferred in the meta session until assessment data exists.
The Hierarchy→LRT link_row is now populated (276 laws linked to 28 hierarchy nodes).
First dashboard use case: "What laws apply at site X?"

## Research Findings

### Dashboard Capabilities
- **API**: Full REST API — dashboards, widgets, data sources all API-creatable
- **Widgets**: Summary, Bar Chart, Line Chart, Pie Chart, Doughnut (up to 3 series)
- **Plan**: Premium tier required ($10/user/month)
- **Auto-refresh**: Widgets update when underlying data changes

### Dashboard Limitations (critical)
- **link_row fields blocked from filtering** — cannot filter "count where Hierarchy contains ABE"
- **No interactive filters** — no user-selectable dropdown, no "pick a site" parameter
- **Static only** — each widget has fixed config, no dynamic drill-down
- **No cross-table joins** — each widget queries one table independently

### Verdict: App Builder, not Dashboard

For "Laws at Site X", **App Builder page is the right tool**:
- Record selector to pick a hierarchy node
- Data source: LRT filtered by `link_row_contains` on Hierarchy
- Table showing applicable laws for the selected node
- Page parameters enable dynamic filtering

Dashboards are useful later for **static KPIs**:
- Total law count (Summary widget)
- Laws per Family (Pie chart)
- Assessment completion % (Summary widget)
- But NOT for interactive queries involving link_row fields

## Design Intent: Apps vs Dashboards

- **Apps = doing** (operational users): data entry, workflows, drill-down. Multi-page.
- **Dashboards = seeing** (decision-makers): KPIs, charts, trends. Static, standalone.
- They're complementary, not alternatives. Share the same underlying tables.
- Dashboards are standalone workspace objects — NOT embeddable in apps.
- Multi-page apps are the intended pattern. Our 12-page Compliance Workbench is fine.
- Page proliferation risk is multiple *apps*, not multiple *pages*.

## Decision

- **"Laws by Site"** → App Builder page (operational, interactive, link_row filter)
- **Compliance KPIs** → Dashboard (static, management view) — defer until assessment data exists

## Todo
- [x] Research Baserow Dashboard capabilities and API
- [x] Evaluate: dashboard vs app page → App Builder for interactive, Dashboard for KPIs
- [x] Research design intent — apps for doing, dashboards for seeing
- [ ] Build "Laws by Site" app page: hierarchy selector → filtered LRT table
- [ ] Defer KPI dashboard until assessment data exists (compliance %, overdue actions, etc.)

## Notes
- Dashboard API: `/{dashboard_id}/widgets/`, `/{dashboard_id}/data-sources/`
- Dashboard = separate workspace object, Premium tier required
- App pages share auth, headers, nav, domain — consolidation is natural
- KPI dashboard candidates: law count, assessment completion %, overdue actions, laws per family
