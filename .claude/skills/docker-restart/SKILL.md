---
name: Docker Dev Services Restart
description: Safe procedures for restarting Docker development services (PostgreSQL, ElectricSQL) after shutdown or reboot. Prevents accidental database data loss.
---

# Docker Dev Services Restart

## After System Reboot

Shared services (auth, hub, electric) auto-restart on boot via `restart: unless-stopped`.
If they didn't come up, run:

```bash
sert-up
```

Legal postgres also auto-restarts. If it didn't:

```bash
cd ~/Desktop/sertantai-legal
docker compose -f docker-compose.dev.yml up -d postgres
```

Then start the app servers:

```bash
sert-dev
```

## Restart Electric Only

When Electric is misbehaving but postgres is fine:

```bash
docker restart sertantai-legal-electric
```

If `docker restart` fails with "permission denied":

```bash
# Reboot is the safest fix for stuck containers
sudo reboot
# After reboot, services auto-restart
```

## Verify Services Are Running

```bash
# Check all service containers
sert-up --status

# Check legal containers
docker ps --format "table {{.Names}}\t{{.Status}}" | grep legal

# Check ElectricSQL health
curl -s http://localhost:3002/v1/health

# Check shape API
curl -s "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1" | head -c 200
```

## NEVER DO

| Command | Risk |
|---------|------|
| `docker compose down -v` | **Destroys database volumes -- all 19k UK LRT records lost** |
| `docker compose up -d electric` (without `--no-deps`) | May recreate postgres container |

## Data Recovery

If database data is accidentally lost:

```bash
cd ~/Desktop/sertantai-legal/backend
unset DATABASE_URL
mix ash_postgres.migrate

# Restore all tables from NAS snapshot
cd ~/Desktop/sertantai-legal
./scripts/nas/import-snapshot.sh
```
