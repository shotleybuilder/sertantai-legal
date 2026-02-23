# Plan: Auth UI for sertantai-hub

## Context

sertantai-hub is the orchestrator service and user entry point. Users authenticate here, then navigate to domain services (legal, enforcement, controls). Currently the hub has **no auth UI** — just a landing page with an API test card. The auth backend (`sertantai-auth` at `~/Desktop/sertantai-auth`) already provides registration, login, refresh, and sign-out endpoints. The decision (from the legal auth integration session) is that **hub hosts the login UI** and transports tokens via shared domain cookie in production, Authorization header in dev.

**Goal**: Add login/register pages, auth state management, and an auth proxy in the hub backend so users can authenticate through the hub.

## Key Decisions

1. **Proxy through hub backend** (not direct frontend→auth CORS calls). Auth has no CORS config and should stay backend-only. Hub backend proxies auth requests, and in production will set HttpOnly cookies.

2. **Port change**: Hub dev port 4000 → **4006** (auth owns 4000 in dev). Frontend `VITE_API_URL` updated accordingly.

3. **Client-side SPA auth**: Hub uses `@sveltejs/adapter-static` (pure SPA). No server-side route protection — auth guard is client-side UX; security comes from authenticated API calls.

4. **Dev mode**: Token in localStorage + Svelte store. No cookies needed locally.

## Auth API Reference (sertantai-auth, port 4000)

| Endpoint | Body | Returns |
|----------|------|---------|
| `POST /api/auth/user/password/register` | `{"user": {"email": "...", "password": "..."}}` | `{status, user, token, organization_id, role}` |
| `POST /api/auth/user/password/sign_in` | same | same |
| `POST /api/auth/refresh` | Authorization header | `{status, access_token, user, organization_id, role}` |
| `GET /api/sign_out` | Authorization header | `{status, message}` |

Registration auto-creates an Organization and assigns user as `owner`.

## Phases

### Phase 1: Port + Config + Backend Auth Proxy

**Modify:**
- `backend/config/dev.exs` — port 4000 → 4006, add `auth_service_url: "http://localhost:4000"`
- `backend/config/runtime.exs` — add `AUTH_SERVICE_URL` env var override
- `backend/mix.exs` — add `{:req, "~> 0.5"}` dep
- `backend/lib/starter_app_web/router.ex` — add auth proxy routes
- `frontend/.env` or `VITE_API_URL` default — update to port 4006

**Create:**
- `backend/lib/starter_app_web/controllers/auth_proxy_controller.ex` — thin proxy:
  - `register/2` → forwards to auth `POST /api/auth/user/password/register`
  - `login/2` → forwards to auth `POST /api/auth/user/password/sign_in`
  - `refresh/2` → forwards to auth `POST /api/auth/refresh`
  - `logout/2` → forwards to auth `GET /api/sign_out`
  - Returns auth service response directly (status code + JSON body)
  - Uses `Req` with test mode plug pattern (same as sertantai-legal)

**Router additions:**
```elixir
scope "/api/auth", StarterAppWeb do
  pipe_through :api
  post "/register", AuthProxyController, :register
  post "/login", AuthProxyController, :login
  post "/refresh", AuthProxyController, :refresh
  post "/logout", AuthProxyController, :logout
end
```

**Verify:** `curl -X POST http://localhost:4006/api/auth/login -H "Content-Type: application/json" -d '{"user":{"email":"test@test.com","password":"password"}}'` returns auth response.

### Phase 2: Frontend Auth Store + API Client

**Create:**
- `frontend/src/lib/stores/auth.ts` — Svelte writable store:
  - State: `{token, user: {id, email}, organizationId, role, isAuthenticated}`
  - `login(email, password)` — POST to hub `/api/auth/login`, store result
  - `register(email, password)` — POST to hub `/api/auth/register`, store result
  - `logout()` — POST to hub `/api/auth/logout`, clear state + localStorage
  - `refresh()` — POST to hub `/api/auth/refresh`
  - `initialize()` — restore from localStorage, check expiry
  - Persists token to `localStorage` key `sertantai_token`
  - Follow pattern from `frontend/src/lib/stores/cases.ts`

- `frontend/src/lib/api/client.ts` — authenticated fetch wrapper:
  - Reads token from auth store
  - Attaches `Authorization: Bearer <token>` header
  - Handles 401 → clears auth, redirects to `/login`
  - Base URL from `VITE_API_URL`

