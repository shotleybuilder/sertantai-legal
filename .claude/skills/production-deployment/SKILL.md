# SKILL: Production Deployment to Hetzner

**Purpose:** Deploy sertantai-legal (or a new microservice) to the shared Hetzner infrastructure

**Context:** Docker, GHCR, PostgreSQL 16, ElectricSQL, Nginx, Let's Encrypt, ~/Desktop/infrastructure

**When to Use:**
- First-time deployment of a new microservice
- Rebuilding and redeploying after code changes
- Restoring production data from dev

---

## Core Principles

1. **Infrastructure is shared** — PostgreSQL, Redis, Nginx, and networking live in `~/Desktop/infrastructure`, not in the service repo
2. **Schema before data** — Never restore a database dump until migrations have been verified to produce an identical schema
3. **Migrations are the source of truth** — If a column exists in dev but not in a migration, it won't exist in prod. Fix the migration first.
4. **ElectricSQL instances need unique identifiers** — Multiple Electric instances on the same PostgreSQL cluster will conflict on replication slots
5. **Alpine versions must match** — The Docker builder stage and runner stage must use the same Alpine/OpenSSL version or NIF libraries will fail to load
6. **No host port mappings** — All services communicate via the `infra_network` Docker network. Health checks must use `docker inspect` or `docker exec`, not `curl localhost`.

## Deployment Scripts & Aliases

All deployment scripts live in `scripts/deployment/`. Shell aliases are defined in `~/.bashrc`:

| Alias | Script | Purpose |
|-------|--------|---------|
| `sert-legal-fe` | `build-frontend.sh` | Build frontend Docker image |
| `sert-legal-be` | `build-backend.sh` | Build backend Docker image |
| `sert-legal-push-fe` | `push-frontend.sh` | Push frontend image to GHCR |
| `sert-legal-push-be` | `push-backend.sh` | Push backend image to GHCR |
| `sert-legal-deploy` | `deploy-prod.sh` | Deploy to production server |

### deploy-prod.sh Options

```bash
sert-legal-deploy                    # Deploy frontend + backend (default)
sert-legal-deploy --frontend         # Frontend only
sert-legal-deploy --backend          # Backend only
sert-legal-deploy --electric         # Restart ElectricSQL only
sert-legal-deploy --with-electric    # Backend + ElectricSQL
sert-legal-deploy --electric-clear-cache  # Recreate Electric (clears shape cache)
sert-legal-deploy --migrate          # Run database migrations after restart
sert-legal-deploy --check-only       # Check status without deploying
sert-legal-deploy --logs             # Follow logs after deployment
```

### Typical Deploy Workflow

```bash
# 1. Build and push (on laptop)
sert-legal-fe && sert-legal-push-fe
sert-legal-be && sert-legal-push-be

# 2. Deploy to server (SSHs automatically)
sert-legal-deploy

# Or frontend only:
sert-legal-fe && sert-legal-push-fe && sert-legal-deploy --frontend
```

## Infrastructure Files to Modify

When adding a new service, these files in `~/Desktop/infrastructure` need updating:

| File | Change |
|------|--------|
| `docker/docker-compose.yml` | Add service + Electric containers |
| `docker/.env.example` | Add service-specific env vars |
| `data/postgres-init/01-create-databases.sql` | Add `CREATE DATABASE` + extensions |
| `nginx/conf.d/<domain>.conf` | Create nginx config with SSL, API proxy, Electric proxy |

**Commit and push** these changes so they can be `git pull`ed on the server.

## Container Architecture

All services run on the internal `infra_network` Docker network with no host port mappings. Nginx is the sole entry point.

```
legal.sertantai.com (Nginx :443)
  /          → sertantai-legal-frontend:3000  (SvelteKit via serve)
  /api/      → sertantai-legal:4000           (Phoenix API)
  /electric/ → sertantai-legal-electric:3000  (ElectricSQL)
  /health    → sertantai-legal:4000/health
```

### Container Health Checks

Health checks are defined in docker-compose.yml and use tools available inside each container:

