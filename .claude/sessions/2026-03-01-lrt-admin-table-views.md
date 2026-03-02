# Issue #37: LRT admin page: migrate to svelte-table-views-tanstack + sidebar layout

**Started**: 2026-03-01
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/37

## Todo
- [x] Study /admin/lat/queue implementation as reference
- [x] Study current /admin/lrt page
- [x] Migrate LRT admin page to svelte-table-views-tanstack + sidebar
- [x] Test and verify (svelte-check 0 errors, lint clean on LRT)
- [ ] Consolidate 3 pages → 1 unified LRT admin page
- [x] Add LRT refresh (ParseReviewModal) to LAT Queue page
- [x] Queue page UX: stacked buttons, wrap title/family, Making-only function display, group by family
- [ ] **PARKED**: svelte-table-kit group row colspan — needs library-level fix (table-layout:fixed ignores colspan on body rows; edits to node_modules .svelte not picked up by Vite prebundle)

## Completed (Phase 1)
- Replaced ViewSelector with ViewSidebar + 4 view groups (16 default views)
- Added handleSidebarSelect, generic seedDefaultViews drift detection
- Restructured HTML to sidebar+content flex layout
- Removed unused imports (SavedView, ViewSelector)

---

## Three-Page Audit: Consolidation to One Unified LRT Admin

### Page Inventory

| Page | Route | Lines | Data Source | Table Lib | Key Feature |
|------|-------|-------|-------------|-----------|-------------|
| LRT Admin | `/admin/lrt` | ~1900 | Electric sync | TableKit + views + sidebar | Inline editing, ParseReviewModal, 16 views |
| LAT Queue | `/admin/lat/queue` | ~550 | REST (`/api/lat/queue`) | TableKit + views + sidebar | ReParse button, queue stats |
| LAT Data | `/admin/lat` | ~500 | REST (TanStack Query) | Custom HTML tables | Law list → LAT/annotation detail, reparse |

### Feature Matrix

| Feature | LRT | LAT Queue | LAT Data |
|---------|-----|-----------|----------|
| **Electric sync** | Yes | No (REST) | No (REST) |
| **TableKit** | Yes | Yes | No (custom tables) |
| **ViewSidebar** | Yes | Yes | No |
| **Saved views** | Yes (16 default) | Yes (3 default) | No |
| **Inline editing** | family, family_ii, function | No | No |
| **ParseReviewModal** | Yes (view + auto-reparse) | No | No |
| **ReParse button** | No (has Parse&Review modal) | Yes (per-row, REST) | Yes (per-law) |
| **Stats bar** | 4 cards (synced, status, filter, editing) | 3 cards (total, missing, stale) | 4 cards (rows, laws, annotations, law+ann) |
| **Column count** | 55+ | 10 | N/A (custom) |
| **LAT row detail** | No | No | Yes (tree-expandable + annotations tab) |
| **Search/filter** | Via TableKit column filters | Via TableKit column filters | Debounced text + type dropdown |
| **Pagination** | TableKit built-in | TableKit built-in | Manual "Load more" |
| **Grouping** | Disabled | Enabled (by family) | N/A |
| **Query invalidation** | No (Electric) | TanStack Query `['lat']` | TanStack Query (5 keys) |
| **Mobile sidebar** | Yes | Yes | No |

### Data Source Differences

1. **LRT Admin**: Electric sync via `getUkLrtCollection(where)` → `updateUkLrtWhere()`. Dynamic WHERE clause reacts to filter changes. Writes via REST PATCH `/api/uk-lrt/{id}`.

2. **LAT Queue**: REST `GET /api/lat/queue?limit=5000`. Returns `QueueItem` with queue-specific fields (`queue_reason`, `lat_count`, `lrt_updated_at`, `latest_lat_updated_at`). Not a subset of UkLrt — it's a JOIN view.

3. **LAT Data**: REST via TanStack Query hooks. Three-level drill-down: stats → law list → law detail (LAT rows + annotations). Completely different data model from UkLrt.

### Column Overlap

**Shared between LRT and LAT Queue:**
- `law_name` (LAT Queue) ≈ `name` (LRT)
- `title_en` — same
- `family` — same
- `live` — same
- `function` — same

**LAT Queue unique columns:**
- `queue_reason` (missing/stale)
- `lat_count`
- `lrt_updated_at`
- `latest_lat_updated_at`

**LAT Data is structurally different** — shows LAT rows (section_type, citation, text, depth) and annotations (code, type, text, source, affected_sections). Not column-compatible with LRT.

### Integration Path

#### What can merge into LRT Admin

