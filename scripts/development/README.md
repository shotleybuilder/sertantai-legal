# Development Scripts

Start/stop scripts for sertantai-legal development.

## Quick Start

```bash
# One-time: bootstrap shared containers (auth, hub, electric)
sert-up

# Daily: start legal dev servers (2 tabs — backend + frontend)
sert-dev

# Stop legal servers
sert-stop
```

## Architecture

```
Always-on containers (auto-restart on boot, managed by sert-up):
  sertantai-auth          port 4000  (GHCR image)
  sertantai-auth-postgres port 5438
  sertantai-hub-backend   port 4006  (GHCR image)
  sertantai-hub-frontend  port 5173  (GHCR image)
  sertantai-hub-postgres  port 5435
  sertantai-hub-electric  port 3000
  sertantai-legal-electric port 3002 (shared by legal + compliance)

Legal postgres (auto-started by sert-dev):
  sertantai-legal-postgres port 5436

Legal dev servers (terminal tabs, managed by sert-dev / sert-stop):
  Phoenix backend          port 4003
  SvelteKit frontend       port 5175
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sert-up` | Start/stop shared service containers |
| `sert-dev` | Start legal backend + frontend in terminal tabs |
| `sert-stop` | Stop legal backend + frontend |

### sert-up

Manages the always-on container stack (`docker-compose.services.yml`).

```bash
sert-up              # Start or verify containers are running
sert-up --pull       # Pull latest GHCR images + restart
sert-up --status     # Show container status
sert-up --stop       # Stop containers (won't auto-restart until re-run)
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
docker compose -f docker-compose.services.yml logs auth
docker compose -f docker-compose.services.yml logs hub-backend
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
