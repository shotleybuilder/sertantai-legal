# Production Deployment: sertantai-legal

**Started**: 2026-02-09

## Todo
- [x] Fix deployment scripts (update org name shotleybuilder, image names sertantai-legal-*)
- [x] Add sertantai-legal services to infrastructure docker-compose.yml
- [x] Add sertantai_legal_prod to postgres init SQL (with uuid-ossp, citext extensions)
- [x] Create nginx config for legal.sertantai.com
- [x] Add env vars to infrastructure .env.example
- [x] Build and push backend Docker image to GHCR
- [x] Build and push frontend Docker image to GHCR
- [x] Deploy and verify services start (all healthy)
- [x] Populate production DB from dev DB (19,318 records)
- [x] Frontend served from container (replaced static file serving)
- [x] Backend healthcheck fixed (wget not curl)
- [x] Deploy script created (`deploy-prod.sh`) with health check retries
- [x] Shell aliases added (`sert-legal-fe`, `sert-legal-be`, `sert-legal-push-fe`, `sert-legal-push-be`, `sert-legal-deploy`)
- [x] GHCR auth check fixed in push scripts
- [x] ELECTRIC_URL changed to relative `/electric` path with vite dev proxy
- [x] Production deployment SKILL.md updated
- [ ] ElectricSQL auth proxy through Phoenix (#20) — blocks data sync in prod

## Architecture
- **Backend**: Phoenix/Ash on port 4000 (internal), proxied via nginx at `/api/`
- **Frontend**: SvelteKit SPA served by `serve` container on port 3000 (internal), proxied via nginx at `/`
- **ElectricSQL**: Port 3000 (internal), proxied at `/electric/` — requires auth proxy (#20)
- **Nginx**: Sole external entry point, all services on internal Docker network (no host port mappings)
- **Health checks**: All use `docker inspect` (no host port access)

## Key Decisions
- Backend port stays at 4000 (matches Dockerfile EXPOSE and healthcheck)
- Frontend uses relative `/electric` path (works via nginx in prod, vite proxy in dev)
- Backend container uses `wget` for healthcheck (no `curl` installed in Alpine image)
- ElectricSQL auth: proxy pattern through Phoenix with JWT validation (not nginx secret injection)
- Blanket Bog requires sign-in (NOT public) — sertantai-auth must be deployed first

## References
- **SKILL.md**: `.claude/skills/production-deployment/SKILL.md`
- **GitHub Issue**: #20 — Electric auth: Proxy shape requests through Phoenix with JWT validation
- **Related Issue**: #18 — Three-tier architecture and feature gating

## Infrastructure Files Modified
- `~/Desktop/infrastructure/docker/docker-compose.yml` — added sertantai-legal, sertantai-legal-electric, sertantai-legal-frontend services; nginx dependency; backend healthcheck wget fix
- `~/Desktop/infrastructure/data/postgres-init/01-create-databases.sql` — added sertantai_legal_prod + extensions
- `~/Desktop/infrastructure/nginx/conf.d/legal.sertantai.com.conf` — proxies / to frontend container, /api/ to backend, /electric/ to Electric
- `~/Desktop/infrastructure/docker/.env.example` — added SERTANTAI_LEGAL_* variables

## sertantai-legal Files Modified
- `scripts/deployment/build-backend.sh` — updated image name, alias references
- `scripts/deployment/build-frontend.sh` — updated image name, alias references
- `scripts/deployment/push-backend.sh` — updated image name, fixed GHCR auth check
- `scripts/deployment/push-frontend.sh` — updated image name, fixed GHCR auth check
- `scripts/deployment/deploy-prod.sh` — new: SSH deploy with health checks via docker inspect
- `frontend/src/lib/electric/client.ts` — ELECTRIC_URL default → `/electric`
- `frontend/src/lib/db/index.client.ts` — ELECTRIC_URL default → `/electric`
- `frontend/src/lib/electric/sync-uk-lrt.ts` — ELECTRIC_URL default → `/electric`
- `frontend/vite.config.ts` — added dev proxy `/electric` → `localhost:3002`

**Ended**: 2026-02-13
