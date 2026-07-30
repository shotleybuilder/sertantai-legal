---
session: "Change Management — Phase A: Change Detection"
status: closed
opened: 2026-06-06
closed: 2026-06-06
---
# Title: Change Management — Phase A: Change Detection

**Started**: 2026-06-06 17:00
**Plan**: .claude/plans/change-management.md (Phase A)
**Ended**: 2026-06-06 18:30
**Commits**: `cb9c7c5`, `8bf7f98`

## Todo
- [x] New event types + columns on applicability_events (materiality, decision, decision_reason, review_due_date)
- [x] New read actions: pending_changes, overdue_reviews
- [x] ChangeDetector module — detect_status_changes, detect_new_laws, detect_score_changes
- [x] Auto trigger on scrape session completion (scrape_controller + session_manager)
- [x] TaxaSubscriber hook — notify_enrichment_change on enrichment for register laws
- [x] Mix task: mix sync.detect_changes (manual/ad-hoc)
- [x] Materiality auto-classification (Major/Moderate/Minor/Informational)
- [x] Tests (18 tests, 0 failures)

## Notes
- Tested against dev DB: QQ 112 status changes, test org 29 status + 18 new laws
- Idempotent: second run produces 0 events (NOT EXISTS dedup)
- TaxaSubscriber dedup uses 1-hour window to avoid spam during batch enrichment