| Container | Tool | Command |
|-----------|------|---------|
| `sertantai_legal_app` | `wget` | `wget --spider http://localhost:4000/health` |
| `sertantai_legal_frontend` | `wget` | `wget --spider http://localhost:3000/` |
| `sertantai_legal_electric` | `curl` | `curl -f http://localhost:3000/v1/health` |

**Important:** The backend container does NOT have `curl` — use `wget` for health checks. The deploy script checks health via `docker inspect --format='{{.State.Health.Status}}'`.

## Common Pitfalls & Solutions

### Pitfall 1: Elixir Regex in Module Attributes (Elixir 1.18+)

Elixir 1.18+ forbids NIF references (compiled Regex structs) in module attributes injected into function bodies. Local compilation may succeed due to cached BEAM files, but Docker builds compile fresh and will fail.

```
# error: Failed to load NIF library
```

- Store raw pattern strings in module attributes
- Compile to Regex at runtime using `:persistent_term` for caching
- See `backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex` for the pattern

### Pitfall 2: Alpine Version Mismatch in Dockerfile

```
# error: Error relocating crypto.so: EVP_PKEY_sign_message_init: symbol not found
```

The `elixir:1.18.4-alpine` image uses Alpine 3.23 with OpenSSL 3.5. If your runner stage uses an older Alpine, the Erlang crypto NIF won't load.

```dockerfile
# Check what Alpine the builder uses:
# docker run --rm elixir:1.18.4-alpine cat /etc/alpine-release
# → 3.23.3

# Runner MUST match:
FROM alpine:3.23   # NOT 3.19 or 3.21
```

### Pitfall 3: ElectricSQL Replication Slot Conflict

Multiple Electric instances default to `electric_slot_default`. Replication slots are cluster-wide in PostgreSQL — even across different databases, the lock acquisition will conflict.

```yaml
# Set ELECTRIC_REPLICATION_STREAM_ID to give each instance unique slot/publication names
# This creates electric_slot_<id> and electric_publication_<id>
environment:
  - ELECTRIC_REPLICATION_STREAM_ID=legal    # → electric_slot_legal
```

`ELECTRIC_SLOT_NAME` and `ELECTRIC_PUBLICATION_NAME` env vars do NOT work in ElectricSQL 1.4+. Use `ELECTRIC_REPLICATION_STREAM_ID` instead.

### Pitfall 4: GHCR Authentication

- GHCR packages are **private by default** — the server needs `docker login ghcr.io` with a PAT that has `read:packages` scope
- PATs expire — if pushes or pulls suddenly fail with `denied`, regenerate the PAT
- The `gh` CLI token is separate from the Docker credential store token
- Push scripts check `~/.docker/config.json` for GHCR credentials and fail fast if not logged in

```bash
# Login to GHCR (both laptop and server need this)
echo "YOUR_PAT" | docker login ghcr.io -u shotleybuilder --password-stdin
```

### Pitfall 5: pg_dump/pg_restore vs psql COPY

Never use `psql -f` or pipe SQL text files for data restores. PostgreSQL 16's `pg_dump` adds `\restrict` directives, and `COPY FROM STDIN` blocks require precise stdin handling that breaks through Docker exec.

```bash
# Use custom format — always works, handles encoding natively
pg_dump --format=custom -f dump.dump   # export
pg_restore dump.dump                    # import
```

### Pitfall 6: Schema Drift Between Dev and Prod

If dev was populated from a legacy dump (e.g., Airtable export), it may have columns that don't exist in Ash migrations. The `pg_restore` will fail with "column X does not exist".

**Fix:** Compare schemas, then create a migration to align them BEFORE restoring data.

```bash
# Compare column counts
psql -d dev_db -c "SELECT count(*) FROM information_schema.columns WHERE table_name = 'uk_lrt';"
psql -d prod_db -c "SELECT count(*) FROM information_schema.columns WHERE table_name = 'uk_lrt';"
# These MUST match before restoring data
```

### Pitfall 7: SSL Cert with Nginx Already Running

`certbot --webroot` fails if nginx catches the ACME challenge request and routes it to another service. Use standalone mode instead:

```bash
docker compose stop nginx
sudo certbot certonly --standalone -d legal.sertantai.com
docker compose start nginx
```

### Pitfall 8: postgres-init SQL Only Runs Once

