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

### Phase 2: JWT Validation in sertantai-legal (#20)
- [ ] Add `shared_token_secret` to `config/test.exs` (known test value)
- [ ] JWT validation plug (verify tokens using `shared_token_secret`)
- [ ] Extract user ID from `sub` claim (parse `"user?id=<uuid>"` format)
- [ ] Extract `org_id` from claims (not `organization_id`)
- [ ] Protect API routes that need authentication
- [ ] Pass-through for unauthenticated routes (health, UK LRT browsing)
- [ ] Test helper (`test/support/auth_helpers.ex`): mint JWTs locally via JOSE
  - `build_token/1` — generates valid JWT with default claims (`sub`, `org_id`, `role`, `iss`, `exp`)
  - Overridable claims for testing edge cases (expired, wrong org, malformed sub)
- [ ] Auth plug unit tests (valid token, expired, malformed, missing header)
- [ ] Controller tests updated to use `AuthHelpers.build_token/1` for authenticated routes

### Phase 3: Electric Auth Proxy (#20)
- [ ] Electric proxy controller (`GET /api/electric/v1/shape`)
- [ ] Proxy validates JWT before forwarding to Electric
- [ ] Proxy appends `?secret=ELECTRIC_SECRET` to upstream Electric requests
- [ ] Frontend ELECTRIC_URL updated to `/api/electric`
- [ ] Remove nginx `/electric/` proxy location in production

### Phase 4: Frontend Auth Integration
- [ ] Auth store/context for JWT management in SvelteKit
- [ ] Login/register UI (or redirect to sertantai-auth)
- [ ] Attach JWT to API requests (Authorization header)
- [ ] Attach JWT to Electric shape requests via proxy

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
