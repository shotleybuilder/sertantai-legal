# Plan: Migrate Electric Auth from Proxy to Gatekeeper Pattern

## Context

sertantai-legal currently uses the **Proxy auth pattern** for ElectricSQL: every shape request
goes through `ElectricProxyController`, which validates JWT, resolves shapes server-side
(table whitelist + org-scoping), appends the Electric secret, and forwards to Electric.

The decision (documented in the session doc) is to migrate to the **Gatekeeper pattern**,
where sertantai-auth validates shape requests via `GET /api/gatekeeper` and the proxy in
-legal becomes a thin pass-through that no longer does shape resolution or org-scoping itself.

This also addresses the separation of concerns overlap: shape authorization logic moves to
-auth (where it belongs), and -legal stops duplicating table whitelists and WHERE injection.

### Key Discovery: Auth Gatekeeper is a Validator, Not a Token Issuer

The actual -auth Gatekeeper (`GatekeeperController.validate/2`) does NOT issue shape-scoped
JWTs as described in the ElectricSQL docs. It's a **validation endpoint**: it returns
`200 {status: "ok"}` or `403 {error: ...}`. This means the flow is:

```
Client → Legal Proxy → calls Auth Gatekeeper to validate → if OK, forwards to Electric
```

Not the "pure" Gatekeeper pattern (client gets shape JWT, uses it directly with Electric),
but a hybrid that keeps the proxy thin while centralizing authorization in -auth.

### Known Bug in -auth ShapePolicies

`ShapePolicies.validate_org_scope/3` reads `claims["organization_id"]` but the actual JWT
uses `"org_id"`. This bug means org-scoped validation will always fail. The fix is in -auth
(not in scope for this plan, but must be done before testing end-to-end).

## Approach

### Step 1: Update ElectricProxyController — delegate to -auth Gatekeeper

Replace the inline `resolve_shape/2` logic with a call to -auth's Gatekeeper endpoint.

**File**: `backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex`

Changes:
- Remove `resolve_shape/2`, `uk_lrt_shape/1`, `org_scoped_shape/3` (proxy pattern code)
- Add `validate_with_gatekeeper/2` that calls `GET AUTH_URL/api/gatekeeper?table=...&where=...`
  forwarding the user's JWT in the Authorization header
- On 200: forward the shape request to Electric (table, where, columns from original params)
- On 401/403: return the error to the client
- On error (auth unavailable): return 502
- UK LRT special case: still allow without auth (public reference data), but validate via
  Gatekeeper if auth header is present
- Keep `passthrough_params/1`, `maybe_add_secret/1`, `stream_from_electric/2`,
  `forward_electric_headers/2`, `ensure_binary/1` (these are proxy mechanics, not auth logic)
- Keep `delete_shape/2` for shape recovery (still needs table whitelist for DELETE — use
  a simple static list, not the full resolve_shape logic)
- Update `@moduledoc` to reference Gatekeeper pattern
- Add `auth_url` config (alongside existing `electric_url`)

### Step 2: Add auth_url configuration

**Files**: `backend/config/dev.exs`, `backend/config/test.exs`, `backend/config/runtime.exs`

- Add `auth_url: "http://localhost:4000"` to dev.exs
- Add `auth_url: "http://localhost:4000"` to test.exs (will be mocked via Req.Test)
- Add `AUTH_URL` env var override in runtime.exs
- Prod: `AUTH_URL` required env var

### Step 3: Update router — add auth to Electric proxy pipeline

**File**: `backend/lib/sertantai_legal_web/router.ex`

Currently the Electric proxy uses `:sse` pipeline (no auth). The controller handles auth
conditionally. With the Gatekeeper pattern, the proxy should:
- Keep `:sse` pipeline for UK LRT (public, no auth required)
- Add a second scope with `:sse_authenticated` for org-scoped shape requests
- OR: keep single scope, let controller decide (simpler, matches current pattern)

**Decision**: Keep single scope with `:sse` pipeline. The controller already handles the
auth-optional pattern (UK LRT = no auth, org-scoped = auth required). The Gatekeeper call
in the controller will forward the JWT if present. This avoids router changes.

No router changes needed.

### Step 4: Update tests

**File**: `backend/test/sertantai_legal_web/controllers/electric_proxy_controller_test.exs`

- Replace Req.Test stubs: need to stub BOTH the auth Gatekeeper AND Electric upstream
- Use a second Req.Test stub name (e.g., `SertantaiLegalWeb.GatekeeperClient`) for auth calls
- Test cases:
  - UK LRT: no auth header → skip Gatekeeper, forward directly to Electric (200)
  - UK LRT: with auth header → call Gatekeeper, Gatekeeper returns 200, forward to Electric
  - Org-scoped table: auth header present, Gatekeeper returns 200 → forward to Electric
  - Org-scoped table: no auth header → 401
  - Org-scoped table: Gatekeeper returns 403 → 403 to client
  - Gatekeeper unavailable → 502
  - Passthrough params still forwarded correctly
  - Electric headers still forwarded correctly
  - Electric secret still appended
  - DELETE shape recovery still works
- Keep existing test infrastructure (Req.Test pattern)

### Step 5: Update frontend comments

**Files**: `frontend/src/lib/db/index.client.ts`, `frontend/src/lib/electric/client.ts`,
`frontend/src/lib/electric/sync-uk-lrt.ts`

- Update comments from "Guardian pattern" to "Gatekeeper pattern"
- No functional changes — the frontend still hits `/api/electric/v1/shape` on the -legal
  backend. The Gatekeeper delegation is transparent to the frontend.

### Step 6: Update session doc

**File**: `.claude/sessions/2026-02-13-auth-integration.md`

- Mark Phase 3 Gatekeeper TODOs as complete
- Update overlap audit to reflect that shape authorization now lives in -auth
- Note the -auth ShapePolicies `organization_id` bug for follow-up

## Files Modified

| File | Change |
|------|--------|
| `backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex` | Replace resolve_shape with Gatekeeper call |
| `backend/config/dev.exs` | Add `auth_url` |
| `backend/config/test.exs` | Add `auth_url` |
| `backend/config/runtime.exs` | Add `AUTH_URL` env var |
| `backend/test/.../electric_proxy_controller_test.exs` | Rewrite tests for Gatekeeper pattern |
| `frontend/src/lib/db/index.client.ts` | Comment update only |
| `frontend/src/lib/electric/client.ts` | Comment update only |
| `frontend/src/lib/electric/sync-uk-lrt.ts` | Comment update only |
| `.claude/sessions/2026-02-13-auth-integration.md` | Progress update |

## Files NOT Modified (in -auth, out of scope)

- `ShapePolicies` `organization_id` → `org_id` bug fix (separate task in -auth repo)
- Gatekeeper enhancement to issue shape-scoped JWTs (future, if needed)

## Verification

1. `cd backend && mix test` — all tests pass
2. `cd backend && mix format --check-formatted` — formatted
3. `cd backend && mix credo` — clean
4. `cd frontend && npm run check` — TypeScript clean
5. Manual: start auth + legal with `sert-legal-start --docker --auth`, verify UK LRT
   shape requests still work through the proxy
6. Manual: verify org-scoped shape request with valid JWT calls Gatekeeper (check auth logs)
