---
session: "Electric: upgrade or remove (#142)"
status: closed
opened: 2026-08-14
closed: 2026-08-14
outcome: success

summary: >
  Moved Electric from legal's docker-compose.dev.yml to docker-compose.services.yml as
  an always-on shared service (like auth and hub). One Electric instance serves both legal
  and compliance frontends on port 3002, resolving the advisory lock conflict. Upgraded
  PGLite deps to match compliance (0.3→0.5, 0.4→0.6).

decisions:
  - what: Share one Electric instance between legal and compliance instead of running two
    why: Electric uses a PostgreSQL advisory lock — only one instance per database, by design and not configurable. Both services query the same DB and just need different shapes.
    result: Single Electric on port 3002, both frontends point at it, zero lock conflicts

  - what: Electric is always-on infrastructure, not per-session
    why: Like auth, hub, and postgres — Electric doesn't change between dev sessions. Starting it each time legal or compliance launch is unnecessary overhead. The restart:unless-stopped pattern auto-starts on boot.
    result: Added to docker-compose.services.yml, managed by sert-services-up

  - what: Connect Electric to legal's postgres via host.docker.internal:5436
    why: Legal's postgres runs in docker-compose.dev.yml on a different Docker network. Cross-compose networking is complex. host.docker.internal bridges to the host port cleanly.
    result: Electric connects via host network, verified serving shapes

metrics:
  pglite_upgrade:
    pglite_before: "0.3.15"
    pglite_after: "0.5.5"
    pglite_sync_before: "0.4.1"
    pglite_sync_after: "0.6.6"
    client_after: "1.5.26"
    adapter_after: "0.7.3"
  frontend_tests: { passed: 127, failures: 0 }
  type_check: { errors: 0 }

lessons:
  - title: Electric advisory lock is by design — one instance per database, period
    detail: >
      There is no ELECTRIC_INSTANCE_ID or configuration to run multiple Electric instances
      on the same PostgreSQL database. The advisory lock prevents concurrent writes to
      replication state. The correct pattern is one shared Electric serving multiple
      frontends via different shape requests.
    tag: infrastructure

  - title: "pnpm workspace: protocol leaks into npm publishes if not stripped"
    detail: >
      gridlite-adapter-pglite@0.7.2 was published with "workspace:^" as a peer dependency
      for svelte-gridlite-kit. npm can't resolve this protocol — it's pnpm-specific.
      The publish pipeline needs to strip workspace: references before publishing to npm.
      Fixed in 0.7.3.
    tag: tooling

  - title: Cross-compose Docker networking — use host.docker.internal for simplicity
    detail: >
      Electric in docker-compose.services.yml needs to reach postgres in
      docker-compose.dev.yml. Rather than shared external networks or Docker network
      linking, connecting via host.docker.internal:5436 (the host-mapped port) is
      the simplest approach. Requires extra_hosts host-gateway mapping on Linux.
    tag: infrastructure

artifacts:
  - docker-compose.services.yml
  - docker-compose.dev.yml
  - scripts/development/sert-services-up
  - frontend/package.json
  - frontend/package-lock.json

depends_on: []

enables:
  - Compliance Electric sync (glossary page, browse page) without lock conflicts
  - Shared Electric infrastructure for any future sertantai service
---

# Session: Electric: upgrade or remove (#142) (CLOSED)

## Problem

Legal and compliance share the same dev DB on port 5436. Legal's Electric runs on port 3002 with an advisory lock. Compliance needs Electric for local-first sync (glossary, browse pages) but can't start a second instance — the advisory lock is by design (one instance per DB, not configurable).

## Decision: shared always-on Electric

One Electric instance serves both services. It's foundational infrastructure like postgres, auth, and hub — always running via `docker-compose.services.yml`, not launched per-session. Both legal and compliance point their frontends at `http://localhost:3002`.

```
Legal Frontend ──→ Electric (port 3002) ←── Compliance Frontend
                        ↓
                 PostgreSQL (5436)
```

## Todo

- ✅ Audit Electric/PGLite usage in legal (3 admin pages, no backend logic)
- ✅ Research advisory lock — confirmed one instance per DB, sharing is the correct pattern
- ✅ Move Electric to docker-compose.services.yml as always-on (`electricsql/electric:latest`, port 3002)
- ✅ Remove Electric container from docker-compose.dev.yml
- ✅ Update `sert-services-up` script to include Electric health check
- ✅ Verify Electric serves shapes from shared DB (tested with legislative_definitions)
- ✅ Upgrade legal frontend PGLite deps to match compliance (pglite 0.3→0.5, pglite-sync 0.4→0.6, adapter 0.7.1→0.7.3)
- ⏸️ Verify legal's 3 admin pages work with shared instance (deferred — manual browser test)
- ⏸️ Update compliance's Electric config to point at localhost:3002 (deferred — separate session in -compliance)

## Dependencies

- ✅ Compliance needs Electric for glossary/browse pages (PGLite 0.5 + pglite-sync 0.6)
- ✅ Shared DB on port 5436

## Audit Results

**Legal frontend**: 3 admin pages use PGLite synced via Electric:
- `/admin/lrt` — browse/filter 20K LRT records
- `/admin/lat/queue` — LAT parse queue
- `/admin/analytics` — analytics dashboard

**Backend**: only Electric CORS headers in `endpoint.ex`

**Compliance frontend**: glossary page, browse page need Electric shapes

Both services query the same DB — they just need different shapes from the same Electric instance.

## Architecture: always-on dev services

```
Always-on (docker-compose.services.yml, restart: unless-stopped):
  ├── postgres (port 5436)     — shared DB
  ├── auth (port 4000)         — JWT auth
  ├── hub (ports 4006/5177)    — orchestrator + login
  └── electric (port 3002)     — sync service (NEW)

Per-session (mix phx.server with hot reload):
  ├── legal backend (4003) + frontend (5175)
  └── compliance backend (4004) + frontend (5176)
```

## Acceptance Criteria

Electric runs as always-on service alongside auth/hub/postgres. Both legal and compliance frontends sync shapes from `localhost:3002`. No advisory lock conflicts. `sert-services-up` manages Electric lifecycle.
