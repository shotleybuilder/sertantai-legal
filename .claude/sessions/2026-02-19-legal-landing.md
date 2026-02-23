# Legal Landing Experience — Auth Wiring

**Started**: 2026-02-19
**Updated**: 2026-02-21
**Ended**: 2026-02-21
**Committed**: 83053c8

## Context

Auth service (sertantai-auth) now provides:
- **Shared domain cookie**: `sertantai_token` HttpOnly cookie on `.sertantai.com`, set on login/refresh/sign-out
- **EdDSA (Ed25519)** signing — no more HS256/shared secret
- **JWKS endpoint**: `GET /.well-known/jwks.json` for public key distribution
- **`LoadFromCookie` plug**: reads cookie, injects as Bearer header
- **JWT claims**: `sub`, `org_id`, `role`, `tier`
- **Gatekeeper**: `POST /api/gatekeeper` unchanged

Browser sends cookie automatically to `legal.sertantai.com` — no URL param or localStorage needed.

## Architecture

```
User logs in at hub (sertantai.com)
  → auth sets HttpOnly cookie: sertantai_token on .sertantai.com
  → user clicks through to legal.sertantai.com/browse
  → browser sends cookie automatically (same eTLD+1, SameSite=Strict OK)

legal.sertantai.com backend:
  LoadFromCookie plug → reads sertantai_token cookie → injects Bearer header
  AuthPlug → verifies EdDSA signature via cached JWKS public key
  ElectricProxyController → reads Bearer from header → forwards to Gatekeeper
  Gatekeeper (auth service) → validates → returns shape params
  Proxy → streams from Electric
```

## Current State (what needs changing)

| Component | Current | Target |
|-----------|---------|--------|
| JWT signing | HS256 via `SHARED_TOKEN_SECRET` | EdDSA via JWKS public key from auth |
| Token transport | Bearer header only | Cookie (primary) + Bearer (fallback) |
| `AuthPlug` | `JOSE.JWT.verify_strict(jwk, ["HS256"], token)` | `JOSE.JWT.verify_strict(jwk, ["EdDSA"], token)` with JWKS key |
| Cookie reading | None | `LoadFromCookie` plug (same pattern as auth) |
| `uk_lrt` Electric shapes | `@public_tables` — no auth | Gatekeeper-validated like all other shapes |
| Frontend auth guard | None — anyone can hit `/browse` | Redirect unauthenticated to hub |
| Config | `shared_token_secret` in dev.exs / runtime.exs | `auth_url` for JWKS fetch, remove `shared_token_secret` |

## Plan

### Phase 1: Backend — EdDSA JWT validation via JWKS

**1a. JWKS key fetcher** — `lib/sertantai_legal/auth/jwks_client.ex`
- GenServer that fetches public key from `GET {auth_url}/.well-known/jwks.json` on startup
- Caches in-memory, re-fetches on verification failure (key rotation)
- Dev: fetches from `http://localhost:4000/.well-known/jwks.json`
- Prod: fetches from `http://sertantai-auth:4001/.well-known/jwks.json` (Docker network)
- Fallback: `SERTANTAI_AUTH_JWT_PUBLIC_KEY` env var (JWK JSON) if no network access

**1b. LoadFromCookie plug** — `lib/sertantai_legal_web/plugs/load_from_cookie.ex`
- Same pattern as auth's `LoadFromCookie`: read `sertantai_token` cookie, inject as Bearer header
- Only acts when no Authorization header already present
- Cookie name: `sertantai_token` (constant, matches auth)

**1c. Update AuthPlug** — `lib/sertantai_legal_web/plugs/auth_plug.ex`
- Change `verify_token/1`: get public key from `JwksClient`, verify with `["EdDSA"]`
- Remove `shared_token_secret` dependency
- Keep: `extract_token/1`, `validate_claims/1`, `extract_user_id/1` (unchanged)

**1d. Wire into router** — `lib/sertantai_legal_web/router.ex`
- Add `LoadFromCookie` to `:api` and `:sse` pipelines (before AuthPlug)
- Electric proxy route: add `:sse_authenticated` pipeline so AuthPlug runs

**1e. Update config**
- `config/dev.exs`: remove `shared_token_secret`, keep `auth_url: "http://localhost:4000"`
- `config/runtime.exs`: remove `SHARED_TOKEN_SECRET` requirement, add optional `SERTANTAI_AUTH_JWT_PUBLIC_KEY`
- `config/test.exs`: configure test key for JWT signing in tests

