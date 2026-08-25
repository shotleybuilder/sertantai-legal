---
session: "GridLite Migration (#160)"
status: pending
opened: 2026-08-25
github_issue: 160
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
supersedes:
  - 156
---

# Session: GridLite Migration (#160) (PENDING)

## Problem

All three definitions admin pages use raw HTML `<table>` elements with manually implemented sorting, filtering, sticky headers, and result limiting. The project already uses `@shotleybuilder/svelte-gridlite-kit@0.10.0` with the PGlite adapter on LRT browser and LAT queue. Migrating definitions tables to GridLite unifies the UX and delivers sorting (#156), pagination, virtual scroll, column resize, and saved views for free.

## Todo

- ⬜ Migrate dashboard table (`/admin/definitions`) — 7-column family summary, row-click navigation
- ⬜ Migrate browse definitions table (`/admin/definitions/browse`) — 5-column right pane, preserve split layout and detail panel
- ⬜ Migrate diagnostic findings table (`/admin/definitions/diagnostic`) — remove 200-row hard limit, virtual scroll
- ⬜ Configure natural section sort comparator for Section column
- ⬜ Wire `svelte-gridlite-views` for saved view persistence
- ⬜ Verify existing features preserved: detail panel, row navigation, category filtering, async diagnostic flow
- ⬜ Close #156 as superseded if sorting delivered

## Dependencies

- ✅ `@shotleybuilder/svelte-gridlite-kit@0.10.0` installed
- ✅ `@shotleybuilder/gridlite-adapter-pglite@0.7.3` installed
- ✅ `@shotleybuilder/svelte-gridlite-views@0.2.1` installed
- ✅ GridLite proven on LRT browser and LAT queue pages