- `frontend/src/lib/auth/jwt.ts` — client-side JWT payload decoder:
  - Base64 decode middle segment (no verification — backend does that)
  - Extract `exp`, `org_id`, `role`, `sub`
  - `isExpired(token)` helper

### Phase 3: Login + Register Pages

**Create:**
- `frontend/src/routes/login/+page.svelte` — login form:
  - Email + password fields (TailwindCSS v4, `@tailwindcss/forms`)
  - Submit calls auth store `login()`
  - Loading spinner, error messages
  - On success → redirect to `/`
  - Link to `/register`
  - Centered card layout matching existing `+page.svelte` style

- `frontend/src/routes/register/+page.svelte` — register form:
  - Email + password + confirm password
  - Client-side validation (password min length, match)
  - Submit calls auth store `register()`
  - On success → auto-login (auth returns token), redirect to `/`
  - Link to `/login`

### Phase 4: Auth Guard + Layout + NavBar

**Modify:**
- `frontend/src/routes/+layout.svelte` — add auth guard:
  - Import auth store, call `initialize()` on mount
  - If not authenticated and not on `/login` or `/register` → redirect to `/login`
  - If authenticated → render `NavBar` above content
  - Keep existing `QueryClientProvider` wrapper

- `frontend/src/routes/+page.svelte` — update dashboard:
  - Show welcome message with user email, org info, role
  - Keep API test card (useful for dev verification)

**Create:**
- `frontend/src/lib/components/NavBar.svelte` — top navigation:
  - Left: "SertantAI" branding
  - Right: user email, role badge, logout button
  - TailwindCSS v4

### Phase 5: Token Refresh + Error Handling

**Modify:**
- `frontend/src/lib/stores/auth.ts` — add proactive refresh:
  - On `initialize()`: if token within 5 min of expiry, refresh
  - Interval check (every 60s) for expiry
  - On refresh failure → clear auth, redirect to `/login`

- `frontend/src/lib/api/client.ts` — add 401 retry:
  - On 401 → attempt one refresh → retry original request
  - If refresh fails → clear auth, redirect to `/login`

## Files Summary

**New files (7):**
| File | Purpose |
|------|---------|
| `backend/lib/starter_app_web/controllers/auth_proxy_controller.ex` | Proxy to sertantai-auth |
| `backend/test/starter_app_web/controllers/auth_proxy_controller_test.exs` | Proxy tests |
| `frontend/src/lib/stores/auth.ts` | Auth state store |
| `frontend/src/lib/api/client.ts` | Authenticated fetch wrapper |
| `frontend/src/lib/auth/jwt.ts` | JWT payload decoder |
| `frontend/src/routes/login/+page.svelte` | Login page |
| `frontend/src/routes/register/+page.svelte` | Register page |
| `frontend/src/lib/components/NavBar.svelte` | Navigation bar |

**Modified files (6):**
| File | Change |
|------|--------|
| `backend/config/dev.exs` | Port 4000→4006, add `auth_service_url` |
| `backend/config/runtime.exs` | Add `AUTH_SERVICE_URL` env var |
| `backend/mix.exs` | Add `{:req, "~> 0.5"}` |
| `backend/lib/starter_app_web/router.ex` | Add auth proxy routes |
| `frontend/src/routes/+layout.svelte` | Auth guard, NavBar |
| `frontend/src/routes/+page.svelte` | Dashboard with user info |

## Verification

1. Start auth: `cd ~/Desktop/sertantai-auth && mix phx.server` (port 4000)
2. Start hub backend: `cd ~/Desktop/sertantai-hub/backend && mix phx.server` (port 4006)
3. Start hub frontend: `cd ~/Desktop/sertantai-hub/frontend && npm run dev` (port 5173)
4. Visit `http://localhost:5173` → should redirect to `/login`
5. Register a new user → should redirect to `/` with welcome message
6. Refresh page → should stay authenticated (localStorage restore)
7. Click logout → should redirect to `/login`
8. Login with registered user → should work
9. `mix test` in hub backend → all pass
10. `npm run check` in hub frontend → 0 errors

## Out of Scope (Future)

- HttpOnly cookie transport (production — requires hub backend to set cookie on `.sertantai.com`)
- Cross-service redirect flow (legal redirects to hub for login)
- `services` / `legalTier` JWT claims (Phase 5 in legal session)
- Password reset flow
- Email verification
