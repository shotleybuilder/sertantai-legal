# Title: Hook up Enrichment Parser to Performance Metrics

**Started**: 2026-01-29
**Related**: Issue #11 (Telemetry/Metrics implementation)

## Todo
- [x] Identify parser telemetry events to capture
- [x] Add telemetry to StagedParser (per-stage and overall timing)
- [x] Update TelemetryHandler to capture new events
- [x] Test metrics collection

## Notes
- Building on metrics system from 2026-01-28-issue-11.md
- StagedParser is the main parsing pipeline (7 stages)
- TaxaParser already had telemetry - now StagedParser has it too

## Events Added
- `[:staged_parser, :parse, :complete]` - Full parse with per-stage timing breakdown
- `[:staged_parser, :stage, :complete]` - Individual stage timing

## Files Modified
- `lib/sertantai_legal/scraper/staged_parser.ex` - Added telemetry emission
- `lib/sertantai_legal/metrics/telemetry_handler.ex` - Capture new events

## Commit
- f87dbb8 - feat(metrics): Add telemetry to StagedParser for parse performance tracking

---

## Issue: Missing law_name in Taxa telemetry

The Taxa telemetry event doesn't include the law name - only `source: "body"`.
This makes it impossible to track performance improvement for specific laws.

**Current state**:
- `[:staged_parser, :parse, :complete]` - ✅ Has `law_name` in metadata
- `[:staged_parser, :stage, :complete]` - ✅ Has `law_name` in metadata  
- `[:taxa, :classify, :complete]` - ❌ Missing `law_name` (only has `source`)

**Root cause**: `TaxaParser.classify_text/2` only receives `text` and `source`.
The law identifier is in `TaxaParser.run/3` but not passed to telemetry.

## Todo (Reopened)
- [x] Add law_name to TaxaParser telemetry metadata
- [x] Pass law identifier through classify_text or emit from run/3
- [x] Test and verify metrics include law_name
- [x] Commit and push (dde5bdd)

---

**Ended**: 2026-01-29
