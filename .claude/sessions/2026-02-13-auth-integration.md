# Auth Integration: JWT Validation + Electric Proxy

**Started**: 2026-02-13
**Issues**: #20 (Electric auth proxy), #18 (3-tier feature gating)

## Development Environment

### Service Dependencies

| Service | Required for dev? | Port | Purpose |
|---------|-------------------|------|---------|
| sertantai-auth | Yes (for auth flows) | 4000 | JWT issuance, user management |
| sertantai-hub | No | - | Orchestrator, not needed for local dev |
| sertantai-legal postgres | Yes | 5436 | Legal service database |
| sertantai-legal electric | Yes | 3002 | ElectricSQL sync |
| sertantai-auth postgres | No (uses native pg:5432) | 5432 | Auth service database |

**Note on auth postgres**: sertantai-auth's `config/dev.exs` connects to localhost:5432 (default port),
using the native PostgreSQL service — NOT its docker-compose container (which maps 5435:5432 but
conflicts with sertantai-controls). The auth databases (`sertantai_auth_dev`, `sertantai_auth_test`)
already exist on the native postgres. The `--auth` dev scripts start auth via `mix phx.server`,
not via docker-compose, so no auth Docker container is needed for development.

### Starting Development

```bash
# Full stack with auth (recommended for auth integration work)
sert-legal-start --docker --auth

# Legal service only (for UI/data work that doesn't need auth)
sert-legal-start --docker

# Stopping everything
sert-legal-stop --docker --auth
```

### Shared Token Secret

Both services must agree on the token signing secret for JWT validation.

- **sertantai-auth dev**: `config :sertantai_auth, :token_signing_secret` in `config/dev.exs`:
  `"dev_secret_key_for_jwt_signing_please_change_in_production"`
- **sertantai-legal dev**: `config :sertantai_legal, :shared_token_secret` in `config/dev.exs`:
  `"dev_secret_key_for_jwt_signing_please_change_in_production"` (same value)
- **runtime.exs**: env var `SHARED_TOKEN_SECRET` overrides dev.exs if set (required in prod)

### Auth Project Location

- Path: `~/Desktop/sertantai_auth` (note: underscore, not hyphen)
- Dev port: 4000 (Phoenix, via `mix phx.server`)
- DB: native postgres on 5432, database `sertantai_auth_dev`
- Health: `GET http://localhost:4000/health`

### Auth API Endpoints (for reference)

```
POST /api/auth/user/password/register  - Register (body: {"user": {"email": "...", "password": "..."}})
POST /api/auth/user/password/sign_in   - Login (same body format, returns JWT)
POST /api/auth/refresh                 - Refresh token
GET  /api/sign_out                     - Logout
```

### Verified JWT Claims Structure

Actual JWT claims from sertantai-auth (verified 2026-02-17):

```json
{
  "aud": "~> 4.12",
  "exp": 1772573910,
  "iat": 1771364310,
  "iss": "AshAuthentication v4.12.0",
  "jti": "32aict508q4s76i184000015",
  "nbf": 1771364310,
  "org_id": "16f00f29-3ea3-4366-a329-843cfd661a13",
  "role": "owner",
  "sub": "user?id=711344c7-25fa-44fa-af52-f00acd85b992"
}
```

**Key differences from CLAUDE.md assumptions**:

| Field | CLAUDE.md assumed | Actual | Impact |
|-------|-------------------|--------|--------|
| `sub` | bare UUID | `"user?id=<uuid>"` | Auth plug must parse user ID from sub |
| org ID | `organization_id` | `org_id` | Auth plug must read `org_id` not `organization_id` |
| `services` | `["legal"]` | Not present | Cannot gate by service claim (yet) |
| `iss` | `"sertantai_auth"` | `"AshAuthentication v4.12.0"` | Issuer check must use actual value |
| `role` | Not expected | `"owner"` | Available for authorization |
| TTL | Not specified | ~14 days (`exp - iat`) | Long-lived tokens |

Registration auto-creates an Organization and assigns the user as `owner`.

---

## Implementation Phases

### Phase 1: Development Environment Setup
- [x] Development scripts (`--auth` flag) for starting/stopping sertantai-auth
- [x] Configure `shared_token_secret` in `backend/config/dev.exs` matching auth service
- [x] Fix `runtime.exs` so env var overrides dev.exs (not clobbers with nil)
- [x] Verify sertantai-auth can register a test user and issue JWTs
- [x] Verify JWT structure and document actual claim names

### Phase 2: JWT Validation in sertantai-legal (#20) — COMPLETE
- [x] Add `shared_token_secret` to `config/test.exs` (known test value)
- [x] JWT validation plug (`AuthPlug`) — verifies HS256 via JOSE
- [x] Extract user ID from `sub` claim (handles `"user?id=<uuid>"` format + bare UUID)
- [x] Extract `org_id` from claims → `conn.assigns.organization_id`
- [x] Extract `role` from claims → `conn.assigns.user_role`
- [x] Router reorganised: public pipeline (health, UK LRT reads) + authenticated pipeline (writes, scraper, cascade)
- [x] Test helper (`test/support/auth_helpers.ex`): mint JWTs locally via JOSE
  - `build_token/1`, `build_expired_token/1`, `put_auth_header/1`
  - Imported in ConnCase for all controller tests
- [x] 17 auth plug tests (valid, expired, malformed, wrong secret, missing claims, router integration)
- [x] Controller tests updated: scrape + cascade use auth in setup, UK LRT writes add auth, 401 tests added
- [x] All 751 tests pass, dialyzer clean

