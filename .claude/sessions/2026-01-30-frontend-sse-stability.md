# Frontend SSE Stability for Large Law Parsing

**Started**: 2026-01-30T07:25:00Z
**Related**: Taxa Parser optimization (Issue #10)

## Problem
Parse completes successfully on backend (38s for ukpga/2008/29) but frontend shows "Lost connection during parsing" error. The SSE connection drops during long parses because no events are sent during the Taxa stage (10+ seconds).

## Root Cause
During long-running parse stages (especially Taxa), the controller was running the parser synchronously. No SSE events were sent for 10+ seconds, causing browser/proxy timeouts.

## Solution
**Commit**: 0f9fca9

Implemented SSE heartbeat keepalive:
1. Parser now runs in a separate `Task`
2. Controller loops receiving parser events with 5-second timeout
3. On timeout, sends SSE comment (`: heartbeat\n\n`) as keepalive
4. SSE comments are ignored by clients per spec but keep connection alive

## Todo
- [x] Investigate SSE timeout/keepalive issues
- [x] Add SSE keepalive heartbeat during long parses
- [ ] Test with large law parsing (ukpga/2008/29)

## Files Modified
- `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex`
  - Added `@sse_heartbeat_interval 5_000`
  - Added `sse_event_loop/4` - receives parser events or sends heartbeats
  - Added `send_parse_complete/4` - sends final result
  - Modified `parse_stream/2` to run parser in Task and use event loop

## Technical Details
- Heartbeat interval: 5 seconds
- Heartbeat format: `: heartbeat\n\n` (SSE comment, ignored by EventSource)
- Parser progress events forwarded via message passing to controller process

---

## Investigation: Async Stage Execution

### Current Architecture
Stages run sequentially via `Enum.reduce_while/3`:
```
metadata → extent → enacted_by → amending → amended_by → repeal_revoke → taxa
```

### Stage Dependencies Analysis

| Stage | Input Dependencies | Output Used By |
|-------|-------------------|----------------|
| **metadata** | `existing_record` (initial) | None - standalone |
| **extent** | None - uses type_code/year/number only | None - standalone |
| **enacted_by** | None - uses type_code/year/number only | None - standalone |
| **amending** | None - uses type_code/year/number only | None - standalone |
| **amended_by** | None - uses type_code/year/number only | `repeal_revoke` (live status reconciliation) |
| **repeal_revoke** | `amended_by.live_from_changes` (reconciliation) | None after reconciliation |
| **taxa** | None - uses type_code/year/number only | None - standalone |

### Key Findings

1. **Most stages are independent**: `metadata`, `extent`, `enacted_by`, `amending`, and `taxa` only need `type_code/year/number` - they don't depend on results from other stages.

2. **One dependency exists**: `repeal_revoke` needs `amended_by` results for live status reconciliation (comparing `live_from_changes` vs `live_from_metadata`).

3. **metadata uses `existing_record`**: But this is the INPUT record, not accumulated results from other stages. It's used to protect `title_en` from being overwritten.

### Parallelization Opportunities

**Group 1 - Fully Independent (can run in parallel):**
- `metadata`
- `extent`
- `enacted_by`
- `amending`
- `taxa` (slowest - 10+ seconds for large laws)

**Group 2 - Sequential Dependency:**
- `amended_by` → `repeal_revoke` (must run in order for reconciliation)

### Recommended Architecture

```
                    ┌─────────────┐
                    │   START     │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┬─────────────────┐
        ▼                  ▼                  ▼                 ▼
   ┌─────────┐       ┌─────────┐       ┌───────────┐      ┌─────────┐
   │metadata │       │ extent  │       │enacted_by │      │amending │
   └────┬────┘       └────┬────┘       └─────┬─────┘      └────┬────┘
        │                 │                  │                 │
        │                 │                  │                 │
        └────────────────┬┴──────────────────┴─────────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │    taxa     │  ← Can also run in parallel with Group 1
                  └──────┬──────┘
                         │
        ┌────────────────┴────────────────┐
        ▼                                 │
   ┌───────────┐                          │
   │amended_by │                          │
   └─────┬─────┘                          │
         │                                │
         ▼                                │
  ┌──────────────┐                        │
  │repeal_revoke │                        │
  └──────┬───────┘                        │
         │                                │
         └────────────────┬───────────────┘
                          ▼
                    ┌─────────┐
                    │  MERGE  │
                    └─────────┘
```

### Performance Impact Estimate

**Current (sequential):**
- Total time ≈ sum of all stages
- For ukpga/2008/29: ~38 seconds

**With parallelization:**
- Group 1 parallel: max(metadata, extent, enacted_by, amending, taxa) ≈ taxa time (~10s)
- Group 2 sequential: amended_by + repeal_revoke (~5s combined)
- **Estimated total: ~15 seconds** (60% reduction)

### Implementation Considerations

1. **Progress Events**: Need to handle out-of-order stage completion for SSE events. Could:
   - Send events as stages complete (out of order)
   - Buffer and send in order
   - Send with sequence numbers

2. **Error Handling**: If one parallel stage fails, others can continue. Current `skip_on_error` option would need rethinking.

3. **Resource Usage**: Parallel HTTP requests to legislation.gov.uk - may need rate limiting to avoid being blocked.

4. **Complexity**: Adds significant complexity to the parser. Current sequential model is simpler to reason about and debug.

### Recommendation

**Short term**: Keep the heartbeat fix (already implemented). This solves the immediate SSE timeout issue.

**Medium term**: Consider parallelizing only the `taxa` stage since it's the slowest and has no dependencies. Run it in parallel with the sequential chain:
```
(metadata → extent → enacted_by → amending → amended_by → repeal_revoke) || taxa
```
This would reduce total time from ~38s to ~28s without major architectural changes.

**→ Created Issue #13**: [Staged Parser: Parallel Taxa Execution for Large Law Performance](https://github.com/shotleybuilder/sertantai-legal/issues/13)

**Long term**: Full parallel execution of independent stages if further performance gains needed.

**Ended**: 2026-01-30T07:32:29Z
