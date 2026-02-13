# Title: Improved Parsing Feedback

**Started**: 2026-01-21 16:23
**Issue**: None (standalone session)

## Goal
Stream real-time parse stage progress to the UI during enrichment parsing, replacing the static "Fetching metadata from legislation.gov.uk" message with live updates.

## Current State
- Backend: `StagedParser.parse()` logs rich progress via `IO.puts` (6 stages with status)
- Frontend: Single HTTP request with spinner, no progress visibility
- Parse takes 10-30+ seconds with no user feedback

## Architecture Decision
**Use Server-Sent Events (SSE)** - simpler than WebSockets for one-way streaming

## Todo

### Backend
- [x] Create progress callback mechanism in `StagedParser.parse/2`
- [x] Add new SSE endpoint `GET /api/sessions/:id/parse_stream`
- [x] Stream stage start/complete events as JSON lines
- [x] Return final result as last event

**Commit**: `99bc890` - feat(backend): Add SSE parse progress streaming

### Frontend
- [x] Create `parseOneStream()` using EventSource API
- [x] Add progress state to `ParseReviewModal.svelte`
- [x] Display stage progress (name, status, summary) during parse
- [x] Handle SSE connection errors gracefully
- [x] Fallback to existing non-streaming endpoint if SSE fails

**Commit**: `7f271f1` - feat(frontend): Add streaming parse progress UI

### UI Design
Progress display during parse:
```
Parsing UK_uksi_2025_568...

[✓] Metadata: 1 SI codes, 0 subjects
[✓] Extent: UK
[✓] Enacted by: 1 parent law(s)
[⟳] Amendments...          <- current stage with spinner
[ ] Repeal/Revoke
[ ] Taxa Classification
```

**Commit**: `a3a9fa9` - test: Add unit tests for progress callback mechanism

### Parse Error Handling
- [x] Investigate displaying likely/known parser errors to UI

## Likely Parser Failure Scenarios

### 1. Network/Service Failures

| Error | Stage(s) Affected | Current Error Message | User-Friendly Message |
|-------|-------------------|----------------------|----------------------|
| **legislation.gov.uk unavailable** | All | `Request failed: %Req.TransportError{reason: :econnrefused}` | "Unable to connect to legislation.gov.uk. The service may be temporarily unavailable." |
| **Request timeout** | All | `Request failed: %Req.TransportError{reason: :timeout}` | "Request timed out. legislation.gov.uk may be slow or unresponsive." |
| **DNS resolution failure** | All | `Request failed: %Req.TransportError{reason: :nxdomain}` | "Unable to resolve legislation.gov.uk. Check your network connection." |
| **SSL/TLS error** | All | `Request failed: %Mint.TransportError{reason: :closed}` | "Secure connection failed. Try again in a moment." |

### 2. HTTP Error Responses

| Error | Stage(s) Affected | Current Error Message | User-Friendly Message |
|-------|-------------------|----------------------|----------------------|
| **404 Not Found** | metadata, extent, enacted_by, amendments | `HTTP 404: Not found: /uksi/2024/999/introduction/data.xml` | "Law not found on legislation.gov.uk. It may have been removed, renumbered, or not yet published." |
| **307 Temporary Redirect** | extent | `HTTP 307: Temporary redirect` | "Law has moved. Try refreshing the page." |
| **429 Too Many Requests** | All | `HTTP 429: Too Many Requests` | "Rate limited by legislation.gov.uk. Please wait a moment and try again." |
| **500 Server Error** | All | `HTTP 500: Internal Server Error` | "legislation.gov.uk is experiencing issues. Try again later." |
| **503 Service Unavailable** | All | `HTTP 503: Service Unavailable` | "legislation.gov.uk is temporarily unavailable for maintenance." |

### 3. Data/Parsing Failures

| Error | Stage(s) Affected | Current Error Message | User-Friendly Message |
|-------|-------------------|----------------------|----------------------|
| **Received HTML instead of XML** | metadata, extent, enacted_by | `Received HTML instead of XML` | "Unexpected response format. The law may not be available in machine-readable format." |
| **XML parse error** | metadata, extent | `XML parse error: {:error, "..."}` | "Unable to parse law data. The format may have changed." |
| **Missing required fields** | metadata | (various) | "Law is missing expected metadata fields." |
| **No extent data** | extent | `No extent found` | "Geographic extent not specified for this law." |

### 4. Stage-Specific Failures

| Stage | Likely Failure | User-Friendly Message |
|-------|---------------|----------------------|
| **Metadata** | Old/draft legislation missing introduction XML | "Metadata not available. This may be draft or historical legislation." |
| **Extent** | Welsh/Scottish-only laws with different XML structure | "Extent data unavailable. Manual review may be needed." |
| **Enacted By** | Primary legislation (Acts) - not an error | "Primary legislation - not enacted by other laws." (shown as info, not error) |
| **Amendments** | Large amendment tables timing out | "Amendment data incomplete. This law has extensive amendment history." |
| **Repeal/Revoke** | No resources.xml file | "Revocation status unknown. Assuming in force." (shown as warning) |
| **Taxa** | Empty law text (title-only instruments) | "Unable to classify. Law body is empty or too short." |

### 5. Current UI Error Display

The current implementation shows errors in two places:
1. **During parsing**: Stage shows red X with error message in summary column
2. **After parsing**: Error list displayed in red box above record details

**Current stage error display** (ParseReviewModal.svelte:282-290):
```svelte
{:else if parseError || $parseMutation.isError}
  <div class="rounded-md bg-red-50 p-4">
    <p class="text-sm text-red-700">{parseError || $parseMutation.error?.message}</p>
  </div>
```

**Current stage summary errors** (ParseReviewModal.svelte:307-315):
```svelte
{#if parseResult.errors.length > 0}
  <div class="mt-3 text-sm text-red-600">
    <strong>Errors:</strong>
    <ul class="list-disc list-inside mt-1">
      {#each parseResult.errors as error}
        <li>{error}</li>
```

### 6. Recommendations for Future Enhancement

- [x] **P1: Error Message Mapping** - Create `mapParseError()` in scraper.ts to convert technical errors to user-friendly messages
- [x] **P2: Partial Success Handling** - Allow confirming records when some stages fail; show succeeded vs failed stages
- [x] **P3: Retry Mechanism** - Add "Retry Failed Stages" button to re-run only failed stages
- [ ] **P4: Offline Detection** - Check `navigator.onLine` before parsing; show "You appear to be offline"
- [ ] **P5: Service Health Check** - Ping legislation.gov.uk before batch parsing; warn if slow/unavailable

**Commits**:
- `8b69fa1` - feat(frontend): Add user-friendly error message mapping
- `f509ff1` - feat(frontend): Add partial success handling for parser errors
- `b7884a8` - feat: Add retry mechanism for failed parser stages

## Key Files
- `backend/lib/sertantai_legal/scraper/staged_parser.ex:67-72` - Progress event types
- `backend/lib/sertantai_legal/scraper/staged_parser.ex:210-251` - Progress helpers
- `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex:442-552` - SSE endpoint
- `frontend/src/lib/api/scraper.ts:523-644` - Error message mapping functions
- `frontend/src/lib/api/scraper.ts:645-725` - SSE client types and function
- `frontend/src/lib/components/ParseReviewModal.svelte:36-160` - Progress state and streaming

## Notes
- SSE chosen over WebSocket: simpler, sufficient for one-way progress
- Keep existing `parse_one` endpoint as fallback
- Stage summaries extracted from existing log output patterns
- Progress UI shows: spinner for running, checkmark for ok, X for error, circle for pending

**Ended**: 2026-01-21 18:45
