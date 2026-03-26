# Issue #56: Admin option to delete LAT rows for revoked/repealed laws

**Started**: 2026-03-26T09:35Z
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/56

## Todo
- [ ] Plan: explore codebase (admin/lrt views, LAT schema, zenoh publishing, function/status columns)
- [ ] New analytics view on ./admin/lrt for qualifying laws (status + function criteria)
- [ ] Columns: status, function, lat_count fields needed for review
- [ ] Per-row delete button (hidden when criteria not met: wrong status/function OR no LAT records)
- [ ] Filter: laws marked as possibly 'making' but full text parse showed no making function
- [ ] Backend: single-law LAT deletion endpoint (not bulk)
- [ ] Zenoh signal to trigger full-text deletion in parsing service
- [ ] Taxa/Fitness fields must remain unaffected by LAT deletion

## Notes
- One law at a time, not bulk
- Only delete LAT for: revoked/repealed laws, or laws falsely flagged as making
- Full text only carried for in-force making laws
