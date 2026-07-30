---
session: LRT→LAT Flow Improvements & LAT Parsing Skill
status: closed
opened: 2026-05-16
closed: 2026-05-16
---
# Title: LRT→LAT Flow Improvements & LAT Parsing Skill

**Started**: 2026-05-16T13:32:00Z

## Objectives
1. Better flow between LRT and LAT parsing (filter LAT queue by LRT session, show making_classification)
2. Create LAT parsing skill (analogous to lrt-scrape-session skill)

## Todo
- [x] Add LRT session filter to LAT queue view (`/admin/lat/queue`)
- [x] Show `making_classification` column in LAT queue (already existed)
- [x] Create LAT parsing skill (`.claude/skills/lat-parse-session/SKILL.md`)

## Notes
- LRT scrape skill exists at `.claude/skills/lrt-scrape-session/SKILL.md`
- LAT parse skill at `.claude/skills/lat-parse-session/SKILL.md`
- GridLite `in` operator: shotleybuilder/svelte-gridlite-kit#32 (core@0.7.0, adapter@0.8.0)
- Adapter `fn.where` doesn't work for live queries — used SQL-level collection rebuild instead
