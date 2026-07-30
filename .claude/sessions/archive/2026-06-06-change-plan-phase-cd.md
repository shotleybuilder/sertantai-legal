---
session: "Change Management — Phase C+D: Review UI Polish + Baserow Sync"
status: closed
opened: 2026-06-06
closed: 2026-06-06
---
# Title: Change Management — Phase C+D: Review UI Polish + Baserow Sync

**Started**: 2026-06-06 20:15
**Plan**: .claude/plans/change-management.md (Phase C + D + deferred)
**Ended**: 2026-06-06 21:30
**Commits**: `9379310`

## Todo
- [x] Categorised change queue on /app/changes (group by event type: repealed, new, amended)
- [x] "Add" decision wires into org_applicabilities (actually adds law to register)
- [x] "Archive" decision updates org_applicabilities status to excluded
- [x] "Keep"/"Dismiss" decisions log event but don't change register
- [x] 3 new tests: add→yes, archive→excluded, keep→no change
- [x] Post-scrape change summary generation (ChangeNotifier.generate_summaries)
- [x] Email notification stub — template + trigger (ChangeNotifier.build_email_body, notify_all)
- [ ] Baserow sync button: "Sync Updates" vs "Review Pending Changes" split → **Phase D session**
- [ ] Incremental sync with status field propagation (don't delete, update status) → **Phase D session**

## Notes
- Phase C complete: decisions wire into register, grouped view with toggle
- "archive" maps to existing `excluded` status (no new enum needed)
- status_before/after on decision events now reflects actual register change
- Frontend has grouped view (by event type) + flat view toggle
- Phase D deferred to its own session
