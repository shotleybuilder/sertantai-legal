# Admin Dashboard Landing Page

**Started**: 2026-02-23

## Objective
Build an admin dashboard at `/admin` — currently returns 404 because there's no `+page.svelte` at that route (only a layout). This will be the landing page for the admin UI.

## Todo
- [x] Create `/admin/+page.svelte` dashboard page — `3c87bf3`
- [x] Fix GitHub OAuth auth flow — `1582e56`
  - `SERTANTAI_LEGAL_` prefix for all GitHub env vars (runtime.exs + user.ex)
  - `auth_tokens` table: rename `inserted_at`→`created_at`, add missing `updated_at`
  - `UserIdentity`: add timestamps (DB has NOT NULL columns)
  - Post-login redirect → `/admin` instead of `/admin/scrape`

## Notes
- Existing admin pages: `/admin/lrt`, `/admin/lat`, `/admin/scrape`, `/admin/scrape/sessions`, `/admin/scrape/cascade`
- Nav defined in `frontend/src/routes/admin/+layout.svelte`
- Dashboard shows: LRT stats (families, year range), LAT stats (4 cards), recent scraper sessions table, quick links
- Fetches from existing endpoints (`/api/uk-lrt/filters`, `/api/lat/stats`, `/api/sessions`) — no new backend needed
- `.bashrc` env vars needed: `SERTANTAI_LEGAL_GITHUB_CLIENT_ID`, `SERTANTAI_LEGAL_GITHUB_CLIENT_SECRET`, `SERTANTAI_LEGAL_GITHUB_ALLOWED_USERS`, `SERTANTAI_LEGAL_GITHUB_REDIRECT_URI`

**Ended**: 2026-02-23
