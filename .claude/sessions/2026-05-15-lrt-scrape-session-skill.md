# Title: LRT Scrape Session Skill

**Started**: 2026-05-15
**Issue**: None

## Todo
- [x] Design the skill workflow stages
- [x] Define QA checks (data completeness, family sense-check, relationships, duplicates)
- [x] Write the skill SKILL.md
- [x] Create /lrt-scrape command
- [x] Add to skills README
- [ ] Test the skill invocation

## Notes
- Human-AI partnered workflow for monthly LRT scrape sessions
- Stages: scope > scrape > QA gate > NAS sync > NAS QA gate > prod sync > prod QA gate
- Family sense-check is the key AI value-add (title vs family fit, not just null check)
- 51 families across 3 domains (HS/Env/HR) with emoji prefixes
