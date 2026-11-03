---
session: Svelte 5 Migration
status: closed
opened: 2026-08-22
closed: 2026-08-23
outcome: success

summary: >
  Migrated the entire frontend from Svelte 4.2 to Svelte 5.56 with runes, snippet slots, and
  TanStack Query v6. All 32 components converted, production build clean, dev server smoke test
  passed. Uncovered and fixed three containerised dev environment issues (GitHub OAuth, cookie
  SameSite, hub service health checks) during smoke testing.

decisions:
  - what: Upgrade to Svelte 5 runes API across all 32 components
    why: Svelte 5 stable since late 2024, staying on 4 blocks library upgrades and new patterns
    result: 0 type errors, 26 pre-existing warnings, clean 9.08s production build
  - what: Remove TanStack DB, keep PGLite adapter for GridLite
    why: TanStack DB was an unnecessary layer; GridLite works directly with PGLite adapter
    result: Removed @tanstack/db and gridlite-adapter-tanstack-db, simplified lrt + lat/queue pages
  - what: Defer Vite 5→6 and TypeScript 5→7 upgrades
    why: vite-plugin-svelte@4 and svelte-check@4 support current versions, no blocking issues
    result: Smaller blast radius for this migration
  - what: Make SameSite cookie attribute configurable in sertantai-auth
    why: SameSite=Strict drops cookies on cross-site GitHub OAuth redirects in dev
    result: Dev uses Lax, production stays Strict via SERTANTAI_AUTH_COOKIE_SAME_SITE env var
  - what: Add /auth/callback route to legal frontend
    why: Hub ServiceTile passes JWT via URL for cross-service SSO when running as containers
    result: Hub→Legal tile navigation works with token handoff

metrics:
  migration:
    components_migrated: 32
    lines_of_code: 17700
    type_errors: 0
    warnings: 26
    build_time_seconds: 9.08

lessons:
  - title: Clearing .svelte-kit cache is required after major Svelte version upgrades
    detail: >
      After upgrading from Svelte 4 to 5, the generated files in .svelte-kit still used
      `new Root()` (Svelte 4 API), causing component_api_invalid_new runtime errors.
      Deleting .svelte-kit and letting SvelteKit regenerate fixes it.
    tag: tooling
  - title: Containerised dev services need explicit env vars that bare-metal dev gets for free
    detail: >
      When auth/hub ran bare-metal, GitHub OAuth env vars came from .bashrc and the cookie
      domain was implicitly localhost. Switching to Docker containers required explicitly
      passing GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET, GITHUB_REDIRECT_URI,
      SERTANTAI_AUTH_GITHUB_OAUTH_REDIRECT_URL, and SERTANTAI_AUTH_COOKIE_SAME_SITE
      through docker-compose.services.yml. The env vars existed but weren't plumbed through.
    tag: infrastructure
  - title: Docker containers can't reach host services via localhost
    detail: >
      Hub backend container checking legal health at localhost:4003 gets connection refused
      because localhost inside the container is the container itself. Need extra_hosts
      host.docker.internal:host-gateway and LEGAL_SERVICE_URL=http://host.docker.internal:4003.
    tag: infrastructure
  - title: Cross-service navigation needs /auth/callback routes in each micro-app
    detail: >
      When services run as separate origins, the hub ServiceTile passes JWT tokens via
      /auth/callback?token=...&dest=/path URL pattern. Each micro-app frontend needs
      this route to store the token in localStorage and redirect. Without it, clicking
      service tiles from the hub dashboard 404s.
    tag: infrastructure

artifacts:
  - frontend/src/routes/auth/callback/+page.svelte
  - docker-compose.services.yml

enables:
  - Future Svelte 5 features (fine-grained reactivity, snippets in libraries)
  - Library upgrades that require Svelte 5 peer dependency
---

# Session: Svelte 5 Migration (CLOSED)

## Problem

The frontend is on Svelte 4.2 with legacy reactive patterns (`export let`, `$:`, `on:event`, `<slot>`). Svelte 5 has been stable since late 2024 — all tooling and dependencies (SvelteKit 2, gridlite-kit 0.7.x, PGLite) already support it. Staying on 4 blocks future library upgrades and means new code can't use runes. 32 components, ~17,700 lines need mechanical migration.

## Todo

- ✅ Upgrade packages: svelte 5.56.10, vite-plugin-svelte 4.0.4, svelte-check 4.7.6, prettier-plugin-svelte 4.1.1, pglite 0.5.6, pglite-sync 0.6.7, gridlite-kit 0.10.0, tanstack/svelte-query 6.1.38
- ✅ Remove TanStack DB: uninstall @tanstack/db, gridlite-adapter-tanstack-db; delete collection-bridge.ts
- ✅ Migrate TanStack Query v5→v6: accessor pattern in 6 hook files, remove `$` prefix in all consumers
- ✅ Switch lrt + lat/queue GridLite pages from TanStack DB adapter → PGLite adapter
- ✅ Migrate layout files: `+layout.svelte` (3 files) — slots → `{@render children()}`
- ✅ Migrate shared components: 11 files in `src/lib/components/` — props, events, reactivity
- ✅ Migrate page components: 19 files in `src/routes/` — reactivity, events
- ✅ ESLint: all `$state()` additions done, 26 pre-existing warnings remain (self-closing tags, a11y labels)
- ✅ Type check (`npm run check`) — 0 errors, 26 warnings
- ✅ Production build (`npm run build`) — clean (9.08s)
- ✅ Dev server smoke test — pages load without runtime errors

## Dependencies

- ✅ SvelteKit 2.70.3 supports Svelte 5 (peerDep `^4 || ^5`)
- ✅ @sveltejs/adapter-static 3.0.10 compatible
- ✅ gridlite-kit 0.7.1 → 0.10.0 (slots → snippets converted)
- ⏸️ gridlite-adapter-pglite peer dep still ^0.7.0 (installed with --legacy-peer-deps, works at runtime)
- ✅ PGLite/Electric packages are framework-agnostic
- ⏸️ Vite 5→6+ upgrade deferred (vite-plugin-svelte@4 supports Vite 5)
- ⏸️ TypeScript 5→7 deferred (svelte-check@4 supports TS 5)
- ✅ gridlite-adapter-tanstack-db removed (no longer needed)

## Migration Patterns

| Svelte 4 | Svelte 5 |
|----------|----------|
| `export let x` | `let { x } = $props()` |
| `$: derived = expr` | `let derived = $derived(expr)` |
| `$: { sideEffect() }` | `$effect(() => { sideEffect() })` |
| `on:click={handler}` | `onclick={handler}` |
| `on:click\|preventDefault` | `onclick={(e) => { e.preventDefault(); handler(e) }}` |
| `<slot />` | `{@render children()}` with `children: Snippet` prop |
| `createEventDispatcher` | callback props (`onchange`, `onsubmit`, etc.) |
