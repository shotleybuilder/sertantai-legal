# Title: Customer Onboarding Phase 2 — Data Quality for Matched Laws

**Started**: 2026-06-02 17:00
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 2)

## Todo
- [x] 2.1 — Fix parser family assignment (#84) — d43af62
- [x] 2.2 — Add missing SI code → family mappings (#85) — fea7264
- [ ] 2.3 — EU law family assignment (#86)
- [ ] 2.4 — Confirm making classification coverage
- [ ] 2.5 — Parse LAT where missing (import-qq-bsc session)

## Notes
- Phase 1 complete: 670 matched, 239 scraped, 32 not handled
- #84: StagedParser now calls si_code_family after metadata stage; confirm endpoint guards nil family override
- #85: Only WEIGHTS AND MEASURES needed mapping; 6 ambiguous admin codes (LOCAL GOVT etc.) not EHS-deterministic
