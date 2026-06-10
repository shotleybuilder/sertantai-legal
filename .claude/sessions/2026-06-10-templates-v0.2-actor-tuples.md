# Title: Templates v0.2 — Actor Tuple Table for Baserow

**Started**: 2026-06-10 00:30
**Plan**: .claude/plans/baserow-compliance-templates.md

## Todo
- [ ] Build Actor Tuples table — one row per (actor, position, drrp_type) from corpus
- [ ] Seed tuples from actual actors struct data (canonical only, governed only for QQ)
- [ ] LAT table: replace Regulated Actors multi-select with link_row → Actor Tuples (many-to-many)
- [ ] Sync engine: create tuples table, link LAT rows to matching tuples
- [ ] Verify "Employer Duties" query works in Baserow
- [ ] Row count check: must stay under 3K free tier

## Notes
- 592 total tuples in QQ corpus, fewer without government actors
- Tuple = (actor label, position, drrp_type) — governed list of valid combinations
- Many-to-many: LAT provision links to multiple Actor Tuple rows
- Replaces flat Regulated Actors multi-select — preserves actor↔DRRP relationship
- Works for Airtable too (linked records are the same pattern)
- ChatGPT's tuple table pattern: sweet spot for <few thousand valid combinations
