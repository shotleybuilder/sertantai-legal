# Proxy to Gatekeeper Migration

**Started**: 2026-02-18
**Plan**: `.claude/plans/proxy-to-gatekeeper-migration.md`

## Key Context

- sertantai-auth at `~/Desktop/sertantai_auth`
- Auth Gatekeeper: `POST /api/gatekeeper` with `{"shape": {"table": "...", "where": "...", "columns": [...]}}`
- Returns: `{status, token, proxy_url, expires_at, shape}` — issues shape-scoped JWT
- Auth pipeline: `:api_authenticated` (bearer token → user loaded)
- Auth ShapePolicies: role-based (`owner`/`admin`/`member`), generic tables (items, orders etc) — needs legal tables
- **Bug in -auth**: `validate_org_scope` reads `claims["organization_id"]` but JWT uses `"org_id"` — must fix
- `auth_url` config already in dev.exs, test.exs, runtime.exs — Step 2 from plan is done

## Phases

### Phase 1: Auth Service Prep (spec only — work done in -auth repo) — COMPLETE
- [x] Fix ShapePolicies `organization_id` → `org_id` bug
- [x] Add legal-specific tables to ShapePolicies: `uk_lrt` (public), `organization_locations`, `location_screenings`
- [x] Verify Gatekeeper handles public tables (no org scoping required)

### Phase 2: ElectricProxyController — delegate to Gatekeeper — COMPLETE
- [x] Add `validate_with_gatekeeper/2` — POST to auth's `/api/gatekeeper`, forward user's JWT
- [x] Remove `resolve_shape/2`, `uk_lrt_shape/1`, `org_scoped_shape/3`
- [x] Wire `shape/2` to call Gatekeeper for auth'd requests, skip for UK LRT (public)
- [x] Keep: `passthrough_params/1`, `maybe_add_secret/1`, `stream_from_electric/2`, `forward_electric_headers/2`, `ensure_binary/1`
- [x] Keep `delete_shape/2` with simple static table whitelist (no Gatekeeper needed for DELETE)
- [x] Handle Gatekeeper errors: 401 → 401, 403 → 403, unavailable → 502
- [x] Update `@moduledoc` to reference Gatekeeper pattern

### Phase 3: Router changes (if needed) — COMPLETE (no changes needed)
- [x] Evaluate: org-scoped shapes now need JWT → Electric proxy scope may need auth pipeline
- [x] Currently `:sse` (no auth) — UK LRT works, org-scoped tables handled in controller
- [x] Decision: keep controller-level auth — same endpoint serves public + auth'd shapes, can't split at router level

### Phase 4: Update tests — COMPLETE (25 tests, 0 failures)
- [x] Add Req.Test stub for Gatekeeper calls (`SertantaiLegalWeb.GatekeeperClient`)
- [x] UK LRT: no auth → skip Gatekeeper, forward to Electric (200)
- [x] Org-scoped: auth + Gatekeeper 200 → forward to Electric (with org WHERE)
- [x] Org-scoped: no auth → 401
- [x] Org-scoped: Gatekeeper 403 → 403
- [x] Gatekeeper unavailable → 502
- [x] Passthrough params still forwarded (public + org-scoped)
- [x] Electric headers still forwarded
- [x] Electric secret still appended
- [x] DELETE shape recovery works (all 3 allowed tables)
- [x] Verifies JWT forwarded to Gatekeeper
- [x] Verifies shape body sent to Gatekeeper

### Phase 5: Frontend comment updates — COMPLETE
- [x] `frontend/src/lib/db/index.client.ts` — Guardian → Gatekeeper
- [x] `frontend/src/lib/electric/client.ts` — same
- [x] `frontend/src/lib/electric/sync-uk-lrt.ts` — same
- [x] `frontend/vite.config.ts` — same
- [x] `backend/lib/sertantai_legal_web/router.ex` — same

### Phase 6: Verification — COMPLETE
- [x] `mix test` — 776 tests, 0 failures
- [x] `mix format` — clean
- [x] `npm run check` — 0 errors, 0 warnings
- [ ] Manual: `sert-legal-start --docker --auth`, verify UK LRT shapes
- [ ] Manual: verify org-scoped shape with valid JWT calls Gatekeeper

**Ended**: 2026-02-18
**Committed**: ac4abc5

## Auth Service Spec (Phase 1)

### Required changes in sertantai-auth (`~/Desktop/sertantai_auth`)

**1. Fix org_id bug in ShapePolicies**

File: `lib/sertantai_auth/electric/shape_policies.ex`

The `validate_org_scope/3` function reads `claims["organization_id"]` but actual JWT claims
use `"org_id"`. All org-scoped validation currently fails silently (always unauthorized).

Fix: Change `claims["organization_id"]` → `claims["org_id"]` throughout.

**2. Add sertantai-legal tables to ShapePolicies**

Current tables are generic placeholders (items, orders, customers, etc.). Need to add:

| Table | Public? | Org-scoped? | Role access |
|-------|---------|-------------|-------------|
| `uk_lrt` | Yes | No | All roles (public reference data) |
| `organization_locations` | No | Yes (`organization_id`) | owner, admin, member |
| `location_screenings` | No | Yes (`organization_id`) | owner, admin, member |

Implementation approach: ShapePolicies should be service-aware or accept a service identifier.
Options:
- A. Add tables directly to the existing policy map (simple, couples -auth to -legal schema)
- B. Make policies configurable per service via config (decoupled but more complex)
- C. Accept a `service` param in the Gatekeeper request, load policies by service

Recommendation: **Option A** for now — add legal tables directly. Refactor to B/C when
a second service (enforcement/controls) needs Electric shapes.

**3. Public table handling in Gatekeeper**

Currently Gatekeeper requires authentication (`api_authenticated` pipeline). But `uk_lrt`
is public reference data that sertantai-legal serves without auth.

Options:
- A. Legal proxy skips Gatekeeper for UK LRT entirely (current plan — simplest)
- B. Gatekeeper adds a public endpoint that doesn't require auth
- C. Legal proxy sends a service-level API key instead of user JWT for public shapes

Recommendation: **Option A** — legal proxy handles UK LRT locally (simple table whitelist),
only calls Gatekeeper for org-scoped tables. This is already the plan.

## Notes
- Plan Step 2 (auth_url config) already done — skip
- Auth Gatekeeper is a token issuer (returns shape JWT), not just a validator — plan was stale on this
- Gatekeeper token could be used directly with Electric (pure Gatekeeper pattern) but that requires
  Electric to be configured with the auth signing key — for now, keep the proxy forwarding pattern
