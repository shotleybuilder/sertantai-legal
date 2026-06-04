# Title: 4.11 Goldilocks Model — Provision-Level Aggregation for Baserow LAT

**Started**: 2026-06-04 01:30
**Meta-plan**: .claude/plans/customer-onboarding.md (4.11)

## Todo
- [ ] Design the aggregation query (GROUP BY provision, concat text, union actors)
- [ ] Prototype with PUWER 1998 (reg.32 fragmentation example)
- [ ] Measure: how many rows does aggregation produce vs current 2,386?
- [ ] Implement in ProfileQuery or as a materialised view
- [ ] Also bundle quick wins: 4.12 (drop Duty Summary), DRRP Duty-only filter
- [ ] Re-sync Baserow with aggregated LAT

## Notes
- Current: each sub_article is a row → 2,386 rows, fragmented duties
- Target: one row per provision (regulation/section) with full text + DRRP
- Example: PUWER reg.32 has 6 sub_article rows → should be 1 aggregated row
- clause_refined is redundant (echoes text) → drop from sync
- QQ is commercial → Duty only, not Responsibility (saves 857 rows)

**Ended**: 2026-06-04 02:30
**Commits**: `fb00a30`, `51e53b3`, `3fb8598`
