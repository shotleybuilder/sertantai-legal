# Title: Package taxa parser code & docs for Rust migration

**Started**: 2026-02-24 19:15

## Todo
- [x] Add ex_doc dependency to mix.exs
- [x] Configure ExDoc with taxa-focused groups (Pipeline, Definitions, Making Detection, LAT Parser)
- [x] Generate ExDoc documentation (HTML + llms.txt + epub)
- [x] Copy docs, source, and tests to ~/Documents/sertantai-data/taxa-migration/

## Notes
- Added `{:ex_doc, "~> 0.35", only: :dev}` to mix.exs
- Configured `docs/0` with 4 module groups: Taxa Pipeline, Taxa Definitions, Making Detection, LAT Parser
- Package at `~/Documents/sertantai-data/taxa-migration/` (9.8 MB):
  - `docs/` — 203 HTML files + epub (full ExDoc output)
  - `llms.txt` — flat text API docs for AI consumption
  - `source/taxa/` — 17 modules (~5,000 LOC)
  - `source/scraper/` — 6 files (taxa_parser, lat_parser, lat_persister, lat_reparser, commentary_parser, commentary_persister)
  - `tests/taxa/` — 12 test files

**Ended**: 2026-02-25
