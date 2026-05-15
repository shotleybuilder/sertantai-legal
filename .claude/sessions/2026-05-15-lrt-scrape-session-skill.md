# Title: LRT Scrape Session Skill

**Started**: 2026-05-15
**Issue**: None

## Todo
- [x] Design the skill workflow stages
- [x] Define QA checks (data completeness, family sense-check, relationships, duplicates)
- [x] Write the skill SKILL.md and /lrt-scrape command
- [x] Fix: confirm endpoint not updating session persisted_count/status
- [x] Feature: Skip endpoint + UI (Skip Pending / Select Pending buttons)
- [x] Backfill 39 sessions with correct persisted_count, auto-complete 45
- [x] Committed and pushed (d591417)
- [x] Run post-scrape QA on Feb 2026 session — found 2 suspect + 4 query families
- [x] Fix 7 family assignments in Feb 2026 data
- [x] Fix: ~w[] sigil bug in health_safety.ex and environment.ex
- [x] Fix: LawParser.persist_direct doesn't calculate Function flags
- [x] Add missing terms: riddor, plant health, fire safety phrases, data (use and access)
- [ ] Commit and push bug fixes

## Notes
- ~w[] with backslash-escaped spaces does NOT preserve phrases in Elixir
  - Replaced all ~w[] with explicit string lists in both term files
  - "fire" was too broad (matched "firearms") — replaced with specific fire phrases
  - Added "riddor" to OH&S, plant health terms to environment, data terms
- LawParser.persist_direct now calls FunctionCalculator.calculate_immediate_function_of_law
  - Both create_record and update_record calculate and merge Function flags
  - Feb 2026 records still have NULL function (will need backfill on re-scrape)
