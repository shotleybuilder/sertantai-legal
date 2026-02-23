# Sertantai-Legal Deployment Scripts

Automated deployment scripts for building and pushing the Sertantai-Legal backend and frontend Docker images to GitHub Container Registry.

## Quick Start

```bash
# Build both backend and frontend
./scripts/deployment/build-backend.sh
./scripts/deployment/build-frontend.sh

# Push both to GHCR
./scripts/deployment/push-backend.sh
./scripts/deployment/push-frontend.sh

# Deploy via your infrastructure setup (see Infrastructure Integration below)
```

## Available Scripts

| Script | Purpose | Component | Time |
|--------|---------|-----------|------|
| **build-backend.sh** | Build backend Docker image | Phoenix/Ash API | 5-10 min |
| **build-frontend.sh** | Build frontend Docker image | SvelteKit app | 3-5 min |
| **push-backend.sh** | Push backend to GHCR | Phoenix/Ash API | 1-2 min |
| **push-frontend.sh** | Push frontend to GHCR | SvelteKit app | 1-2 min |

## Architecture

This template uses a **backend/frontend split** architecture:

- **Backend:** Phoenix + Ash Framework API (port 4003)
  - No LiveView
  - No asset compilation
  - RESTful/JSON:API endpoints
  - Database migrations via release module
  - Health check endpoint: `/health`

- **Frontend:** SvelteKit static application (port 5175)
  - Connects to backend API
  - Connects to ElectricSQL sync service
  - TanStack DB for client-side data
  - Served via `serve` utility

## Script Details

### build-backend.sh

Build the production Docker image for the Phoenix/Ash backend.

```bash
./scripts/deployment/build-backend.sh [tag]

# Examples:
./scripts/deployment/build-backend.sh           # Build with 'latest' tag
./scripts/deployment/build-backend.sh v1.2.3    # Build with version tag
```

**What it does:**
- Validates `backend/Dockerfile` exists
- Checks Docker is running
- Builds multi-stage image (builder + runner)
- Includes migrations via `SertantaiLegal.Release.migrate/0`
- Shows image size and ID

**Dockerfile features:**
- Elixir 1.18.4 + OTP 27.2
- Non-root user (UID 1000)
- Health check via wget to `/health`
- Auto-runs migrations on startup
- ERL tuning for containerized environment

---

### build-frontend.sh

Build the production Docker image for the SvelteKit frontend.

```bash
./scripts/deployment/build-frontend.sh [tag]

# Examples:
./scripts/deployment/build-frontend.sh           # Build with 'latest' tag
./scripts/deployment/build-frontend.sh v1.2.3    # Build with version tag
```

**What it does:**
- Validates `frontend/Dockerfile` exists
- Checks Docker is running
- Builds multi-stage image (builder + runner)
- Compiles SvelteKit to static build
- Shows image size and ID

**Dockerfile features:**
- Node 20 Alpine
- Non-root user (UID 1000)
- Serves static files via `serve`
- Health check via wget to root `/`

---

### push-backend.sh

Push the backend image to GitHub Container Registry.

```bash
./scripts/deployment/push-backend.sh [tag]

# Examples:
./scripts/deployment/push-backend.sh           # Push 'latest' tag
./scripts/deployment/push-backend.sh v1.2.3    # Push version tag
```

**Prerequisites:**
```bash
# One-time GHCR login
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

**Configuration:**
Update `IMAGE_NAME` in script with your GitHub org/user:
```bash
IMAGE_NAME="ghcr.io/YOUR_GITHUB_ORG/sertantai-legal-backend"
```

---

### push-frontend.sh

Push the frontend image to GitHub Container Registry.

```bash
./scripts/deployment/push-frontend.sh [tag]

# Examples:
./scripts/deployment/push-frontend.sh           # Push 'latest' tag
./scripts/deployment/push-frontend.sh v1.2.3    # Push version tag
```

**Configuration:**
Update `IMAGE_NAME` in script with your GitHub org/user:
```bash
IMAGE_NAME="ghcr.io/YOUR_GITHUB_ORG/sertantai-legal-frontend"
```

---

## Typical Workflows

### Daily Development Deployment

```bash
# 1. Make your changes
git add . && git commit -m "feat: add feature" && git push

# 2. Build both images
./scripts/deployment/build-backend.sh
./scripts/deployment/build-frontend.sh

# 3. Push to GHCR
./scripts/deployment/push-backend.sh
./scripts/deployment/push-frontend.sh

# 4. Deploy via your infrastructure
# (See Infrastructure Integration below)
```

### Version Release

```bash
# Build and tag version
./scripts/deployment/build-backend.sh v1.2.3
./scripts/deployment/build-frontend.sh v1.2.3

# Push versions
./scripts/deployment/push-backend.sh v1.2.3
./scripts/deployment/push-frontend.sh v1.2.3

