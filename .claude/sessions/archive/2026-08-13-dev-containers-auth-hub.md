---
session: Dev Containers for Auth & Hub
status: closed
opened: 2026-08-13
closed: 2026-08-13
outcome: success

summary: >
  Replaced source-based auth + hub startup (5+ terminal tabs, minutes of compilation)
  with always-on GHCR containers that auto-restart on boot. Daily workflow is now just
  `sert-legal-start` for two tabs. Hub frontend uses runtime env injection so one GHCR
  image works for both production and local dev.

decisions:
  - what: Use GHCR release images (not Dockerfile.dev builds) for auth + hub containers
    why: Dockerfile.dev builds were fragile (npm ci platform issues, dev.exs hardcoded hostnames). GHCR release images match production, use runtime.exs with env vars, and are already tested.
    result: Clean compose file mirroring sertantai-stack production pattern

  - what: Runtime env injection via window.__ENV__ for hub frontend
    why: VITE_* vars are baked in at build time — building separate :dev images or swapping .env files is fragile. Gemini review recommended runtime injection as the standard pattern.
    result: One GHCR image works everywhere. docker-entrypoint.sh generates env-config.js from VITE_* env vars at container startup.

  - what: Point containers at _dev databases (not _prod)
    why: Dev user accounts and data were in sertantai_auth_dev / sertantai_hub_dev from previous source-based dev setup. Using _prod databases would lose this data.
    result: Auth found 3 existing user accounts, sign-in flow works

  - what: Map auth container port 4001 → host port 4000
    why: Auth GHCR image runs internally on 4001 (hardcoded healthcheck), but canonical dev port allocation is 4000 per hub README.
    result: All services match the documented port allocation table

metrics:
  containers: { total: 6, auth: 2, hub: 4 }
  daily_startup: { before: "5+ tabs, 2-3 min compilation", after: "2 tabs, instant" }

lessons:
  - title: GHCR release images need runtime env vars, not dev.exs hardcoded values
    detail: Hub's dev.exs hardcodes hostname localhost and port 5438 for auth DB. Inside Docker containers, localhost means the container itself. Using MIX_ENV=dev in containers is fundamentally broken for multi-container setups. Always use MIX_ENV=prod with runtime.exs for containerized services.
    tag: infrastructure

  - title: SvelteKit static builds bake VITE_* vars at build time
    detail: Unlike Phoenix (runtime env vars), Vite inlines env vars during `npm run build`. The standard solution is runtime injection via window.__ENV__ with a docker-entrypoint.sh that generates env-config.js. This is the pattern used by Create React App, Next.js standalone, etc.
    tag: infrastructure

  - title: Docker external volumes preserve data across compose file changes
    detail: When switching from per-repo compose files to a unified services compose, use external volumes with explicit names to reference existing data. New compose creates new volumes by default — data appears lost but is still in the old volumes.
    tag: infrastructure

  - title: npm ci fails on cross-platform lockfiles in Docker
    detail: If package-lock.json was generated on a machine with optional deps for different platforms (e.g. @esbuild/netbsd-arm64), npm ci will fail in Docker (linux/x64). Use npm install instead — it tolerates platform mismatches for optional deps.
    tag: tooling

artifacts:
  - docker-compose.services.yml
  - .env
  - scripts/development/sert-services-up
  - scripts/development/sert-legal-start
  - scripts/development/sert-legal-stop
  - scripts/development/README.md

enables:
  - Reboot-and-go development workflow
  - Future services (compliance, enforcement) can follow the same container pattern
---

# Session: Dev Containers for Auth & Hub (CLOSED)

## Problem

Starting development requires `sert-legal-start --docker --auth --hub` which opens 5+ terminal tabs, compiles auth and hub from source each time, and takes minutes. Auth and hub rarely change — they should run as containers that auto-start on boot so `sert-legal-start` only launches legal's backend + frontend tabs.

## Current State

- **Auth**: GHCR image exists (`ghcr.io/shotleybuilder/sertantai-auth:latest`), already defined as `app` service in auth's docker-compose.dev.yml on port 4001. Legal expects auth on port 4000.
- **Hub**: No GHCR image. Has Dockerfile.dev (builds from source in container). Backend on 4006, frontend on 5173.
- **Docker**: Enabled on boot (`systemctl is-enabled docker` → `enabled`).
- **Legal's dev.exs**: `auth_url: "http://localhost:4000"`.

## Todo

- ✅ Create `docker-compose.services.yml` — GHCR release images for auth + hub, mirrors sertantai-stack production pattern
- ✅ `.env` for dev secrets (JWT key, TOTP key) — gitignored
- ✅ `sert-services-up` script — pulls GHCR images, manages volumes, health checks
- ✅ Update `sert-legal-start` — auto-detects containerized auth/hub, legacy `--auth`/`--hub` still work
- ✅ Update `sert-legal-stop` — `--services` flag stops containers, `--auth`/`--hub` handle both modes
- ⏸️ Test full flow: reboot → containers auto-start → `sert-legal-start` detects them (deferred — verify on next reboot)
- ✅ Update `scripts/development/README.md` with new workflow

## Dependencies

- ✅ Docker enabled on boot
- ✅ Auth GHCR image published
- ✅ Auth docker-compose.dev.yml has `app` service definition
- ✅ Hub has Dockerfile.dev for local build
- ✅ Hub frontend — uses GHCR release image with runtime env injection (not Dockerfile.dev)
