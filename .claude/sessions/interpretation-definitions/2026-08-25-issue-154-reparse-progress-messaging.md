---
session: "Reparse Progress Messaging (#154)"
status: pending
opened: 2026-08-25
github_issue: 154
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
---

# Session: Reparse Progress Messaging (#154) (PENDING)

## Problem

The Reparse button on `/admin/definitions/browse` is fire-and-forget — returns immediately with a static "Parse started" message. The background task (fetch XML, parse 3 strategies, persist, mark parsed) gives no stage-by-stage feedback, no completion confirmation, and silently swallows errors. The LAT and scraper parsers already have a proven SSE streaming pattern that can be reused.

## Todo

- ⬜ Create `DefinitionsStagedParser` module with `on_progress` callback (same protocol as `LatStagedParser`)
- ⬜ Add SSE endpoint `parse_stream/2` to `DefinitionsAdminController` using `sse_event_loop` pattern
- ⬜ Add SSE route at `/api/definitions/admin/parse-stream`
- ⬜ Switch frontend `triggerReparse()` from POST to EventSource streaming
- ⬜ Update inline blue banner with per-stage progress (fetch → parse → persist → done)
- ⬜ Surface errors with stage + reason to user
- ⬜ Test: successful parse, fetch failure, parse with zero definitions

## Dependencies

- ✅ Definitions browse page built (UI phases 1-7)
- ✅ LAT SSE pattern proven (`LatStagedParser`, `lat_parse_stream/2`, `latParseStream()`)
- ✅ Definition parser and persister modules exist