# Update infrastructure docker-compose.yml to use v1.2.3
# Deploy via infrastructure
```

---

## Infrastructure Integration

This template follows the **centralized infrastructure pattern** where PostgreSQL, Redis, Nginx, and SSL are provided by your infrastructure setup.

### Infrastructure Provides:
- PostgreSQL 15+ with logical replication
- Redis (for caching/sessions)
- Nginx (reverse proxy + SSL termination)
- Docker orchestration
- SSL certificates

### Your App Provides:
- Backend Docker image (exposes port 4003)
- Frontend Docker image (exposes port 5175)
- Health endpoints for monitoring
- Runtime configuration via environment variables
- Automatic migrations on startup

### Deployment Process:

1. **Push images to GHCR** (using these scripts)

2. **Update infrastructure docker-compose.yml:**
   ```yaml
   services:
     sertantai-legal-backend:
       image: ghcr.io/YOUR_ORG/sertantai-legal-backend:latest
       environment:
         DATABASE_URL: postgresql://postgres:password@postgres:5432/sertantai_legal_prod
         SECRET_KEY_BASE: ${SECRET_KEY_BASE}
         SHARED_TOKEN_SECRET: ${SHARED_TOKEN_SECRET}  # For JWT validation
         PHX_HOST: legal.sertantai.com
       depends_on:
         - postgres

     sertantai-legal-frontend:
       image: ghcr.io/YOUR_ORG/sertantai-legal-frontend:latest
       environment:
         PUBLIC_API_URL: https://legal-api.sertantai.com
         PUBLIC_ELECTRIC_URL: https://legal-electric.sertantai.com
   ```

3. **Pull and restart on production server:**
   ```bash
   ssh your-server
   cd ~/infrastructure/docker
   docker compose pull sertantai-legal-backend sertantai-legal-frontend
   docker compose up -d sertantai-legal-backend sertantai-legal-frontend
   docker compose logs -f sertantai-legal-backend
   ```

4. **Configure Nginx reverse proxy:**
   ```nginx
   # Backend API
   server {
       listen 443 ssl;
       server_name legal-api.sertantai.com;
       location / {
           proxy_pass http://sertantai-legal-backend:4003;
       }
   }

   # Frontend
   server {
       listen 443 ssl;
       server_name legal.sertantai.com;
       location / {
           proxy_pass http://sertantai-legal-frontend:5175;
       }
   }
   ```

### Environment Variables

**Backend (.env):**
```bash
DATABASE_URL=postgresql://postgres:password@postgres:5432/sertantai_legal_prod
SECRET_KEY_BASE=your-secret-key-base-at-least-64-chars
SHARED_TOKEN_SECRET=same-as-sertantai-auth-service
PHX_HOST=legal-api.sertantai.com
FRONTEND_URL=https://legal.sertantai.com
POOL_SIZE=10
```

**Frontend (.env):**
```bash
PUBLIC_API_URL=https://legal-api.sertantai.com
PUBLIC_ELECTRIC_URL=https://legal-electric.sertantai.com
```

See `backend/.env.example` and `frontend/.env.example` for complete lists.

---

## Script Configuration

Before using the scripts, update the `IMAGE_NAME` variable in each script:

**In build-backend.sh and push-backend.sh:**
```bash
IMAGE_NAME="ghcr.io/YOUR_GITHUB_ORG/sertantai-legal-backend"
```

**In build-frontend.sh and push-frontend.sh:**
```bash
IMAGE_NAME="ghcr.io/YOUR_GITHUB_ORG/sertantai-legal-frontend"
```

Replace `YOUR_GITHUB_ORG` with your GitHub organization or username.

---

## Prerequisites

### For Building
- Docker installed and running
- Dockerfiles present in backend/ and frontend/
- Source code for backend and frontend

### For Pushing
- Images built locally
- GHCR authentication configured
- Network connectivity
- GitHub PAT with `write:packages` scope

### For Deploying
- Production infrastructure setup (PostgreSQL, Redis, Nginx)
- Docker Compose on production server
- SSH access to production server
- Environment variables configured

---

## Troubleshooting

### Build fails

```bash
# Check Docker is running
docker info

# Check Dockerfiles exist
ls -la backend/Dockerfile frontend/Dockerfile

# Check for syntax errors
docker build --no-cache -f backend/Dockerfile backend/
```

### Push fails

```bash
# Login to GHCR
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Verify images exist
docker images | grep sertantai-legal

# Check GHCR permissions
# Ensure your GitHub PAT has write:packages scope
```

### Backend container fails to start

```bash
# Check logs
docker logs sertantai-legal-backend

# Common issues:
# - DATABASE_URL not set or incorrect
# - PostgreSQL not reachable (check host, should be 'postgres' not 'localhost')
# - SECRET_KEY_BASE not set
# - Migrations failed (check database permissions)
```

### Frontend container fails to start

```bash
# Check logs
docker logs sertantai-legal-frontend

# Common issues:
# - Build artifacts missing (rebuild with --no-cache)
# - PUBLIC_API_URL not set
# - CORS issues (check backend FRONTEND_URL config)
```

---

## Health Checks

**Backend:**
- Endpoint: `http://localhost:4003/health`
- Expected: `{"status": "ok", "service": "sertantai-legal", "timestamp": "..."}`
- Detailed: `http://localhost:4003/health/detailed` (includes database check)

**Frontend:**
- Endpoint: `http://localhost:3002/`
- Expected: HTTP 200 with HTML

**Docker health checks:**
Both containers include health checks that Docker uses for monitoring.

---

## Script Features

All scripts include:
- ✅ Colored terminal output
- ✅ Progress indicators
- ✅ Built-in validation
- ✅ Error handling with helpful messages
- ✅ Next-step suggestions
- ✅ Comprehensive help text

---

## Documentation

**Related Documentation:**
- [README.md](../../README.md) - Project overview and setup
- [CLAUDE.md](../../CLAUDE.md) - Development guide for AI assistants
- [Infrastructure Integration Guide](https://github.com/YOUR_ORG/infrastructure/docs/standardisation/NEW_APP_INTEGRATION.md) - Centralized infrastructure setup

**Additional Resources:**
- [Phoenix Releases](https://hexdocs.pm/phoenix/releases.html)
- [SvelteKit Deployment](https://kit.svelte.dev/docs/adapters)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

---

**Last Updated:** 2025-11-15
**Scripts Version:** 1.0
