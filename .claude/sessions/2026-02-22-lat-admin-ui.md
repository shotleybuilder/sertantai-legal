# LAT & Amendments Admin UI

**Started**: 2026-02-22
**Context**: `.claude/sessions/2026-02-22-issue-23-lat-table.md` (Phase 3 parser, Phase 4b commentary parser)

## Objective
Build admin UI for browsing/re-parsing LAT and amendment annotations, following style cues of existing LRT admin UI.

## Todo
- [x] Plan: identify admin pages/endpoints needed
- [x] Backend: LatReparser + LatAdminController (5 endpoints) + 19 tests — `8cdae60`
- [x] Frontend: API client, TanStack Query hooks, `/admin/lat` page, nav update — `8cdae60`

## Notes
- New route: `/admin/lat` — law-first browsing (select law → structure/annotations tabs)
- Backend endpoints: `GET /api/lat/stats`, `/laws`, `/laws/:law_name`, `/laws/:law_name/annotations`, `POST /laws/:law_name/reparse`
- LatReparser: standalone fetch→parse→persist pipeline extracted from StagedParser substage
- REST API + TanStack Query (not ElectricSQL) — simpler for admin tool, cache invalidation on reparse
- Synchronous reparse (1-5s) — no SSE needed
- 1056 backend tests + 95 frontend tests, 0 failures
