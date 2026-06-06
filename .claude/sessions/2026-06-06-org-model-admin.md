# Issue #105: Org Model + Auto-Screener DRRP Fix

**Started**: 2026-06-06 10:30
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/105

## Todo
- [x] Explore sertantai-auth DB schema (users/orgs/roles)
- [x] Design: decided against org switcher — per-org user accounts instead
- [x] Set up auth DB: gmail=admin (no org), QQ owner, test org+user
- [x] Handle org_id=null in /app layout for admin account
- [x] Fix #106: per-user PGLite IndexedDB stores
- [x] Fix entitlement endpoint (broken Ash API pattern)
- [x] Add family subscription filter to seed query
- [x] Add DRRP actor matching (duty_holder/responsibility_holder)
- [x] Split profile: governed_actors + government_actors
- [x] Test auto-screener with test org — 65 laws seeded successfully

## Notes
- **Approach**: no org switcher, no override headers, no auth-side changes
  - /admin = platform admin (gmail, role=admin, no org)
  - /app = org user (JWT carries org_id)
  - Switching orgs = switching login accounts
- **Auth DB users**:
  - drjasonwoodruff@gmail.com → admin, no org
  - jason.woodruff@qinetiq.com → owner of QinetiQ (pw: Test123!)
  - testuser@test-org.com → owner of Test Org (pw: Test123!)
- **Key fix**: screener was only matching fitness_person — now matches DRRP actors
  - governed_actors → duty_holder + rights_holder (commercial orgs)
  - government_actors → responsibility_holder + power_holder (gov agencies)
  - HSWA 1974 found via Org: Employer in duty_holder
  - Recall: 27→65 laws (+140%) from using DRRP actors
- **Other fixes**: PGLite per-user stores (#106), entitlement Ash.Query pattern, profile scroll, family subscription filter, debug dump endpoint

**Ended**: 2026-06-06 12:30
**Commits**: `2b848db`, (uncommitted batch)

## Summary
- Completed: 10 of 10 todos
- Files: client.ts, sync.ts, sync_controller.ex, screening_controller.ex, org_screening_profile.ex, router.ex, /app/+layout.svelte, /app/profile/+page.svelte, /app/screening/+page.svelte, migration
- Outcome: Org model redesigned (per-org users, no switcher), DRRP actor matching added to screener (27→65 laws, HSWA found), per-user PGLite stores fixed (#106), family subscription filter working.
- Next: Validate against QQ Enhesa data, dimension weighting (G2), explainability (G5)
