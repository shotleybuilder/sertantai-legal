---
session: LAT Parsing Session Workflow
status: closed
opened: 2026-03-08
closed: 2026-03-08
---
# Title: LAT Parsing Session Workflow

**Started**: 2026-03-08
**Issue**: #48

## Goal
Bring the rich LRT session-based parsing experience to LAT parsing.

## Key Phases (from #48)
1. Extend `scrape_sessions` + `scrape_session_records` tables (add `type` discriminator, LAT-specific fields)
2. Backend `LatSessionManager` — create sessions from family/type_code/function/queue_reason filters
3. SSE streaming for LAT — 5-stage progress (fetch_body, parse_structure, persist_lat, parse_annotations, persist_annotations)
4. "Parse Family" dialog on `/admin/lat/queue` — filter, preview count, create session, redirect
5. LAT session detail page (`/admin/lat/sessions/:id`) — records table, selection, auto-parse, streaming progress
6. LAT sessions list page (`/admin/lat/sessions`) — session history

## Completed
- [x] Explored LRT reparse session infrastructure (backend + frontend)
- [x] Explored current LAT parsing flow
- [x] Created GitHub issue #48
- [x] Phase 1-2: DB migration + Ash resource updates
- [x] Phase 3: LatSessionManager + LatStagedParser + Storage helpers
- [x] Phase 4: 9 API endpoints + routes in LatAdminController + router
- [x] Phase 5: Frontend API client + TanStack Query hooks
- [x] Phase 6a-b: LatParseDialog + LatParseReviewModal components
- [x] Phase 6c-d: LAT sessions list + session detail pages
- [x] Phase 6e: Parse Family button + Sessions link on queue page
- [x] Backend compiles clean, frontend svelte-check 0 errors

## Files Created
- `backend/priv/repo/migrations/20260308220000_add_lat_session_support.exs`
- `backend/lib/sertantai_legal/scraper/lat_session_manager.ex`
- `backend/lib/sertantai_legal/scraper/lat_staged_parser.ex`
- `frontend/src/lib/components/LatParseDialog.svelte`
- `frontend/src/lib/components/LatParseReviewModal.svelte`
- `frontend/src/routes/admin/lat/sessions/+page.svelte`
- `frontend/src/routes/admin/lat/sessions/[id]/+page.svelte`

## Files Modified
- `backend/lib/sertantai_legal/scraper/resources/scrape_session.ex`
- `backend/lib/sertantai_legal/scraper/resources/scrape_session_record.ex`
- `backend/lib/sertantai_legal/scraper/storage.ex`
- `backend/lib/sertantai_legal_web/controllers/lat_admin_controller.ex`
- `backend/lib/sertantai_legal_web/router.ex`
- `frontend/src/lib/api/lat.ts`
- `frontend/src/lib/query/lat.ts`
- `frontend/src/routes/admin/lat/queue/+page.svelte`

## Notes
- Extended existing tables rather than new ones — session pattern is identical, only parse payload differs
- `session_type` discriminator: `scrape` | `reparse` | `lat_parse`
- LAT has 5 stages (fetch_body, parse_lat, persist_lat, parse_annotations, persist_annotations) vs LRT's 6
- Fixed: LAT sessions were showing in LRT scrape sessions list — added filter in scrape_controller
- Fixed: auto-parse was ignoring selection, parsing all pending records — now strictly uses selectedRecords
- Perf: LAT queue page switched from createLiveQuery (all records) to createDynamicQueryStore (family-scoped SQL)
- Added family-based sidebar views to LAT queue matching LRT page pattern
- Nav dropdown for Sessions (LRT/LAT) added to admin layout

**Ended**: 2026-03-08T22:45Z
