---
name: Docker Dev Services Restart
description: Safe procedures for restarting Docker development services (PostgreSQL, ElectricSQL) after shutdown or reboot. Prevents accidental database data loss.
---

# Docker Dev Services Restart

## After System Reboot

Run these commands in order from the project root:

```bash
cd /home/jason/Desktop/sertantai-legal
docker compose -f docker-compose.dev.yml up -d postgres
sleep 5
docker compose -f docker-compose.dev.yml up -d --no-deps electric
```

Then start the app servers:

```bash
sert-legal-start
# Or with Docker (if not already started above):
sert-legal-start --docker
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
# After reboot, follow "After System Reboot" above
```

## Restart Electric with Config Changes

When `docker-compose.dev.yml` Electric config has changed (new env vars, etc.):

```bash
docker compose -f docker-compose.dev.yml up -d --no-deps electric
```

The `--no-deps` flag is **critical** -- without it, Docker may recreate the postgres container too, which can cause data loss.

## Verify Services Are Running

```bash
# Check containers
docker ps --format "table {{.Names}}\t{{.Status}}" | grep legal

# Check ElectricSQL health
curl -s http://localhost:3002/v1/health

# Check shape API
curl -s "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1" | head -c 200

# Check shape deletion is enabled
curl -s -X DELETE "http://localhost:3002/v1/shape?table=uk_lrt"
# Should return 202 (accepted), not 405 (not allowed)
```

## NEVER DO

| Command | Risk |
|---------|------|
| `docker compose down -v` | **Destroys database volumes -- all 19k UK LRT records lost** |
| `docker compose up -d electric` (without `--no-deps`) | May recreate postgres container |
| `aa-remove-unknown` | **Removes AppArmor profiles for Firefox, VS Code, and all snap apps** |

## Data Recovery

If database data is accidentally lost:

```bash
cd /home/jason/Desktop/sertantai-legal/backend
unset DATABASE_URL
mix ash_postgres.migrate

# Restore all tables from NAS snapshot (preferred)
cd /home/jason/Desktop/sertantai-legal
./scripts/nas/import-snapshot.sh
```

If the NAS is unavailable, see the legacy fallback in CLAUDE.md under "Legacy Data Import".
