# Title: 4.9 — Enhesa Data Quality Report for QQ Management

**Started**: 2026-06-05 10:15
**Meta-plan**: .claude/plans/customer-onboarding.md (4.9)

## Artifacts

1. **Confusion Matrix** — TP/FP/TN/FN grid with summary numbers + appendix of each law
2. **Revoked Law Report** — Enhesa Yes laws that are revoked/repealed (wasted compliance effort)
3. **Coverage Gap Report** — Making laws in QQ's families not in Enhesa register
4. **Family Distribution** — obligation count by domain (OH&S vs Env vs HR)
5. **Duty Density** — top laws by duty count (where compliance burden sits)
6. **EU vs UK Split** — retained EU law proportion + post-Brexit divergence risk
7. **Stale Law Report** — heavily amended laws needing re-review

## Todo
- [x] Brainstorm QA artifacts
- [x] Pull data for confusion matrix — 208 TP, 66 FP, 23 FN, 37 TN
- [x] Pull data for revoked laws — 22 fully revoked in Yes set
- [x] Pull family distribution + duty density stats
- [x] Pull EU/UK split
- [x] Generate report v3 (.md) with appendices
- [x] Export backing data (.csv)
- [x] Create customer-quality-report skill
- [ ] Coverage gap analysis (SertantAI laws NOT in Enhesa register) — deferred

## Design Principles
- **Audience**: QQ senior management — business-readable, not technical
- **Format**: .md report + .csv data files in data/reports/qq/
- **Structure**: Summary numbers up front, appendices listing actual laws behind each metric
- **Reusable**: Design queries/logic so they can power a customer-facing report page in the app later
- **Confusion matrix definitions**:
  - TP: Enhesa Yes + SertantAI confirms (Making, in force)
  - FP: Enhesa Yes + law is revoked OR Housekeeping (no duties)
  - FN: Enhesa No/missing + SertantAI finds Making + in force in QQ's families
  - TN: Enhesa No + SertantAI agrees (not making, wrong family, or revoked)

## Notes
- Full QQ corpus: 24 sites, 275 yes-laws, 60 no-laws (union semantics)
- ~45 misidentified SSIs already fixed
- EU laws now parsed + enriched (61 Making, 9,090 LAT rows)
- Org ID: c075d56b-8420-4408-b695-ccfbc1ba15ec
- **10:20** v1 report generated: 192 TP, 83 FP (52 pending). Created customer-quality-report skill.
- **10:45** Fixed 3 misidentified Acts (asp/anaw wrongly matched as ukpga). Added pest/pesticide terms.
- **11:00** v2 report: 207 TP, 67 FP after parsing 27 pending laws
- **11:15** SQL bug: FP breakdown used different grouping than matrix — counts didn't add up. Fixed skill to use single-classification approach.
- **11:30** v3 final report: 208 TP, 66 FP, 23 FN. All assessable laws fully parsed. 76% precision, 90% recall.
- Fixed LRT ParseReviewModal not closing on last record (missing on:complete handler)
- Fixed LAT session title backfill from LRT lookup
- Updated customer-quality-report skill with SQL consistency warning
