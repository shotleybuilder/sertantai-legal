# Issue #56: Admin option to delete LAT rows for revoked/repealed laws

**Started**: 2026-03-26T09:35Z
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/56

## Todo
- [x] Plan: explore codebase (admin/lrt views, LAT schema, zenoh publishing, function/status columns)
- [x] New analytics view on ./admin/lrt for qualifying laws (status + function criteria) — LAT Cleanup view
- [x] Columns: status, function, lat_count fields needed for review
- [x] Per-row delete button (hidden when criteria not met: wrong status/function OR no LAT records)
- [x] Filter: laws marked as possibly 'making' but full text parse showed no making function
- [x] Backend: single-law LAT deletion endpoint (not bulk) — `DELETE /api/lat/laws/:law_name/data`
- [x] Zenoh signal to trigger full-text deletion in parsing service — `ChangeNotifier.notify("lat", "lat_deleted", ...)`
- [x] Taxa/Fitness fields must remain unaffected by LAT deletion — verified

## Notes
- One law at a time, not bulk
- Only delete LAT for: revoked/repealed laws, or laws falsely flagged as making
- Full text only carried for in-force making laws

**Reopened**: 2026-03-27 — #60 blocker resolved, resuming LAT deletion work
- E2E verified: UK_uksi_2010_768 (878 LAT rows) deleted via admin UI, Zenoh signal received by fractalaw, local LAT deleted on both sides
- Spec doc created: `data/ZENOH-LAT-DELETION-SIGNAL.md`
- Additional admin views added: Unparsed, Revoked (Unverified)

**Ended**: 2026-03-27T13:00Z
