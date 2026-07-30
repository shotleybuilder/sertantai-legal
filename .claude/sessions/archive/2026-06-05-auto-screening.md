---
session: AI-Seeded Register from Org Profile
status: closed
opened: 2026-06-05
closed: 2026-06-05
---
# Issue #102: AI-Seeded Register from Org Profile

**Started**: 2026-06-05 21:00
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/102
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 8)

## Todo
- [x] Review #102 + meta-plan Phase 8 → draft plan at .claude/plans/auto-screening.md
- [x] Share plan for feedback (3 rounds: user, Gemini x2, ChatGPT)
- [x] Iterate based on feedback (scored matching, deprecation, governance)
- [ ] Implementation (Phase 8a-8d)

## Notes
- Phase 7 (manual screening UI) is MVP complete
- Fitness coverage: 44% EU, ~50% UK domestic
- Existing: OrgApplicability with source enum (enhesa_import/manual/screener)
- Fractalaw Tier 1: +8,648 DRRP provisions, 202/274 QQ laws now have duties (8,739 entries)
- NAS snapshot exported with new enrichment data (215K LAT rows)

**Ended**: 2026-06-06 00:00
**Commits**: (plan only, no code changes)

## Summary
- Completed: 1 of 4 todos (draft plan created, reviewed externally, iterated)
- Files: .claude/plans/auto-screening.md
- Outcome: Comprehensive auto-screening plan with 3 rounds of external review (user feedback, Gemini x2, ChatGPT). Scored matching, deprecation preview, explainability, governance guidelines all captured. Fractalaw Tier 1 landed 8,648 new DRRP provisions.
- Next: Implementation of Phase 8a-8d. Pre-implementation checklist in plan.
