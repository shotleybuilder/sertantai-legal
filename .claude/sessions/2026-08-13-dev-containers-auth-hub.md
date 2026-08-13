---
session: Dev Containers for Auth & Hub
status: active
opened: 2026-08-13
---

# Session: Dev Containers for Auth & Hub (ACTIVE)

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
- ⬜ Test full flow: reboot → containers auto-start → `sert-legal-start` detects them → legal tabs only
- ✅ Update `scripts/development/README.md` with new workflow

## Dependencies

- ✅ Docker enabled on boot
- ✅ Auth GHCR image published
- ✅ Auth docker-compose.dev.yml has `app` service definition
- ✅ Hub has Dockerfile.dev for local build
- ⬜ Hub frontend needs Dockerfile.dev (exists at `~/Desktop/sertantai-hub/frontend/Dockerfile.dev`)
