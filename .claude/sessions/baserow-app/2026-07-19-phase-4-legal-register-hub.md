# Legal Register Hub — Phase 4

**Started**: 2026-07-19 12:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Reverted Assessment Queue page to original (was wrongly repurposed)
- [x] Create Legal Register page from LRT table (page 1071076, DS 1955715)
- [x] Table columns: Title, Year, Family, Status, Significance, Assessment Status
- [x] Legal Register set as home page (`/`), Assessment Queue moved to `/assess-queue`
- [x] Assessment_Status lookup field created on LRT table (9627086)
- [x] Emoji compliance statuses on Assessments table (✅⚠️❌⬜➖)
- [x] Assessment Status column working with single-quote formula
- [x] Assess link → Assessment Form (/assess/:id) with correct row ID via reverse link
- [x] Actions link removed (two-hop — deferred to Phase 5)
- [x] Assess link text set in UI
- [x] Published
- [ ] CSS styling — deferred, needs QQ branding guidelines (deferred)

## Design Change
Original plan was to repurpose the Assessment Queue. Wrong approach — the Legal Register
is a different data source (LRT table, not Assessments table). The Assessment and Actions
pages remain as-is, linked FROM the Legal Register hub.

## Notes
- LRT table: 1079905
- Assessment_Status lookup: field 9627086 (through Assessments reverse link 9564709, target Compliance_Status 9564710)
- Assess link uses: `get('current_record.field_9564709.0.id')` — first Assessment row ID
- Single quotes required in App Builder formulas for complex paths like `.*.value.value`
- Created Law_Title (9627030) and Law_Year (9627031) lookup fields on Assessments table
