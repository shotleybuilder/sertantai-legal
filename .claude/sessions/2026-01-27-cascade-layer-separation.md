# Title: Cascade Layer Separation

**Started**: 2026-01-27 15:46

## Problem Statement

When laws are parsed and confirmed:
- **Layer 0**: Initial scrape/parse of new laws
- **Layer 1**: Affected laws discovered from layer 0 confirmations (amending/rescinding/enacted_by references) — these get added to `cascade_affected_laws` and processed
- **Layer 2**: When layer 1 laws are confirmed, their affected laws get added back into the same `cascade_affected_laws` table as new pending entries

Layer 2 entries are indistinguishable from layer 1 entries. This creates a potentially infinite cascade where processing never completes — each confirmed law spawns more affected laws.

## Root Cause Analysis

### 1. `confirm` endpoint has no layer awareness (`scrape_controller.ex:710-730`)

The confirm endpoint unconditionally calls `Storage.add_affected_laws()` for every confirmed law, regardless of whether that law was itself a cascade entry:

```elixir
# After persisting, ALWAYS adds affected laws — no depth check
Storage.add_affected_laws(
  session_id, name,
  amending, rescinding, enacted_by_names
)
```

### 2. `cascade_affected_laws` table has no `layer` field

The schema (`cascade_affected_law.ex`) tracks `session_id`, `affected_law`, `update_type`, `status`, and `source_laws` — but has no concept of cascade depth/layer.

### 3. Deduplication masks the problem partially

The unique constraint `(session_id, affected_law)` prevents duplicate entries, so if a layer 2 law happens to already be in layer 1, it won't create a duplicate. But new layer 2 laws (not already in layer 1) get added as pending entries indistinguishable from layer 1.

### 4. Frontend shows a single flat list

`get_affected_laws_summary_from_db` returns all pending entries for a session with no layer distinction, so the user sees layer 1 and layer 2 entries mixed together.

## Design Decision: Layer Cap vs Infinite Cascade

**Recommended approach**: Add a `layer` integer field to `cascade_affected_laws`. When confirming a law that is itself a cascade entry at layer N, its affected laws are created at layer N+1. The frontend and backend can then:
- Process layers sequentially (finish layer 1 before showing layer 2)
- Allow a configurable max depth (e.g., stop at layer 2 or 3)
- Show layer info in the UI so users understand the cascade depth

## Todo

- [x] Add `layer` integer attribute to `cascade_affected_law.ex` resource (default: 1)
- [x] Generate and run Ash migration for the new column
- [x] Update `Storage.add_affected_laws/5` to accept a `layer` parameter
- [x] Update `scrape_controller.ex` confirm endpoint to determine the source law's layer and pass `layer + 1` to `add_affected_laws`
- [x] When confirming a cascade entry, look up its layer from `cascade_affected_laws` and propagate depth
- [x] Update `get_affected_laws_summary_from_db` to include layer info in response
- [x] Add read action `pending_for_session_and_layer` to filter by layer
- [x] Update frontend cascade panel to group/filter by layer
- [x] Add a max layer cap (e.g., layer 3) — beyond this, affected laws are recorded but not auto-queued as pending
- [ ] Test: confirm a layer 0 law creates layer 1 entries; confirm a layer 1 law creates layer 2 entries (not more layer 1)

## Key Files

| File | Role |
|------|------|
| `backend/lib/sertantai_legal/scraper/resources/cascade_affected_law.ex` | Schema — needs `layer` attribute |
| `backend/lib/sertantai_legal/scraper/storage.ex` (lines 352-430) | `add_affected_laws` + `upsert_cascade_entry` — needs layer param |
| `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex` (lines 683-765) | `confirm` endpoint — needs to determine and propagate layer |
| `frontend/src/lib/components/parse-review/` | Cascade panel UI — needs layer display/filter |

## Notes
- Continuing from previous work on cascade update form enhancements
- The unique constraint `(session_id, affected_law)` means a law can only appear once per session regardless of layer — if it was already added at layer 1, a layer 2 discovery won't duplicate it (good for dedup, but the layer should reflect the earliest/shallowest discovery)
- Consider: if a law appears at both layer 1 and layer 2, keep the lower layer number (it needs processing sooner)

**Ended**: 2026-01-27 16:05
**Committed**: d07ea66

## Summary
- Completed: 9 of 10 todos (manual integration test remaining)
- Files: cascade_affected_law.ex, storage.ex, scrape_controller.ex, cascade_controller.ex, scraper.ts, CascadeUpdateModal.svelte, cascade/+page.svelte, migration
- Outcome: Cascade entries now track depth via `layer` field. Confirm endpoint propagates layer+1. Max cap at layer 3 marks entries as `:deferred`. Frontend shows layer badges and breakdown.
- Next: Manual integration test to verify layer propagation end-to-end during a real scrape session