### Phase 3: Electric Auth Proxy (#20) — COMPLETE
- [x] Electric proxy controller (`ElectricProxyController`) — Guardian pattern
  - `GET /api/electric/v1/shape` — resolves shape, forwards to Electric
  - `DELETE /api/electric/v1/shape` — shape recovery for broken offsets
  - Server-side shape resolution: only allowed tables (uk_lrt, organization_locations, location_screenings)
  - Org-scoped tables get mandatory `WHERE organization_id = <jwt.org_id>` filter
  - UK LRT is public reference data — no auth required (matches REST endpoints)
  - Passthrough params: offset, handle, live, cursor, replica
- [x] Proxy appends `?secret=ELECTRIC_SECRET` when configured (production)
  - `electric_url` in dev.exs/test.exs, `ELECTRIC_URL` env var override
  - `electric_secret` via `ELECTRIC_SECRET` env var (production only)
- [x] Frontend ELECTRIC_URL updated to point through Phoenix proxy
  - `index.client.ts`, `sync-uk-lrt.ts`, `client.ts` all use `API_URL/api/electric`
  - Removed Vite `/electric` proxy (no longer needed)
- [x] 18 new tests: shape resolution, param forwarding, header forwarding, secret handling, upstream errors
- [x] All 769 tests pass, dialyzer clean, TypeScript clean
- [ ] Remove nginx `/electric/` proxy location in production (deferred to Phase 6)

### Phase 4: Frontend Auth Integration

#### Where should Login/Register UI live?

**Problem**: All four frontend services (-legal, -enforcement, -controls, -hub) need a common
login/register flow. Duplicating auth UI in each service is wrong. Three options considered:

| Option | Pros | Cons |
|--------|------|------|
| **A. sertantai-auth** (add frontend) | Auth logic co-located; single source of truth for auth flows | Currently backend-only; adding a frontend changes its nature; tighter coupling between auth API and UI |
| **B. sertantai-hub** (orchestrator) | Already has a SvelteKit frontend; natural home for cross-cutting UI; orchestrator role fits; users land at hub first then navigate to services | Hub becomes a dependency for all services; login latency if hub redirects are involved |
| **C. Shared SvelteKit package** | Each service embeds the component; no redirect needed; works offline | Package versioning/publishing overhead; duplication of auth state management; harder to update |

**Recommendation: Option B — sertantai-hub**

Rationale:
1. **Hub is the user's entry point** — users authenticate at the hub, then navigate to domain
   services. This matches the orchestrator role described in CLAUDE.md.
2. **Hub already has a SvelteKit frontend** — no new project or frontend bootstrap needed.
3. **Auth stays backend-only** — sertantai_auth remains a clean API/IdP service. Adding UI to it
   would blur the boundary between identity provider and user-facing application.
4. **Natural redirect flow**: `legal.sertantai.com` → check JWT → no JWT → redirect to
   `hub.sertantai.com/login` → authenticate → redirect back with JWT → proceed.
5. **Shared auth state**: Hub manages the JWT lifecycle (login, refresh, logout). Domain services
   only validate JWTs — they never issue or refresh them.
6. **Single sign-on (SSO)**: Hub login covers all services. Once authenticated at hub, the JWT
   works across -legal, -enforcement, and -controls (same `SHARED_TOKEN_SECRET`).

**Flow**:
```
User visits legal.sertantai.com
  → Frontend checks for JWT in localStorage/cookie
  → No JWT? Redirect to hub.sertantai.com/login?redirect=legal.sertantai.com
  → Hub login page calls sertantai-auth API (POST /api/auth/user/password/sign_in)
  → On success, hub stores JWT and redirects back to legal.sertantai.com?token=<jwt>
  → Legal frontend stores JWT, attaches to API requests
```

**What sertantai-legal Phase 4 still needs** (JWT consumption, not auth UI):
- [ ] Auth guard: check for JWT on app load, redirect to hub if missing
- [ ] JWT storage (localStorage or cookie) and retrieval
- [ ] Attach JWT to API requests (Authorization header) — scraper, cascade, write endpoints
- [ ] Attach JWT to Electric proxy requests (for future org-scoped shapes)
- [ ] Token refresh flow (call hub/auth refresh endpoint before expiry)
- [ ] Logout: clear JWT, redirect to hub

### Phase 5: Tier Claims + Feature Gating (#18)
- [ ] sertantai-auth: Add `services` and `legalTier` claims to JWTs
- [ ] sertantai-legal: Read tier from JWT claims in frontend
- [ ] Feature-gate UI components by tier
- [ ] Electric proxy enforces table access by tier

### Phase 6: Production Deployment
- [ ] sertantai-auth deployed to production
- [ ] `SHARED_TOKEN_SECRET` configured in infrastructure `.env`
- [ ] Production data flowing through authenticated proxy
- [ ] Verify cross-service JWT validation in production

## References

- **Dev scripts**: `scripts/development/README.md`
- **Electric Auth Guide**: https://electric-sql.com/docs/guides/auth
- **Electric Security Guide**: https://electric-sql.com/docs/guides/security
- **Tier Plan**: `.claude/plans/issue-18-future-tiers-and-views.md`
- **Auth API docs**: `~/Desktop/sertantai_auth/API.md`
- **Auth CLAUDE.md**: `~/Desktop/sertantai_auth/CLAUDE.md`
