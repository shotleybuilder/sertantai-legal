# UI Improvements Session

**Started**: 2026-03-07
**Type**: Iterative UI improvements

## Todo
- [x] Reparse button / View Record modal: a) remove Taxa from reparse workflow (moved to external Zenoh service), b) remove Taxa stage from View Record UI

- [x] Consolidate reparse: new sessionless `GET /api/uk-lrt/:id/parse-stream` SSE endpoint + wire LRT admin reparse button to use scrape-style streaming parse + diff UI (update mode, not read mode)

- [x] Stop taxa stage running during reparse; preserve `is_making` and taxa fields from DB through reparse; exclude taxa fields from diff. Added `making_classification` badge to Update Record credentials summary.

- [x] Family and Sub-Family dropdowns not populating in Update Record modal during reparse — `selectedFamily`/`selectedSubFamily` were initialized from parsed record (which doesn't produce family). Fixed to initialize from duplicate DB record in update mode.

- [x] MakingDetector classifying obvious Making laws as "Not Making" — e.g. UK_nisr_2000_388 "Management of Health and Safety at Work Regulations (Northern Ireland)" is a duty-setting regulation but MakingDetector says not_making. Fixed in v2.

- [ ] Family reparse as session — reparse all laws in a family as a batch, treating them like a scrape session with the same streaming parse + diff + confirm workflow. See design notes below.

## Completed

### Consolidate reparse (done)
- **Backend**: Added `parse_stream` SSE action to `UkLrtController` — streams real-time parse progress for existing records without creating a session. Removed `parse_preview` action and all its helpers (`parse_stages_param`, `compute_diff`, `normalize_value`, `build_update_attrs`, `format_stages`, `list_to_jsonb_map`). Removed `POST /api/uk-lrt/:id/parse-preview` route.
- **Frontend**: Added `parseRecordStream()` sessionless SSE client. Removed `parsePreview()`/`ParsePreviewResult`. Updated `ParseReviewModal` — sessionless branch in `parseCurrentRecord()`/`handleConfirm()`, removed entire read-mode codepath (~200+ lines). Updated `/admin/lrt` and `/admin/lat/queue` pages to pass `records[]` + `recordId` props.
- **Diff**: `RecordDiff` now excludes taxa fields from diff display (taxa managed by external Rust/Zenoh service).

### Taxa separation decision (in progress)
**Context**: Taxa parsing moved to external Rust service over Zenoh P2P. Three record states exist:
1. Legacy records — old Taxa parser data on DB (`is_making` set, `making_classification` null)
2. Newly parsed/reparsed — MakingDetector ran after metadata stage (`making_classification` set)
3. Updated by external service — authoritative taxa from Rust/Zenoh (`is_making` refreshed)

**DB state** (19,318 records): `is_making` true=3,334 / false=15,858 / null=126. `function["Making"]` perfectly in sync with `is_making`. `making_classification` = 0 records (never persisted yet).

**Decision**: Two fields, two concerns:
- `is_making` (boolean) — **authoritative**, set only by external Zenoh service (or legacy data). Preserved through reparse. Never overwritten by core parser.
- `making_classification` (string: making/not_making/uncertain) — **lightweight proxy**, always refreshed by MakingDetector after metadata stage 1. Used by Zenoh service to triage which laws need full-text taxa processing.
- `function` map — not touched during reparse. Calculated by `FunctionCalculator` at persist time from `is_making`.
- All taxa DB fields (role, duty_holder, purpose, popimar, etc.) — preserved through reparse, not overwritten.

### MakingDetector v2 (done)

**Problem**: Laws like "Management of Health and Safety at Work Regulations (Northern Ireland)" classified as `not_making` (0.173 = base rate) despite being duty-setting regulations. Zero signals fired.

**Root cause**: Three gaps in v1:
1. **No positive title signals** — only negative exclusions. "Regulations" in title (31.3% Making rate, 1.8x base) never checked.
2. **Tier 3 dead zone** — body paragraphs 6-50 produced no signal. 2,586 records with 39.8% Making rate got nothing.
3. **Tier 4 can't run** — `md_description` is nil for many records, so description analysis never triggers.

**Corpus analysis** (19,318 records):
| Title pattern (no exclusion) | Total | Making% |
|------------------------------|-------|---------|
| Regulations | 4,552 | 31.3% |
| Rules | 102 | 21.6% |
| Act | 1,243 | 20.0% |
| Order | 3,230 | 20.1% |
| Directive | 80 | 0% |
| Scheme | 49 | 2% |

**Changes** (v2):
- **Tier 2 positive signals**: `title_regulations` (confidence 0.55), `title_rules` (0.35) — only fire when no exclusion marker present
- **Tier 2 negative signals**: `title_directive` (0.85), `title_scheme` (0.70)
- **Tier 3 moderate body**: `moderate_body_paras` (11-50 paras, confidence 0.40) — fills the dead zone
- **Version bumped** to 2

**Result for UK_nisr_2000_388**: `not_making` (0.173) → `uncertain` (0.611). Two signals: `title_regulations` + `moderate_body_paras`. Correctly queued for AI analysis.

**Note**: Tier 4 description patterns could be improved with regex to handle "to make **further** provision for" — left as future work.

**Files**: `making_detector.ex` (version bump), `making_detector_signals.ex` (new signals), `making_detector_test.exs` (updated tests)

## Design: Family Reparse as Session

### Motivation
The parser is constantly improving. When stages improve (e.g. MakingDetector v2, better amendment detection), we need an efficient way to re-process families of laws already in the DB. Scrape sessions already provide an excellent workflow for this — streaming parse, diff review, confirm/save — but they only work for newly scraped laws. Extending this to existing DB records by family gives a controlled, documented reparse workflow.

### How scrape sessions work today
1. `POST /api/scrape` → fetches new laws from legislation.gov.uk, creates `ScrapeSession` + `ScrapeSessionRecord` rows
2. Session detail page (`/admin/scrape/sessions/[slug]`) shows records grouped by status (pending/parsed/confirmed)
3. "Review All" or "Auto Parse" opens `ParseReviewModal` with the session's records array
4. Modal parses one record at a time via SSE (`GET /api/sessions/:id/parse-stream?name=...`), shows stage progress, then diff
5. User confirms → record saved, modal advances to next record
6. Session tracks progress: `persisted_count` / total

### What "family reparse" adds
A new way to **create** a session — not from a scrape, but from existing DB records filtered by family. Once created, the session uses the exact same review workflow.

### Key design decisions

**Session naming convention**: No `type` field on `ScrapeSession` — distinguish by `session_id` prefix. Scrape sessions use date ranges (`2024-12-02-to-05`). Reparse sessions use `reparse-{family}-{date}` (e.g. `reparse-FIRE-2026-03-07`, `reparse-FIRE-uksi-making-2026-03-07`). The session list UI can detect the prefix to show a badge/label.

**Filters**: The creation dialog supports multiple filters combined:
- `family` (required) — e.g. FIRE, OH&S, CLIMATE CHANGE
- `family_ii` (optional) — sub-family refinement
- `type_code` (optional) — e.g. uksi, ukpga, nisr
- `function` (optional) — e.g. Making, Amending (keys from the `function` JSONB map)
- These combine as AND conditions. Session ID encodes the active filters for traceability.

**Session ID format**: `reparse-{family}[-{type_code}][-{function}]-{date}[-{seq}]`
- Examples: `reparse-FIRE-2026-03-07`, `reparse-FIRE-uksi-making-2026-03-07`, `reparse-OH&S-2026-03-07-2` (sequence suffix if duplicate)

**Reuse vs new UI**: Reuse the existing session detail page and `ParseReviewModal` entirely. The only new piece is the session creation step — a "Reparse Family" button on the LRT admin page that opens a dialog to pick family/sub-family/type_code/function, shows record count, and creates the session.

**Parse endpoint**: The existing `GET /api/sessions/:id/parse-stream?name=...` already works — it looks up the law by name and parses it. No new SSE endpoint needed. The session-based confirm endpoint also works since it saves parsed data via the session record.

**Stages**: `ParseReviewModal` already supports `stages?: ParseStage[]` for targeted reparsing (e.g. just metadata + amendments). The family reparse dialog could offer stage selection.

**Scale**: Some families have hundreds of records (FIRE has ~800+). Filters like `type_code` and `function` help narrow the set. Consider adding a "parse count" filter to prioritize records that haven't been reparsed recently.

### Implementation outline

1. **Backend**: New controller action `POST /api/sessions/reparse` — takes `{family, family_ii?, type_code?, function?}`, queries `uk_lrt` with combined filters, creates `ScrapeSession` + bulk-inserts `ScrapeSessionRecord` rows. Returns session object.
2. **Frontend**: "Reparse Family" button/dialog on LRT admin page — family picker, optional type_code dropdown, optional function tag filter (Making/Amending/etc.), record count preview, create button → navigates to session detail page.
3. **Session list**: Detect `reparse-` prefix in session ID to show "Reparse" badge alongside existing scrape sessions.

### What already works
- `ParseReviewModal` with records array + navigation + streaming parse + diff + confirm
- Session detail page with record list, status tracking, progress counts
- `parseOneStream` SSE endpoint (session-based)
- Confirm/save endpoint (session-based)

### What's new
- Session creation from DB query (not from scrape) with family + type_code + function filters
- Family reparse dialog on LRT admin page
- Session ID naming convention (`reparse-*`) to distinguish from scrape sessions

## Notes
- User will describe requirements one at a time
- Capture each as a todo, implement, iterate
- Taxa parsing removed from core stages (moved to external Zenoh service)
- Reparse consolidation: scrape session streaming UI is the gold standard, LRT admin should reuse it without creating sessions
