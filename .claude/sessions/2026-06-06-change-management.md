# Title: Change Management — New Laws, Updates, Repeals + Sync

**Started**: 2026-06-06 15:30
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 6 sync, 7.7 remaining)

## Todo
- [x] Map out change scenarios (new law, repeal, amendment, status change, family change, etc.)
- [x] Design: how changes surface to users (notifications? queue? dashboard?)
- [x] Design: sync behaviour per scenario (auto-propagate vs user-confirm)
- [x] Design: Baserow sync strategy (update in place vs flag vs remove)
- [x] Plan document at .claude/plans/
- [ ] External review and feedback iteration

## Notes
- Change = monthly scrape session picks up new/amended/repealed laws
- Scenarios are complex: repeal could mean remove OR just update status
- Customer has enrichment in Baserow they don't want to lose
- New laws need applicability screening — auto-screener helps but human review needed
- This is the bridge between admin scraping and customer-facing screening
- 5 categories mapped: law status, new laws, amendments/metadata, profile changes, Baserow sync
- Design principles: never auto-delete from Baserow, surface don't impose, change is an event, sync is conscious
- Plan ready for sharing at .claude/plans/change-management.md