The `data/postgres-init/01-create-databases.sql` only executes on first PostgreSQL container creation. If postgres is already running, create the database manually:

```bash
docker exec shared_postgres psql -U postgres -c "CREATE DATABASE sertantai_legal_prod;"
docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; CREATE EXTENSION IF NOT EXISTS \"citext\";"
```

### Pitfall 9: Health Check Tool Mismatch

Backend container is Alpine-based and only has `wget`, not `curl`. If docker-compose.yml healthcheck uses `curl`, the container will always show `unhealthy`.

```yaml
# WRONG — curl not installed:
test: ["CMD", "curl", "-f", "http://localhost:4000/health"]

# CORRECT — wget is available:
test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4000/health"]
```

## Working Deployment Sequence

### Phase 1: Prepare Infrastructure (on laptop)

```bash
cd ~/Desktop/infrastructure

# 1. Edit docker/docker-compose.yml — add service containers
# 2. Edit docker/.env.example — add service env vars
# 3. Edit data/postgres-init/01-create-databases.sql — add database
# 4. Create nginx/conf.d/<domain>.conf

git add -A && git commit -m "feat: Add <service> infrastructure"
git push
```

### Phase 2: Build and Push Docker Images (on laptop)

```bash
# Build
sert-legal-be
sert-legal-fe

# Push (ensure GHCR login is current)
sert-legal-push-be
sert-legal-push-fe
```

### Phase 3: Server Setup (SSH to hetzner — first time only)

```bash
ssh sertantai-hz

# 1. Pull infrastructure updates
cd ~/infrastructure
git pull

# 2. DNS — ensure A record points to server IP
dig legal.sertantai.com +short  # should return 46.224.29.187

# 3. Generate secrets
openssl rand -base64 64 | tr -d '\n' && echo   # SECRET_KEY_BASE
openssl rand -base64 32 | tr -d '\n' && echo   # ELECTRIC_SECRET

# 4. Add secrets to .env
nano docker/.env

# 5. Create database (postgres already running)
docker exec shared_postgres psql -U postgres -c "CREATE DATABASE sertantai_legal_prod;"
docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; CREATE EXTENSION IF NOT EXISTS \"citext\";"

# 6. SSL cert
docker compose -f docker/docker-compose.yml stop nginx
sudo certbot certonly --standalone -d legal.sertantai.com
docker compose -f docker/docker-compose.yml start nginx
```

### Phase 4: Deploy Services

```bash
# From laptop — handles SSH, pull, restart, health checks automatically:
sert-legal-deploy

# Or deploy individual components:
sert-legal-deploy --frontend
sert-legal-deploy --backend
sert-legal-deploy --backend --with-electric
```

### Phase 5: Populate Data (on laptop, then server)

**Critical: Verify schema parity first**

```bash
# On laptop — count dev columns
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT count(*) FROM information_schema.columns WHERE table_name = 'uk_lrt';"

# On server — count prod columns (should match)
docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c "SELECT count(*) FROM information_schema.columns WHERE table_name = 'uk_lrt';"
```

**If they match, dump and restore:**

```bash
# On laptop — dump in custom format
PGPASSWORD=postgres pg_dump -h localhost -p 5436 -U postgres \
  -d sertantai_legal_dev --data-only --no-owner --no-acl \
  --format=custom -f /tmp/sertantai_legal_data.dump

# Transfer to server
scp /tmp/sertantai_legal_data.dump sertantai-hz:/tmp/

# On server — stop services, restore, restart
docker compose stop sertantai-legal sertantai-legal-electric
docker cp /tmp/sertantai_legal_data.dump shared_postgres:/tmp/
docker exec shared_postgres pg_restore -U postgres -d sertantai_legal_prod \
  --data-only --no-owner --no-acl --disable-triggers \
  /tmp/sertantai_legal_data.dump

# Verify row count
docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c "SELECT count(*) FROM uk_lrt;"
# Expected: 19318

# Restart services (force-recreate Electric to clear cached state)
docker compose up -d --force-recreate sertantai-legal-electric
docker compose up -d --force-recreate sertantai-legal
docker compose exec nginx nginx -s reload
```

