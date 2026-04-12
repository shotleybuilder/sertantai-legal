# Development Scripts

Start/stop scripts for sertantai-legal (Phoenix + ElectricSQL + SvelteKit) with optional sertantai-auth dependency management.

## Quick Start

```bash
# Start sertantai-legal only (assumes Docker + auth already running)
sert-legal-start

# Start with Docker containers
sert-legal-start --docker

# Start with Docker + sertantai-auth + sertantai-hub
sert-legal-start --docker --auth --hub

# Stop servers
sert-legal-stop

# Stop everything (servers + Docker + auth + hub)
sert-legal-stop --docker --auth --hub
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sert-legal-start` | Start backend + frontend in terminal tabs |
| `sert-legal-stop` | Stop backend + frontend processes |
| `sert-legal-restart` | Force-stop then restart (with port cleanup) |

## Flags

All three scripts support these flags:

| Flag | Description |
|------|-------------|
| `--docker` | Also manage sertantai-legal Docker containers (postgres + electric) |
| `--auth` | Also manage sertantai-auth service (postgres container + Phoenix server) |
| `--hub` | Also manage sertantai-hub service (postgres container + Phoenix server) |

Additional flags for `sert-legal-restart`:

| Flag | Description |
|------|-------------|
| `--frontend` | Restart frontend only |
| `--backend` | Restart backend only |
| `--force` | Skip graceful shutdown, force-kill immediately |

Flags can be combined: `sert-legal-start --docker --auth --hub`

## Service Architecture

```
sertantai-auth (port 4000)        <-- JWT issuer, optional dependency
    PostgreSQL (port 5438)

sertantai-hub (port 4006)         <-- Orchestrator, mediates auth
    Frontend (port 5173)          <-- SvelteKit (login UI)
    PostgreSQL (port 5435)

sertantai-legal
    Backend  (port 4003)          <-- Phoenix/Ash, validates JWTs
    Frontend (port 5175)          <-- SvelteKit
    Electric (port 3002)          <-- ElectricSQL sync
    PostgreSQL (port 5436)        <-- Docker container
```

## sertantai-auth Integration

sertantai-legal validates JWTs issued by sertantai-auth. For development:

- **Without auth**: Legal service runs normally but cannot validate user tokens. Fine for browsing UK LRT data and UI development.
- **With auth**: Full authentication flow. Use `--auth` flag to auto-start the auth service.

The `--auth` flag:
1. Checks if sertantai-auth is already running (health check on port 4000)
2. If not running, starts its PostgreSQL container (port 5435)
3. Starts auth's Phoenix server in a new terminal tab
4. Waits up to 30s for health check to pass

**Shared secret**: Both services must use the same `SHARED_TOKEN_SECRET` for JWT validation. In development, set this in `backend/.env` matching the value from sertantai-auth's `config/dev.exs`.

### Auth project location

The scripts expect sertantai-auth at `~/Desktop/sertantai-auth`. If your layout differs, update `AUTH_PROJECT_ROOT` in the scripts.

## Symlink Setup

```bash
# From the sertantai-legal project root
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
| sertantai-legal Phoenix | 4003 | sertantai-legal |
| sertantai-legal PostgreSQL | 5436 | sertantai-legal |
| sertantai-legal Electric | 3002 | sertantai-legal |
| sertantai-legal Frontend | 5175 | sertantai-legal |

## sertantai-hub Integration

The hub service is the microservices orchestrator. Authentication is mediated through hub — to sign in with admin credentials, hub must be running.

- **Without hub**: Legal service runs but cannot authenticate users. Fine for UI development with no auth.
- **With hub**: Full authentication flow via sertantai-auth + hub. Use `--hub --auth` flags.

The `--hub` flag:
1. Checks if sertantai-hub is already running (health check on port 4006)
2. If not running, starts its PostgreSQL container (port 5435)
3. Starts hub's Phoenix server in a new terminal tab
4. Waits up to 30s for health check to pass

### Hub project location

The scripts expect sertantai-hub at `~/Desktop/sertantai-hub`. If your layout differs, update `HUB_PROJECT_ROOT` in the scripts.

## Prerequisites

- **gnome-terminal** (Ubuntu) or **ptyxis** (Bluefin/Fedora) — auto-detected
- **Docker** + **docker compose**
- **Elixir/Phoenix** backend in `backend/`
- **SvelteKit** frontend in `frontend/`
- **sertantai-auth** at `~/Desktop/sertantai-auth` (for `--auth` flag)
- **sertantai-hub** at `~/Desktop/sertantai-hub` (for `--hub` flag)

## Troubleshooting

### sertantai-auth won't start
- Check if port 4000 is already in use: `lsof -ti:4000`
- Verify auth project exists: `ls ~/Desktop/sertantai-auth/mix.exs`
- Check auth database: `docker ps | grep sertantai-auth`

### Frontend shows "vite: not found"
```bash
cd frontend && npm install
```

### Ports already in use
```bash
# Check what's using a port
lsof -ti:4003
lsof -ti:5175

# Force stop everything
sert-legal-stop --docker --auth
```

### Docker services not starting
Manually start Docker services:
```bash
docker compose -f docker-compose.dev.yml up -d postgres
docker compose -f docker-compose.dev.yml up -d --no-deps electric
```
