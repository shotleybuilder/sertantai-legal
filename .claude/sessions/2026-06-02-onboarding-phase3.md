# Title: Customer Onboarding Phase 3 — Org-Level Applicability Screener

**Started**: 2026-06-02 18:30
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 3)

## Todo
- [ ] 3.1 — Design the screener (Fitness field analysis, scoring model, org profile shape)
- [ ] 3.2 — Build screening logic in Legal (module + mix task, validate vs Enhesa 345)
- [ ] 3.3 — Aggregate site CSVs (validation set from QQ sites)
- [ ] 3.4 — Extract API shape once proven (endpoint for Hub to call)

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
