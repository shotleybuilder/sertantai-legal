# Title: LRT→LAT Flow Improvements & LAT Parsing Skill

**Started**: 2026-05-16T13:32:00Z

## Objectives
1. Better flow between LRT and LAT parsing (filter LAT queue by LRT session, show making_classification)
2. Create LAT parsing skill (analogous to lrt-scrape-session skill)

## Todo
- [x] Add LRT session filter to LAT queue view (`/admin/lat/queue`)
- [x] Show `making_classification` column in LAT queue (already existed)
- [ ] Create LAT parsing skill (`.claude/skills/lat-parse-session.md`)

## Notes
- LRT scrape skill exists at `.claude/skills/lrt-scrape-session.md`
- LAT queue: http://localhost:5175/admin/lat/queue
- LRT sessions: http://localhost:5175/admin/scrape/sessions
- Only "making" laws get LAT parsing
- GridLite `in` operator: shotleybuilder/svelte-gridlite-kit#32 (implemented in core@0.7.0, adapter@0.8.0)
- Adapter `fn.where` doesn't work for live queries — used SQL-level collection rebuild instead