**If schemas don't match:**
1. Find the missing columns: compare column lists from both databases
2. Determine if they should be in a migration (used by the app) or dropped (legacy cruft)
3. Create and run the migration on dev first, then rebuild the Docker image
4. Deploy the new image to prod, verify column counts match, then restore data

## Troubleshooting

### Backend container keeps restarting
```bash
docker compose logs sertantai-legal --tail 50
```
- **crypto NIF error** → Alpine version mismatch (see Pitfall 2)
- **database does not exist** → Create it manually (see Pitfall 8)
- **connect raised UndefinedFunctionError** → Usually the crypto NIF issue

### Backend shows "unhealthy" but logs show 200s
The docker-compose healthcheck is using a tool not available in the container (e.g., `curl` instead of `wget`). See Pitfall 9.

### ElectricSQL stuck on "waiting_on_lock"
```bash
docker compose logs sertantai-legal-electric --tail 50
```
- Check for "Replication slot already in use" → Set `ELECTRIC_REPLICATION_STREAM_ID` (see Pitfall 3)
- Check `pg_replication_slots` for conflicts:
  ```bash
  docker exec shared_postgres psql -U postgres \
    -c "SELECT slot_name, database, active FROM pg_replication_slots;"
  ```

### 502 Bad Gateway after deploy
Backend takes ~5-10 seconds to start (runs migrations first). The deploy script retries health checks 6 times over 30 seconds. If still failing, check logs.

### pg_restore fails with "column X does not exist"
Schema drift — see Pitfall 6. Fix migrations before restoring data.

### pg_restore fails with "duplicate key" on schema_migrations
Harmless — the migrations table was already populated when the container ran migrations on startup. Use `--data-only` to avoid this, or ignore the warning.

## Quick Reference

### SSH to server
```bash
ssh sertantai-hz
```

### Key paths on server
| Path | Purpose |
|------|---------|
| `~/infrastructure/docker/` | docker-compose.yml and .env |
| `~/infrastructure/nginx/conf.d/` | Nginx site configs |
| `/etc/letsencrypt/live/legal.sertantai.com/` | SSL certs |

### Key ports (internal to Docker network — no host mappings)
| Service | Container Name | Port |
|---------|---------------|------|
| PostgreSQL | `shared_postgres` | 5432 |
| sertantai-legal (Phoenix) | `sertantai_legal_app` | 4000 |
| sertantai-legal-electric | `sertantai_legal_electric` | 3000 |
| sertantai-legal-frontend | `sertantai_legal_frontend` | 3000 |
| sertantai-auth | `sertantai_auth_app` | 4001 |
| sertantai-enforcement | `sertantai_enforcement_app` | 4002 |

### Docker image names
```
ghcr.io/shotleybuilder/sertantai-legal-backend:latest
ghcr.io/shotleybuilder/sertantai-legal-frontend:latest
```

### Rebuild and deploy cycle
```bash
# On laptop — full cycle
sert-legal-be && sert-legal-push-be && sert-legal-fe && sert-legal-push-fe && sert-legal-deploy

# Frontend only
sert-legal-fe && sert-legal-push-fe && sert-legal-deploy --frontend

# Backend only
sert-legal-be && sert-legal-push-be && sert-legal-deploy --backend
```

## Related Skills

- [Docker Restart](../docker-restart/) — Safe restart of local dev services
- [Stale Electric Shapes](../stale-electric-shapes/) — Recovering from broken ElectricSQL shapes
- [ElectricSQL Sync Setup](../electricsql-sync-setup/) — Setting up sync for new resources

## Key Takeaways

- **Use the deployment scripts** — `sert-legal-deploy` handles SSH, pulling, restarting, and health checks
- **Always use `--format=custom`** for pg_dump/pg_restore — never plain SQL text
- **Always verify schema parity** before restoring data
- **Always use `ELECTRIC_REPLICATION_STREAM_ID`** when running multiple Electric instances
- **Always match Alpine versions** between Docker builder and runner stages
- **Always use `wget` not `curl`** for backend container health checks
- **Always check GHCR PAT expiry** when pushes/pulls fail with "denied"
- **Never use `docker compose down -v`** on production — it destroys data volumes
- **Never assume localhost is reachable** — services have no host port mappings, use `docker inspect` or `docker exec`
