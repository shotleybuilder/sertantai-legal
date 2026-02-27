# Title: Arrow IPC format negotiation for DataServer

**Started**: 2026-02-27
**Ended**: 2026-02-27

## Todo
- [x] Add Arrow IPC response to DataServer `*/lat/{name}` queryable
- [x] Query parameter negotiation: default Arrow IPC, `?format=json` for JSON
- [x] Keep existing JSON serialization as fallback
- [x] Update `*/lrt/*` and `*/amendments/*` similarly
- [x] Compile + type check

## Notes
- Spec saved at `data/ZENOH-LAT-ARROW-IPC.md`
- JSON spec at `data/zenoh-dataserver-spec.md`
- Explorer already a dependency (used by TaxaSubscriber)
- `Zenohex.Query.parameters` field used for `?format=json` negotiation
- `parse_format/1` defaults to `:arrow`, returns `:json` if params contain `format=json`
- LRT Arrow excludes JSONB map fields (duty_holder, function, etc.) — not representable in flat Arrow columns
- Amendments Arrow excludes `affected_sections` (array of strings) for same reason
- Empty result sets return `<<>>` (0 bytes) — fractalaw treats as "no data"
- Integer columns cast to `{:s, 32}` via `cast_columns/3` helper (Explorer.Series.cast)
- `Explorer.DataFrame.mutate` macro doesn't work outside require context — used Series.cast directly
