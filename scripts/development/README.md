# Development Scripts

Start/stop scripts for sertantai-legal (Phoenix + ElectricSQL + SvelteKit).

Auth and Hub run as always-on Docker containers that auto-restart on boot.

## Quick Start

```bash
# One-time: bootstrap auth + hub containers
sert-services-up

# Daily: start legal dev servers (2 tabs — backend + frontend)
sert-legal-start

# Stop legal servers
sert-legal-stop
```

## Architecture

```
Always-on containers (auto-restart on boot):
  sertantai-auth          port 4000  (GHCR image)
  sertantai-auth-postgres port 5438
  sertantai-hub-backend   port 4006  (built from Dockerfile.dev)
  sertantai-hub-frontend  port 5173  (login UI)
  sertantai-hub-postgres  port 5435
  sertantai-hub-electric  port 3000

Legal Docker (auto-start when sert-legal-start runs):
  sertantai-legal-postgres port 5436
  sertantai-legal-electric port 3002

Legal dev servers (terminal tabs):
  Phoenix backend          port 4003
  SvelteKit frontend       port 5175
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sert-services-up` | Bootstrap / manage auth + hub containers |
| `sert-legal-start` | Start legal backend + frontend in terminal tabs |
| `sert-legal-stop` | Stop legal servers |
| `sert-legal-restart` | Force-stop then restart (with port cleanup) |

### sert-services-up

Manages the auth + hub container stack (`docker-compose.services.yml`).

```bash
sert-services-up              # Start or verify containers are running
sert-services-up --build      # Rebuild hub images (after hub code changes)
sert-services-up --status     # Show container status
sert-services-up --stop       # Stop containers (won't auto-restart until re-run)
```

First run pulls the auth GHCR image and builds hub images (~2-5 min).
After that, container restarts are instant.

### sert-legal-start

Opens terminal tabs for legal's Phoenix backend and SvelteKit frontend.
Auto-starts legal's Docker containers (postgres + electric) if not running.
Detects whether auth + hub containers are healthy and reports status.

```bash
sert-legal-start              # Normal start (auto-detects services)
sert-legal-start --docker     # Force restart legal Docker containers
sert-legal-start --zenoh      # Enable Zenoh P2P mesh
sert-legal-start --auth       # Legacy: start auth from source
sert-legal-start --hub        # Legacy: start hub from source
```

### sert-legal-stop

```bash
sert-legal-stop               # Stop legal servers only
sert-legal-stop --docker      # Also stop legal Docker containers
sert-legal-stop --services    # Also stop auth + hub containers
sert-legal-stop --auth        # Stop auth only (container or source)
sert-legal-stop --hub         # Stop hub only (container or source)
```

## Symlink Setup

```bash
# From the sertantai-legal project root
sudo ln -sf $(pwd)/scripts/development/sert-services-up /usr/local/bin/sert-services-up
sudo ln -sf $(pwd)/scripts/development/sert-legal-start /usr/local/bin/sert-legal-start
sudo ln -sf $(pwd)/scripts/development/sert-legal-stop /usr/local/bin/sert-legal-stop
sudo ln -sf $(pwd)/scripts/development/sert-legal-restart /usr/local/bin/sert-legal-restart
```

## Port Allocation

| Service | Port | Project |
|---------|------|---------|
| sertantai-auth Phoenix | 4000 | sertantai-auth |
| sertantai-auth PostgreSQL | 5438 | sertantai-auth |
| sertantai-hub Phoenix | 4006 | sertantai-hub |
| sertantai-hub Frontend | 5173 | sertantai-hub |
| sertantai-hub PostgreSQL | 5435 | sertantai-hub |
| sertantai-hub Electric | 3000 | sertantai-hub |
| sertantai-legal Phoenix | 4003 | sertantai-legal |
| sertantai-legal PostgreSQL | 5436 | sertantai-legal |
| sertantai-legal Electric | 3002 | sertantai-legal |
| sertantai-legal Frontend | 5175 | sertantai-legal |

## Rebuilding Hub Images

When hub code changes (rare), rebuild the container images:

```bash
sert-services-up --build
```

This rebuilds from the Dockerfile.dev in the hub repo. No changes needed in sertantai-legal.

## Troubleshooting

### Auth not healthy after boot
```bash
# Check container logs
docker compose -f docker-compose.services.yml logs auth

# Restart just auth
docker compose -f docker-compose.services.yml restart auth
```

### Hub frontend shows blank page
```bash
# Check if hub backend is up first (frontend depends on it)
curl http://localhost:4006/health

# Check frontend logs
docker compose -f docker-compose.services.yml logs hub-frontend
```

### Port conflicts
```bash
# Check what's using a port
lsof -ti:4000   # auth
lsof -ti:4006   # hub backend
lsof -ti:5173   # hub frontend

# Stop everything
sert-legal-stop --services --docker
```

### Migrating from source-based startup
If you previously ran `sert-legal-start --auth --hub`, stop those first:
```bash
sert-legal-stop --auth --hub --docker
sert-services-up
```

## Prerequisites

- **Docker** + **docker compose** (Docker Desktop or Docker Engine with compose v2)
- **ptyxis** (Bluefin/Fedora) or **gnome-terminal** (Ubuntu) — auto-detected
- **Elixir/Phoenix** backend in `backend/`
- **SvelteKit** frontend in `frontend/`
- **sertantai-auth** at `~/Desktop/sertantai-auth` (for GHCR image reference)
- **sertantai-hub** at `~/Desktop/sertantai-hub` (for Dockerfile.dev builds)
