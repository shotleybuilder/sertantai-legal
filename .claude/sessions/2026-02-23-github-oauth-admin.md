# Title: GitHub OAuth for Admin Routes (sertantai-legal)

**Started**: 2026-02-23T07:42:31Z
**Commit**: 4efa0d3

## Todo
- [x] Add AshAuthentication + GitHub OAuth deps to sertantai-legal
- [x] Create User resource with GitHub OAuth strategy + is_admin flag
- [x] Add UserIdentity + Token resources for AshAuthentication
- [x] Create AuthHelpers plug (require_authenticated_user, require_admin_user)
- [x] Add browser + admin_required pipelines to router
- [x] Move admin routes from api_authenticated to admin_required pipeline
- [x] Add GitHub OAuth config (dev.exs, runtime.exs, test.exs)
- [x] Create AuthController for OAuth callback handling
- [x] Create FlexibleAuth plug for SSE (JWT or session)
- [x] JwksClient graceful degradation when AUTH_URL missing
- [x] Frontend: auth callback page, auth store, admin layout gate
- [x] Frontend: scraper.ts credentials (adminFetch wrapper)
- [x] Create sert-legal-admin startup script
- [x] Update all admin controller tests for session auth
- [x] All tests passing (1065 tests, 0 failures)
- [x] Commit and push

## Notes
- Pattern from sertantai-enforcement: AshAuthentication OAuth2 :github strategy
- Admin check via GITHUB_ALLOWED_USERS config
- Admin routes use Phoenix sessions (browser pipeline), not JWT
- Tenant routes (uk-lrt writes) keep existing JWT auth (AuthPlug)
- SSE parse-stream uses FlexibleAuth (tries JWT first, falls back to session)
- JwksClient no longer raises when auth_url missing -- allows admin-only mode
- Pre-push hooks pass: dialyzer, sobelow, deps audit, tests

**Ended**: 2026-02-23
