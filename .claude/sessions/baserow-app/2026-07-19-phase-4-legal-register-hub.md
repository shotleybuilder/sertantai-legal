# Legal Register Hub — Phase 4

**Started**: 2026-07-19 12:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Reverted Assessment Queue page to original (was wrongly repurposed)
- [x] Create Legal Register page from LRT table (page 1071076, DS 1955715)
- [x] Table columns: Title, Year, Family, Status, Significance + Assessment/Actions links
- [x] Legal Register set as home page (`/`), Assessment Queue moved to `/assess-queue`
- [x] Published
- [ ] Set link text: "Assess →" and "Actions →" in UI
- [ ] Assessment link param — needs to resolve LRT→Assessment row ID via reverse link
- [ ] CSS styling
- [ ] Final re-publish

## Design Change
Original plan was to repurpose the Assessment Queue. Wrong approach — the Legal Register
is a different data source (LRT table, not Assessments table). The Assessment and Actions
pages remain as-is, linked FROM the Legal Register hub.

## Notes
- LRT table: 1079905 — has Title (9565190), Year (9565192), Family (9565191), Status (9565195)
- Need to link LRT rows to their Assessment rows and Action rows
- Created Law_Title (9627030) and Law_Year (9627031) lookup fields on Assessments table — may still be useful