1. **LAT Queue views → LRT sidebar views** (EASY)
   - LRT already has an "LAT Queue" default view with `is_making=true` + `live != revoked` filters
   - Add "Missing LAT" and "Stale LAT" as additional views in the Analysis group
   - Need: `queue_reason`, `lat_count`, `lrt_updated_at`, `latest_lat_updated_at` columns added to LRT
   - Challenge: These fields come from the queue JOIN, not the uk_lrt table. Options:
     - a) Add a backend endpoint to enrich UK LRT records with LAT queue metadata
     - b) Add these as computed/virtual columns in Electric shape (needs DB view or materialized view)
     - c) Client-side join: fetch queue data separately, merge into LRT records by name

2. **ReParse button → LRT actions column** (MEDIUM)
   - LRT already has an actions column with View + Parse&Review buttons
   - Add a third "Re-parse" button that calls `POST /api/lat/laws/:name/reparse`
   - Reuse `reparseMessage`/`reparseError` feedback pattern from LAT Queue
   - Parse&Review modal already does this but with preview — ReParse is the "just do it" variant
   - Could merge: Parse&Review = preview mode, ReParse = direct mode (same button, hold shift?)

3. **Queue stats** (EASY)
   - Add a conditional stats row that appears when LAT Queue view is active
   - Fetch `/api/lat/queue` for counts only (or add a `/api/lat/queue/stats` lightweight endpoint)
   - Show total/missing/stale counts above table

4. **LAT row detail + annotation browsing** (HARD — keep separate or use modal)
   - LAT Data page shows a tree-expandable LAT structure and annotations tab
   - This is fundamentally different UI from a flat table
   - Options:
     - a) Open LAT detail in a new modal from LRT table (like ParseReviewModal but showing LAT structure)
     - b) Keep `/admin/lat` as a detail page, link from LRT actions column
     - c) Add an expandable row detail panel in TableKit (if supported)
   - Recommendation: **Add a "LAT" action button in LRT** that opens a modal or navigates to `/admin/lat?law=<name>`

#### What should stay separate (or become modal/detail)

- **LAT row tree view**: The depth-indented, expandable LAT structure is too different from flat table to merge inline. Best as a modal or linked page.
- **Annotation detail tab**: Same — better as detail view, not inline columns.
- **TanStack Query infrastructure**: LAT Data uses TanStack Query hooks extensively. LRT uses Electric. Mixing them in one page adds complexity but is feasible for the queue stats fetch.

#### Proposed Unified LRT Admin

```
/admin/lrt (unified)
├── ViewSidebar
│   ├── Credentials & Dates (5 views)
│   ├── Classification (4 views) 
│   ├── Holders (4 views)
│   ├── Analysis (3 views + LAT Queue views)
│   │   ├── POPIMAR
│   │   ├── Purpose
│   │   ├── LAT Queue (All)      ← from /admin/lat/queue
│   │   ├── LAT Queue (Missing)  ← from /admin/lat/queue  
│   │   └── LAT Queue (Stale)    ← from /admin/lat/queue
│   └── User-created views
├── Stats Bar (context-sensitive)
│   ├── Default: synced records, sync status, filter, editing
│   └── LAT Queue views: total queue, missing, stale + sync stats
├── TableKit (55+ columns)
│   ├── actions column: View | Parse&Review | Re-parse | LAT Detail
│   ├── Existing LRT columns (all 55+)
│   ├── + queue_reason column (new)
│   ├── + lat_count column (new)  
│   ├── + lrt_updated_at column (new)
│   └── + latest_lat_updated_at column (new)
├── Inline editing (family, family_ii, function)
├── ParseReviewModal (existing)
├── SaveViewModal (existing)
└── LAT Detail Modal (new — tree view + annotations)
```

#### Pages to deprecate after consolidation
- `/admin/lat/queue` → views + reparse merged into LRT
- `/admin/lat` → becomes LAT Detail Modal or lightweight linked page

#### Key Technical Decisions Needed

1. **Queue data enrichment**: How to get `queue_reason`, `lat_count` etc. into LRT table rows?
   - Best option: client-side lookup map (fetch queue once, index by law_name, enrich)
   - Avoids DB schema changes, works with existing Electric sync

2. **LAT detail UI**: Modal or separate page?
   - Modal keeps single-page UX, but LAT tree view is complex
   - Separate page is simpler but breaks the "one page" goal

3. **Stats bar**: Static or context-sensitive?
   - Context-sensitive (different stats for queue views) is better UX
   - Needs view-change detection to swap stat cards

4. **Re-parse vs Parse&Review**: Merge or keep both?
   - Parse&Review shows diff before saving (careful mode)
   - Re-parse fires immediately (fast mode)
   - Both useful — keep as separate action buttons

5. **LAT Queue data source**: REST fetch on every page load is slow (seconds). Should migrate to Electric sync or client-side computation from already-synced uk_lrt data + lightweight LAT stats lookup.

**Ended**: 2026-03-02
