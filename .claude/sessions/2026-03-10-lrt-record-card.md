# LRT Record Card (Back of Card)

**Started**: 2026-03-10 20:08

## Todo
- [ ] Study ParseReviewModal to identify reusable record display logic
- [ ] Design RecordCard component (reusable, configurable modes)
- [ ] Implement RecordCard for LRT table row click → full record view
- [ ] Wire up row click on /admin/lrt to open RecordCard

## Notes
- Airtable pattern: table rows = metadata ("front"), click row = full record ("back of card")
- ParseReviewModal already shows record fields — reuse/extend as configurable component
- Start with LRT table, extend to LAT queue later

**Ended**: 2026-03-10 21:00
**Committed**: 5b549a0
