Deploy sertantai-legal to production.

Runs the full deployment pipeline: build Docker images, push to GHCR, deploy to production server.

## Arguments

The user may specify:
- `$ARGUMENTS` — passed as context (e.g. "frontend only", "backend with migrations", "just check status")

## Deployment Decision Tree

Determine what changed since the last deployment to decide what to build/deploy:

1. **Frontend-only changes** (`.svelte`, `.ts` in `frontend/`, `.env.production`):
   - Build frontend: `./scripts/deployment/build-frontend.sh`
   - Push frontend: `./scripts/deployment/push-frontend.sh`
   - Deploy: `./scripts/deployment/deploy-prod.sh --frontend`

2. **Backend-only changes** (`.ex` files, migrations):
   - Build backend: `./scripts/deployment/build-backend.sh`
   - Push backend: `./scripts/deployment/push-backend.sh`
   - Deploy: `./scripts/deployment/deploy-prod.sh --backend`
   - Add `--migrate` if there are new migrations

3. **Both changed** (default):
   - Build both images (can run in parallel)
   - Push both images (can run in parallel)
   - Deploy: `./scripts/deployment/deploy-prod.sh --all`
   - Add `--migrate` if there are new migrations
   - Add `--with-electric` if Electric columns or schema changed

4. **Status check only**: `./scripts/deployment/deploy-prod.sh --check-only`

## Steps

### 1. Pre-flight checks
- Run `git status` to confirm working tree is clean (all changes committed and pushed)
- If there are uncommitted changes, warn the user and stop
- Check what files changed since last deploy tag or recent commits to determine scope

### 2. Build Docker images
Run the appropriate build scripts. Build in parallel when both are needed:
```bash
./scripts/deployment/build-backend.sh    # ~5-10 min
./scripts/deployment/build-frontend.sh   # ~1-2 min
```

### 3. Push to GHCR
Push images to GitHub Container Registry. Can run in parallel:
```bash
./scripts/deployment/push-backend.sh
./scripts/deployment/push-frontend.sh
```

### 4. Deploy to production
Run the deploy script with appropriate flags:
```bash
./scripts/deployment/deploy-prod.sh [flags]
```

**Common flag combinations:**
- `--all` — Deploy frontend + backend (default)
- `--all --migrate` — Deploy everything + run DB migrations
- `--all --migrate --with-electric` — Full deploy with migrations + Electric restart
- `--frontend` — Frontend only
- `--backend --migrate` — Backend with migrations
- `--electric` — Restart Electric only (safe restart)
- `--electric-clear-cache` — Restart Electric and clear shape cache (use after schema changes)
- `--check-only` — Just check production status, don't deploy

### 5. Post-deployment
- Verify the deploy script output shows all services healthy
- If user wants to follow logs: `--logs` flag or manual SSH

## Important Notes

- **NEVER** run `docker-compose down -v` on production — destroys data
- Electric restart uses `docker restart` (safe) — NOT `docker compose up` without `--no-deps`
- Backend auto-runs migrations on startup, but `--migrate` runs them explicitly for visibility
- Build scripts use `latest` tag by default; pass a version arg for tagged releases (e.g. `./scripts/deployment/build-backend.sh v1.2.3`)
- SSH config must have `sertantai-hz` host configured
