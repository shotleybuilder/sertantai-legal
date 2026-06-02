# Title: Customer Onboarding Phase 3 — Org-Level Applicability Screener

**Started**: 2026-06-02 18:30
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 3)

## Todo
- [x] 3.1 — Design: screener lives in Legal, Hub provides org profile — 39afec6
- [x] 3.2a — OrgApplicability resource + enums + migration — 39afec6
- [x] 3.2b — mix sync.seed_applicability + QQ/BSC seeded (204 yes, 82 no) — 39afec6
- [x] 3.2c — Enhesa data QA: OH&S Personal Safety analysed, draft skill created
- [ ] 3.2d — API endpoints for applicability CRUD (needs auth context)
- [ ] 3.2e — Sync engine integration (Baserow Applicability column)
- [ ] 3.3 — Aggregate more QQ site CSVs through import pipeline
- [ ] 3.4 — Fitness-based screener (once Fitness coverage improves beyond safety families)
- [ ] 3.5 — Extract API shape for Hub to call

## Architecture Decision
- Screener lives in *-legal (close to the data, domain knowledge)
- Legal exposes screening endpoint; Hub provides org profile as input
- Build + validate here first, API boundary later
- Baserow sync is a first-class delivery channel, not interim

## Context: Fitness Data & Enhesa Quality

**Fitness coverage is intentionally uneven** — fractalaw's Fitness parser is being built iteratively, one family at a time. Safety families (OH&S, FIRE, Building Safety, Air Safety) have good coverage; environment families have almost none yet. The unlock for the POC is enriching the Enhesa-matched laws specifically.

**Enhesa data quality is suspect:**
- Coverage may be poor (missing laws that should be there)
- Known to include repealed laws (6 confirmed from Phase 1 QA)
- Human applicability screening (Yes/No) is error-prone

**The real goal is to QA the Enhesa data, not just replicate it.** The Enhesa 345 is not ground truth — it's a benchmark to test against, and we expect to find gaps and errors.

**Short circuit available:** The Enhesa CSV has human-assigned Yes/No applicability. We can import those answers directly without needing Fitness-based screening for the POC. The screener's value is proving it can match or exceed human curation quality.

## Notes
- L2 (1,665 making laws) is 13x too broad; target L3 ~300-400
- Fitness fields: fitness, fitness_person, fitness_place, fitness_plant, fitness_process, fitness_property, fitness_sector
- Fitness coverage: 249/3,348 making laws (7.4%), concentrated in 💙 safety families
- Enhesa curated set (345) is a benchmark to test against, not ground truth