**1f. Update ElectricProxyController**
- Remove `uk_lrt` from `@public_tables` (empty the list or remove the concept)
- All shapes now go through `forward_gatekeeper_shape` which reads Bearer from header

**1g. Update tests**
- Test JWTs must be EdDSA-signed (generate test keypair in test helper)
- UK LRT shape tests: now require auth header
- Existing Gatekeeper tests should mostly work (they mock the Gatekeeper response)

### Phase 2: Frontend — auth guard & Electric headers

**2a. Auth guard** — `frontend/src/routes/browse/+page.svelte` (or layout)
- On mount: check if cookie exists (can't read HttpOnly cookie from JS!)
- Instead: make a lightweight auth check request to backend (e.g. `GET /api/me` or just let Electric shape request fail with 401)
- On 401 from Electric: redirect to hub login page
- Hub URL from `VITE_HUB_URL` env var (default: `https://sertantai.com`)

**2b. Electric shape requests — cookie sent automatically**
- `shapeOptions.url` points to `legal.sertantai.com/api/electric/v1/shape`
- Browser sends `sertantai_token` cookie automatically (same domain)
- **No code change needed** in `index.client.ts` for cookie transport!
- The `fetch` calls include cookies by default for same-origin requests
- For cross-origin (dev with different ports): may need `credentials: 'include'`

**2c. Handle 401 in Electric sync**
- `onError` handler in `index.client.ts`: if status 401, redirect to hub
- Already has onError for 400 (shape recovery) — add 401 case

**2d. Root redirect**
- `frontend/src/routes/+page.svelte`: redirect `/` → `/browse`

### Phase 3: Deploy & verify
- Deploy auth (already done — cookie is being set)
- Deploy legal backend + frontend
- Test: hub login → navigate to legal → cookie sent → data loads
- Test: direct visit to legal without cookie → 401 → redirect to hub
- Test: expired token → 401 → redirect to hub

## Key Files to Change

| File | Change |
|------|--------|
| `backend/lib/sertantai_legal/auth/jwks_client.ex` | **New** — JWKS public key fetcher/cache |
| `backend/lib/sertantai_legal_web/plugs/load_from_cookie.ex` | **New** — cookie → Bearer injection |
| `backend/lib/sertantai_legal_web/plugs/auth_plug.ex` | Switch HS256 → EdDSA, use JwksClient |
| `backend/lib/sertantai_legal_web/router.ex` | Add LoadFromCookie, auth Electric routes |
| `backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex` | Remove `@public_tables` |
| `backend/config/dev.exs` | Remove `shared_token_secret` |
| `backend/config/runtime.exs` | Remove `SHARED_TOKEN_SECRET`, add `SERTANTAI_AUTH_JWT_PUBLIC_KEY` |
| `backend/config/test.exs` | Test EdDSA keypair config |
| `frontend/src/lib/db/index.client.ts` | Add 401 handling in onError |
| `frontend/src/routes/+page.svelte` | Redirect `/` → `/browse` |
| `frontend/.env.development` | Add `VITE_HUB_URL` |

## Auth Service Reference

| Item | Value |
|------|-------|
| Cookie name | `sertantai_token` |
| Cookie domain | `.sertantai.com` (prod), omitted (dev) |
| Cookie flags | HttpOnly, Secure (prod), SameSite=Strict |
| Signing algorithm | EdDSA (Ed25519) |
| JWKS endpoint | `GET {auth_url}/.well-known/jwks.json` |
| Auth dev URL | `http://localhost:4000` |
| Auth prod URL | `http://sertantai-auth:4001` (Docker) |
| JWT claims | `sub`, `org_id`, `role`, `tier`, `exp`, `iat`, `iss`, `jti` |
| Access token TTL | 15 minutes |
| Gatekeeper | `POST {auth_url}/api/gatekeeper` |

## Notes
- `SameSite=Strict` is fine for subdomain navigation (same eTLD+1)
- HttpOnly means JS can't read the cookie — auth guard must infer from API responses, not cookie inspection
- `JOSE` library already in mix.exs — supports EdDSA natively
- Auth's `LoadFromCookie` plug is ~30 lines — simple to replicate
- Electric `fetch` uses browser's default cookie behaviour — should send cookie for same-origin automatically
- Dev: auth on port 4000, legal on port 4003 — different ports = different origins. May need `credentials: 'include'` on fetch, or rely on the proxy (same origin via Phoenix at 4003)
- Since Electric requests go through Phoenix proxy (`/api/electric/v1/shape`), they ARE same-origin — cookie sent automatically. No CORS issues.
