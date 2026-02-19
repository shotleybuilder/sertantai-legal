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

### Phase 3: Electric Auth — Proxy Pattern (interim) → Gatekeeper Pattern (target) (#20)

**Terminology** (per [ElectricSQL auth guide](https://electric-sql.com/docs/guides/auth)):
- **Proxy auth**: Every request goes through your backend, which validates auth and injects shape params server-side
- **Gatekeeper auth**: Your API issues a short-lived shape-scoped JWT; client uses it with a thin validating proxy

**Current state**: Proxy pattern implemented (see below). This works but puts the backend on the
hot path for every Electric request. The target architecture is the **Gatekeeper pattern**, where
sertantai-auth issues shape-scoped JWTs and a thin proxy (or edge function) validates them.
See `.claude/plans/proxy-v-gatekeeper-auth.md` for the full comparison.

**Migration path**: The proxy controller below will be replaced when the Gatekeeper flow is wired
through from -auth. The frontend ELECTRIC_URL routing and backend config (electric_url, electric_secret)
will be reused.

#### Completed (Proxy pattern — interim)
- [x] Electric proxy controller (`ElectricProxyController`) — Proxy auth pattern
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

#### TODO (Gatekeeper pattern — target)
- [ ] Wire frontend to call -auth's `/api/gatekeeper` to obtain shape-scoped JWT
- [ ] Replace `ElectricProxyController` shape resolution with thin JWT validation proxy
- [ ] Remove nginx `/electric/` proxy location in production (deferred to Phase 6)

### Phase 4: Frontend Auth Integration

#### Where should Login/Register UI live?

**Problem**: All four frontend services (-legal, -enforcement, -controls, -hub) need a common
login/register flow. Duplicating auth UI in each service is wrong.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **A. sertantai-auth** (add frontend) | Auth logic co-located; single source of truth | Changes its backend-only nature; tighter coupling |
| **B. sertantai-hub** (orchestrator) | Has SvelteKit frontend; orchestrator role fits | Hub dependency for all services |
| **C. Shared SvelteKit package** | No redirect; works offline | Versioning overhead; duplicated state |
| **D. Keycloak** (replace auth) | Industry-standard OIDC; built-in login UI | Java stack; operational overhead; loses custom tenant model |

#### Keycloak Assessment (Option D)

Keycloak 25+ has an [Organizations feature](https://www.keycloak.org/2024/06/announcement-keycloak-organizations)
that supports multi-tenancy with first-class Organizations, Memberships, and Roles. However:

**Keycloak cannot replace our tenant model.** Here's why:

1. **Domain-specific user attributes**: sertantai-auth already stores `org_id` and `role` on users
   and injects them as JWT claims. Future phases will add `legalTier`, `services`, and
   content-matching attributes (duty_holder type, geo_region, role_gvt). These are deeply
   domain-specific — Keycloak's custom claims require writing Java protocol mappers.

2. **Existing Gatekeeper pattern**: sertantai-auth already has a `/api/gatekeeper` endpoint that
   issues shape-scoped JWTs for ElectricSQL, with role-based table access policies
   (owner/admin/member/viewer). This is tightly integrated with Ash resources and would need
   complete reimplementation in Keycloak.

3. **Content matching**: Later phases need to match users to legal content based on their
   organization profile (what type of duty holder, geographic jurisdiction, sector). This requires
   domain queries joining user/org data with UK LRT records — something that lives in our
   Ash resources, not in an external IdP.

4. **Operational overhead**: Keycloak is a Java application requiring its own infrastructure,
   monitoring, and upgrades. For a small team, maintaining a custom Elixir auth service built on
   AshAuthentication is less operational burden than running Keycloak alongside the existing stack.

5. **What Keycloak IS good for**: If we needed federated SSO (SAML, social login, enterprise IdPs)
   or had hundreds of tenants, Keycloak would be worth the overhead. We don't — we have a
   straightforward email/password flow with a small tenant base.

**Verdict**: Keep sertantai-auth. It owns the tenant model and will grow to support content matching.

#### Recommendation: Option B — sertantai-hub (with shared domain cookie)

**Hub hosts the login UI. Token transport via shared domain cookie, not URL redirect.**

Rationale:
1. **Hub is the user's entry point** — users authenticate at the hub, then navigate to domain
   services. This matches the orchestrator role.
2. **Hub already has a SvelteKit frontend** — no new project needed.
3. **Auth stays backend-only** — sertantai_auth remains a clean API/IdP service.

#### Token Transport: Shared Domain Cookie (not URL redirect)

**Initial proposal** (`?token=<jwt>` in redirect URL) has security issues:
- JWT appears in browser history, server logs, and Referrer headers
- Essentially reinventing OAuth2 authorization code flow, badly

**Better approach**: HttpOnly cookie on `.sertantai.com` domain.

```
User visits legal.sertantai.com
  → Frontend checks for JWT cookie (set on .sertantai.com domain)
  → No cookie? Redirect to hub.sertantai.com/login?redirect=legal.sertantai.com
  → Hub login page calls sertantai-auth API (POST /api/auth/user/password/sign_in)
  → On success, hub backend sets HttpOnly cookie on .sertantai.com domain
  → Redirect back to legal.sertantai.com
  → Cookie automatically sent with all requests to *.sertantai.com
  → Legal backend reads JWT from cookie (or Authorization header — support both)
```

**Cookie properties**:
- `Domain=.sertantai.com` — shared across all subdomains
- `HttpOnly` — not accessible via JavaScript (XSS-safe)
- `Secure` — HTTPS only
- `SameSite=Lax` — sent on top-level navigations and same-site requests
- `Path=/` — available on all paths
- `Max-Age=1209600` — 14 days (matches JWT TTL)

**Implications**:
- Backend `AuthPlug` updated to check both `Authorization` header AND cookie
- API requests from SvelteKit frontend use cookie automatically (no manual header needed)
- Electric proxy requests also carry the cookie
- `localStorage` not needed for token storage
- Logout = delete cookie at hub + redirect

**Dev environment**: In development, services run on `localhost` with different ports. Cookie
domain `.localhost` doesn't work reliably across browsers. Two options:
- Use `Authorization` header in dev (frontend reads token from cookie-less login response)
- Use `/etc/hosts` aliases: `hub.sertantai.local`, `legal.sertantai.local` with cookie on
  `.sertantai.local`

#### sertantai-auth Capabilities (already built)

Deeper review of sertantai-auth revealed it already has more than expected:

| Capability | Status | Location |
|------------|--------|----------|
| User + Organization resources | Built | `lib/sertantai_auth/accounts/` |
| Password registration + login | Built | AshAuthentication password strategy |
| JWT with `org_id` + `role` claims | Built | `auth_controller.ex` |
| Token refresh endpoint | Built | `POST /api/auth/refresh` |
| Gatekeeper (shape-scoped JWTs) | Built | `gatekeeper_controller.ex` |
| Role-based shape policies | Built | `electric/shape_policies.ex` |
| Auto-create org on registration | Built | `auth_controller.ex` |
| `services` / `legalTier` claims | Not yet | Phase 5 |
| Content-matching user attributes | Not yet | Future |
| Login/Register UI | Not built | Phase 4 (in hub) |

**Note**: sertantai-auth already has a Gatekeeper endpoint that issues shape-scoped JWTs. This
overlaps with sertantai-legal's Phase 3 ElectricProxyController. Decision needed: should the
Electric proxy in sertantai-legal delegate to auth's Gatekeeper, or continue validating
independently? For now, independent validation is simpler (avoids inter-service HTTP call on
every shape request), but worth revisiting when org-scoped shapes are needed.

#### Phase 4 Tasks (JWT consumption in sertantai-legal, not auth UI)

- [ ] Auth guard: check for JWT cookie on app load, redirect to hub if missing
- [ ] Update `AuthPlug` to read JWT from cookie OR Authorization header
- [ ] Attach JWT to API requests (cookie auto-sent; Authorization header as fallback)
- [ ] Attach JWT to Electric proxy requests (for future org-scoped shapes)
- [ ] Token refresh flow (call hub/auth refresh endpoint before expiry)
- [ ] Logout: clear cookie via hub, redirect
- [ ] Dev environment strategy: decide on cookie vs header approach for localhost

### Phase 5: Tier Claims + Feature Gating (#18)
- [ ] sertantai-auth: Add `services` and `legalTier` claims to JWTs
- [ ] sertantai-legal: Read tier from JWT claims in frontend
- [ ] Feature-gate UI components by tier
- [ ] Electric proxy enforces table access by tier

### Phase 6: Production Deployment
- [ ] sertantai-auth deployed to production
- [ ] `SHARED_TOKEN_SECRET` configured in infrastructure `.env`
- [ ] Nginx: cookie domain `.sertantai.com` on hub login response
- [ ] Remove nginx `/electric/` direct proxy (use backend proxy only)
- [ ] Production data flowing through authenticated proxy
- [ ] Verify cross-service JWT validation in production

## Separation of Concerns Audit (2026-02-17)

### Overlap Between -auth and -legal

| Area | -legal | -auth | Resolution |
|------|--------|-------|------------|
| JWT validation | `AuthPlug` (JOSE, HS256) | AshAuthentication built-in | OK — each service validates locally, no inter-service call needed |
| Shape table whitelist | `ElectricProxyController.resolve_shape/2` | `ShapePolicies.allowed_shapes/1` | **Overlap** — auth has role-based policies, legal has hardcoded whitelist |
| Org-scoped WHERE injection | `org_scoped_shape/3` in proxy | `ShapeValidator.validate_where/3` | **Overlap** — same logic in two places |
| Electric secret management | `maybe_add_secret/1` appends to query | Gatekeeper signs shape-scoped JWT | Different mechanisms, same goal |
| Tenant extraction | `conn.assigns.organization_id` (manual) | `Ash.PlugHelpers.set_tenant` (ORM-integrated) | Style difference — legal should adopt Ash tenant pattern if it uses Ash queries |

### Proxy vs Gatekeeper — Decision

Two Electric auth patterns exist (per [ElectricSQL auth guide](https://electric-sql.com/docs/guides/auth)):
- **Proxy auth (legal, interim)**: Every request goes through backend, which validates auth and injects
  shape params. Simple but puts backend on the hot path for all Electric traffic.
- **Gatekeeper auth (auth, target)**: API issues shape-scoped JWT once; client uses it with a thin
  validating proxy. Higher performance, edge-friendly, auth check happens once per token.

See `.claude/plans/proxy-v-gatekeeper-auth.md` for full comparison.

**Decision: Gatekeeper pattern wins.** It keeps shape authorization in -auth (where it belongs),
offloads the hot path from -legal's backend, and aligns with ElectricSQL's recommendation for
production apps. The proxy pattern in -legal is an interim step that will be replaced.

### What Should Move to -auth (Future)

- **Shape policies already in -auth**: The Gatekeeper decision means `ShapePolicies` in -auth is the
  correct home for role-based shape access rules. When -enforcement and -controls need Electric shapes,
  they call -auth's Gatekeeper — no shape whitelisting needed in each service. The overlap in -legal's
  `ElectricProxyController` will be removed when migrating to Gatekeeper.

- **JWT claim parsing**: The `"user?id=<uuid>"` sub format parsing is duplicated. A shared Elixir library
  (`sertantai_auth_client`) could export a `parse_claims/1` helper. **Not urgent** — trivial code, but
  worth extracting when 3+ services exist.

### What Stays in -legal (Correct Placement)

- **Guardian proxy itself**: Each service proxies its own Electric shapes because each service knows its
  own tables and domain-specific WHERE clauses. The proxy lives where the domain knowledge lives.
- **Domain-specific shape resolution**: `uk_lrt` is public, `organization_locations` needs org scoping —
  this is legal domain logic, not auth logic.
- **JWT validation plug**: Each service validates JWTs locally. This is standard microservice practice —
  no auth service round-trip on every request.

### Elixir Ecosystem Research (Cookies & Hub)

**Keycloak is a misdirection.** Staying in the Elixir ecosystem.

| Library/Tool | What It Does | Relevant? |
|-------------|--------------|-----------|
| AshAuthentication | Password strategy, JWT issuance, token storage | Already used by -auth. No cross-subdomain cookie support (that's Plug's job). |
| Phoenix `Plug.Session` | Session cookies with configurable `domain` | **Key tool** — `domain: ".sertantai.com"` enables cross-subdomain cookie sharing |
| Guardian (ueberauth) | JWT-in-session, auth pipelines | Unnecessary — we already have JWT validation via JOSE. Adds a dependency for no benefit. |
| JOSE | JWT signing/verification | Already used by -legal's AuthPlug. Correct choice. |

**Cross-subdomain cookie approach** (confirmed by Elixir community patterns):
- Hub sets HttpOnly cookie on `.sertantai.com` domain containing the JWT
- All services (`legal.sertantai.com`, etc.) receive the cookie automatically
- `AuthPlug` reads JWT from cookie OR Authorization header (support both)
- No extra libraries needed — `Plug.Session` handles cookie management
- For shared session cookies: all services need matching `secret_key_base`, `signing_salt`, `encryption_salt`
- For JWT-in-cookie: simpler — just set a plain cookie with JWT, each service verifies with JOSE

**Dev environment**: Services run on `localhost:PORT` (no subdomains). Use Authorization header in dev,
cookie in production. Or use `/etc/hosts` aliases with `.sertantai.local` domain.

**No new libraries needed**: JOSE + Plug.Session + AshAuthentication cover everything.

## References

- **Dev scripts**: `scripts/development/README.md`
- **Electric Auth Guide**: https://electric-sql.com/docs/guides/auth
- **Electric Security Guide**: https://electric-sql.com/docs/guides/security
- **Tier Plan**: `.claude/plans/issue-18-future-tiers-and-views.md`
- **Auth API docs**: `~/Desktop/sertantai_auth/API.md`
- **Auth CLAUDE.md**: `~/Desktop/sertantai_auth/CLAUDE.md`
- **Auth Gatekeeper**: `~/Desktop/sertantai_auth/lib/sertantai_auth_web/controllers/gatekeeper_controller.ex`
- **Auth Shape Policies**: `~/Desktop/sertantai_auth/lib/sertantai_auth/electric/shape_policies.ex`
- **Keycloak Organizations**: https://www.keycloak.org/2024/06/announcement-keycloak-organizations
- **Keycloak Multi-Tenancy Options**: https://phasetwo.io/blog/multi-tenancy-options-keycloak/
- **Microservices Auth Architecture**: https://microservices.io/post/architecture/2025/05/28/microservices-authn-authz-part-2-authentication.html
- **Cross-subdomain Cookies**: https://fwielstra.github.io/2017/03/13/fun-with-cookies-and-subdomains/

**Ended**: 2026-02-18
