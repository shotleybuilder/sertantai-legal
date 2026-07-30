---
session: New Customer POC Setup Workflow
status: closed
opened: 2026-06-02
closed: 2026-06-02
---
# Title: New Customer POC Setup Workflow

**Started**: 2026-06-02 08:45
**Status**: Complete — Phase 1 done, remaining phases in meta-plan

## Completed
- [x] Build `mix legal.import_register` (extract → transform → match pipeline)
- [x] Import QQ/BSC Enhesa CSV: 670 matched, 239 scraped, 32 not handled
- [x] Post-scrape QA + family QA (domestic) — PASS
- [x] NAS sync + archive to /mnt/nas/sertantai-data/data/imports/qq/bsc/
- [x] Skill: .claude/skills/customer-onboarding-import/
- [x] Updated lrt-scrape skill: family QA as parser improvement loop
- [x] LAT queue picker updated: import sessions now selectable
- [x] Import session marked completed
- [x] Filed parser issues: #84 (family bug), #85 (SI code gaps), #86 (EU family)
- [x] Onboarding analysis: backend/data/imports/qq/bsc/onboarding-analysis.md
- [x] Meta-plan: .claude/plans/customer-onboarding.md (Phases 2-5)

## Key Artefacts
- Mix task: backend/lib/mix/tasks/legal.import_register.ex
- Skill: .claude/skills/customer-onboarding-import/SKILL.md
- Meta-plan: .claude/plans/customer-onboarding.md
- Customer data: backend/data/imports/qq/bsc/ (gitignored, archived to NAS)

## Key Learning
- UK law identity: type_code + year + number (never year+number alone)
- Vendor Act numbers unreliable — always match by title
- EU citation format varies wildly — disambiguate EC/ (number/year) vs EU/ (either order)
- Applicability has 3 levels: L1 family, L2 making, L3 org-screened (Fitness-informed)
- SertantAI L2 (1,665) is 13x site needs — L3 screener is the value-add
