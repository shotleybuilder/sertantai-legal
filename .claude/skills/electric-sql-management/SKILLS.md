---
name: ElectricSQL Safe Management
description: Safe procedures for restarting, troubleshooting, and managing ElectricSQL sync service without wiping the PostgreSQL database. Includes critical warnings about Docker Compose dependency chains and proper restart commands.
---

# ElectricSQL Safe Management

## Overview

ElectricSQL provides real-time PostgreSQL sync via HTTP Shape API. This guide covers safe restart procedures and troubleshooting to **prevent accidental database wipes**.

## Development vs Production Environments

The project uses different Docker Compose files for dev and production:

**Development** (`docker-compose.dev.yml`):
```bash
# Container names: sertantai-legal-postgres, sertantai-legal-electric
docker-compose -f docker-compose.dev.yml up -d postgres electric
```

**Production** (infrastructure repo):
```bash
# Container names: sertantai_legal, sertantai_legal_electric
# Managed via ~/Desktop/infrastructure
```

## Critical Warning: Never Use docker-compose to Restart Electric

⚠️ **DANGER**: Using `docker-compose up -d electric` will recreate both Electric AND PostgreSQL containers due to dependency chain, **wiping all database data**.

### Wrong (Data Loss):
```bash
# ❌ NEVER DO THIS - Wipes database!
docker-compose -f docker-compose.dev.yml up -d electric
```

### Correct (Safe):
```bash
# ✅ Safe restart - preserves database
docker restart sertantai-legal-electric
```

## Safe Restart Procedures

### 1. Restart Electric Only (Most Common)

When Electric is unhealthy, not responding, or has stale shape cache:

```bash
# Stop Electric container
docker stop sertantai-legal-electric

# Remove container (preserves Postgres)
docker rm sertantai-legal-electric

# Recreate Electric container ONLY
docker-compose -f docker-compose.dev.yml up -d electric --no-deps

# Verify it's running
docker ps | grep electric
```

The `--no-deps` flag prevents recreating dependent services (Postgres).

### 2. Quick Restart (No Cache Clear)

For simple restarts without removing cached shapes:

```bash
docker restart sertantai-legal-electric
```

### 3. Full Reset with Cache Clear

When shape cache is corrupted or needs clearing:

```bash
# Stop and remove Electric container
docker stop sertantai-legal-electric
docker rm sertantai-legal-electric

# Remove Electric volume (clears shape cache)
docker volume rm sertantai-legal_electric_data 2>/dev/null || true

# Recreate Electric without touching Postgres
docker-compose -f docker-compose.dev.yml up -d electric --no-deps
```

## Verification Steps

### Check Electric is Running

```bash
# Container status
docker ps | grep electric

# Should show:
# sertantai-legal-electric   electricsql/electric:latest   Up X minutes (healthy)   3002->3000/tcp
```

### Test Shape API Endpoint

```bash
# Test uk_lrt table shape
curl "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1"

# Should return JSON with shape data
# Bad response: "Not found" or connection refused means Electric isn't working
```

### Check Logs

```bash
# View Electric logs
docker logs sertantai-legal-electric --tail=50

# Look for:
# ✅ "Electric is running on http://0.0.0.0:3000"
# ❌ "Database connection failed" or panic errors
```

## Exposing Tables to Electric

Electric only syncs tables with REPLICA IDENTITY FULL set.

### Check Table REPLICA IDENTITY

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c \
  "SELECT relname, relreplident FROM pg_class WHERE relname = 'uk_lrt';"

# relreplident values: 'd' = default, 'f' = full (required for Electric)
```

### Enable REPLICA IDENTITY FULL

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c \
  "ALTER TABLE uk_lrt REPLICA IDENTITY FULL;"

# Restart Electric to pick up changes
docker restart sertantai-legal-electric
```

### Verify Table is Exposed

```bash
# Test API endpoint (should return data or empty snapshot, not "Not found")
curl "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1"
```

## Common Issues and Fixes

### Issue: "Table does not exist" Error

**Cause**: Database schema is missing (migrations not run).

**Fix**:
```bash
# Run migrations
cd /home/jason/Desktop/sertantai-legal/backend
mix ash_postgres.migrate
```

### Issue: "Not found" on Shape Endpoint

**Cause 1**: Table doesn't have REPLICA IDENTITY FULL set.

**Cause 2**: Incorrect port mapping in docker-compose.yml.

**Check**: Electric runs on port 3000 inside container, mapped to 3002 on host.

