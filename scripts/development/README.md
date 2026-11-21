# Development Scripts

Start/stop scripts for sertantai-legal development.

## Quick Start

```bash
# One-time: start legal's Electric container (auth and the hub: sertantai-stack)
sert-up

# Daily: start legal dev servers (2 tabs — backend + frontend)
sert-dev

# Stop legal servers
sert-stop
```

## Architecture

```
Always-on, managed by sert-up (auto-restart on boot):
  sertantai-legal-electric port 3002 (shared by legal + compliance)

Always-on, managed in sertantai-stack (docker/docker-compose.dev.yml,
project sertantai-dev; moved there 2026-11-21, Jason):
  sertantai-auth          port 4000  (GHCR image)
  sertantai-auth-postgres port 5438
  sertantai-hub-backend   port 4006  (GHCR image)
  sertantai-hub-frontend  port 5173  (GHCR image)
  sertantai-hub-postgres  port 5435
  sertantai-hub-electric  port 3000

Legal postgres (auto-started by sert-dev):
  sertantai-legal-postgres port 5436

Legal dev servers (terminal tabs, managed by sert-dev / sert-stop):
  Phoenix backend          port 4003
  SvelteKit frontend       port 5175
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sert-up` | Start/stop legal's Electric container |
| `sert-dev` | Start legal backend + frontend in terminal tabs |
| `sert-stop` | Stop legal backend + frontend |

### sert-up

Manages legal-electric (`docker-compose.services.yml`), alone: it never starts or stops another service. Auth and the hub are managed from sertantai-stack:

```bash
sert-up              # Start or verify legal-electric is running
sert-up --pull       # Pull the latest Electric image + restart
sert-up --status     # Show its status (and where auth and the hub are managed)
sert-up --stop       # Stop it (won't auto-restart until re-run)

# auth and the hub, from ~/Desktop/sertantai-stack:
docker compose -p sertantai-dev -f docker/docker-compose.dev.yml --env-file docker/.env.dev ps
```

### sert-dev

Opens terminal tabs for Phoenix backend and SvelteKit frontend.
Auto-starts legal postgres if not running. Reports shared service status.

```bash
sert-dev              # Start backend + frontend
sert-dev --zenoh      # Enable Zenoh P2P mesh
```

### sert-stop

```bash
sert-stop             # Stop legal servers only (postgres stays running)
sert-stop --docker    # Also stop legal postgres container
```

To restart: `sert-stop && sert-dev`

## Symlink Setup

```bash
cd ~/Desktop/sertantai-legal
sudo ln -sf $(pwd)/scripts/development/sert-up /usr/local/bin/sert-up
sudo ln -sf $(pwd)/scripts/development/sert-dev /usr/local/bin/sert-dev
sudo ln -sf $(pwd)/scripts/development/sert-stop /usr/local/bin/sert-stop
```

## Port Allocation

| Service | Port | Project |
|---------|------|---------|
| Auth Phoenix | 4000 | sertantai-auth |
| Auth PostgreSQL | 5438 | sertantai-auth |
| Hub Phoenix | 4006 | sertantai-hub |
| Hub Frontend | 5173 | sertantai-hub |
| Hub PostgreSQL | 5435 | sertantai-hub |
| Hub Electric | 3000 | sertantai-hub |
| Legal Phoenix | 4003 | sertantai-legal |
| Legal PostgreSQL | 5436 | sertantai-legal |
| Legal Electric | 3002 | sertantai-legal (shared) |
| Legal Frontend | 5175 | sertantai-legal |

## Troubleshooting

### Service not healthy after boot
```bash
sert-up --status
# auth and hub logs: from sertantai-stack (project sertantai-dev)
docker compose -f docker-compose.services.yml logs legal-electric
```

### Port conflicts
```bash
lsof -ti:4003   # legal backend
lsof -ti:5175   # legal frontend
```

### Electric health check
```bash
curl http://localhost:3002/v1/health
```