**Correct Configuration**:
```yaml
electric:
  ports:
    - "3002:3000"  # ✅ Correct: host:container
```

**Fix for Cause 1**:
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c \
  "ALTER TABLE uk_lrt REPLICA IDENTITY FULL;"
docker restart sertantai-legal-electric
```

**Correct API Format**:
```bash
# ✅ Correct - uses query parameters
curl "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1"

# With WHERE clause
curl "http://localhost:3002/v1/shape?table=uk_lrt&where=year%3E%3D2024&offset=-1"
```

### Issue: Electric Container Unhealthy

**Symptoms**: `docker ps` shows "(unhealthy)" status.

**Diagnosis**:
```bash
# Check health check logs
docker inspect sertantai-legal-electric | grep -A 10 Health

# Check Electric logs
docker logs sertantai-legal-electric --tail=100
```

**Fix**:
```bash
# Restart Electric
docker restart sertantai-legal-electric

# If still unhealthy, check database connection:
docker exec -it sertantai-legal-postgres psql -U postgres -d sertantai_legal_dev -c "SELECT 1;"
```

### Issue: Browser Shows "Offline" or "No Data"

**Cause**: ElectricSQL sync not working or shape cache stale.

**Fix**:
```bash
# 1. Verify Electric is accessible
curl "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1"

# 2. If working, refresh browser (Ctrl+Shift+R)

# 3. If still offline, restart Electric with cache clear:
docker stop sertantai-legal-electric
docker rm sertantai-legal-electric
docker-compose -f docker-compose.dev.yml up -d electric --no-deps
```

## Complete Stack Restart (Safe)

When you need to restart everything (e.g., config changes):

```bash
# Safe restart preserving volumes:
docker-compose -f docker-compose.dev.yml stop     # Stops all, preserves volumes
docker-compose -f docker-compose.dev.yml up -d    # Recreates all containers safely
```

**Why Safe**: `stop` + `up -d` preserves named volumes (database data persists).

**Unsafe**: `docker-compose down -v` (removes volumes, wipes data).

## Port Configuration Reference

### Current Setup (sertantai-legal):
- **PostgreSQL**: Host 5436 → Container 5432
- **ElectricSQL**: Host 3002 → Container 3000
- **Phoenix**: Host 4003 (no Docker in dev)
- **Frontend**: Host 5175 (no Docker in dev)

### Environment Variables:
```yaml
electric:
  environment:
    DATABASE_URL: postgresql://postgres:postgres@postgres:5432/sertantai_legal_dev
    ELECTRIC_INSECURE: "true"  # Dev only!
```

## Database Recovery (If Accidentally Wiped)

If database was wiped, recover with these steps:

```bash
# 1. Run all migrations
cd /home/jason/Desktop/sertantai-legal/backend
mix ash_postgres.migrate

# 2. Re-import UK LRT data
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -f /home/jason/Documents/sertantai-data/import_uk_lrt.sql

# 3. Verify import
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT COUNT(*) FROM uk_lrt;"
# Should show: 19089
```

## Quick Reference Card

| Task | Safe Command |
|------|--------------|
| Restart Electric | `docker restart sertantai-legal-electric` |
| Electric + cache clear | `docker stop sertantai-legal-electric && docker rm sertantai-legal-electric && docker-compose -f docker-compose.dev.yml up -d electric --no-deps` |
| Check Electric status | `docker ps \| grep electric` |
| Test shape API | `curl "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1"` |
| Test with WHERE | `curl "http://localhost:3002/v1/shape?table=uk_lrt&where=year%3E%3D2024&offset=-1"` |
| View logs | `docker logs sertantai-legal-electric --tail=50` |
| Check REPLICA IDENTITY | `psql -c "SELECT relreplident FROM pg_class WHERE relname = 'uk_lrt';"` |
| Enable REPLICA IDENTITY | `psql -c "ALTER TABLE uk_lrt REPLICA IDENTITY FULL;"` |
| Full stack restart | `docker-compose -f docker-compose.dev.yml stop && docker-compose -f docker-compose.dev.yml up -d` |
| **NEVER DO** | `docker-compose -f docker-compose.dev.yml up -d electric` (may wipe database!) |

## Related Documentation

- ElectricSQL HTTP API: https://electric-sql.com/docs/api/http
- Docker Compose docs: https://docs.docker.com/compose/
- Project docker-compose.dev.yml: `/home/jason/Desktop/sertantai-legal/docker-compose.dev.yml`
- CLAUDE.md: Project documentation with Electric setup notes
