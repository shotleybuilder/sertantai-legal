#!/bin/bash
#
# deploy-prod.sh - Deploy Sertantai Legal to production server
#
# This script deploys to production:
#   - Frontend: Docker container (pull + restart)
#   - Backend: Phoenix Docker container (pull + restart)
#   - Electric: ElectricSQL sync service (safe restart)
#
# Usage:
#   sert-legal-deploy [options]
#   ./scripts/deployment/deploy-prod.sh [options]
#
# Options:
#   --all              Deploy both frontend and backend (default)
#   --frontend         Deploy frontend only
#   --backend          Deploy backend only
#   --electric         Restart ElectricSQL only (safe restart)
#   --with-electric    Also restart ElectricSQL when deploying backend
#   --electric-clear-cache  Restart Electric and clear shape cache
#   --migrate          Run database migrations
#   --check-only       Only check status, don't deploy
#   --logs             Follow logs after deployment
#   --help             Show this help message
#
# ElectricSQL Notes:
#   - Uses 'docker restart' for safe restarts (preserves database)
#   - NEVER uses 'docker compose up electric' without --no-deps (can wipe database!)
#   - Clear cache when schema changes or shapes are stale
#   - Electric container: sertantai_legal_electric
#
# Prerequisites:
#   - SSH access to sertantai-hz server configured
#   - Backend: Image pushed to GHCR (sert-legal-push-be)
#   - Frontend: Image pushed to GHCR (sert-legal-push-fe)
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER="sertantai-hz"
DEPLOY_PATH="~/infrastructure/docker"
BACKEND_SERVICE="sertantai-legal"
FRONTEND_SERVICE="sertantai-legal-frontend"
ELECTRIC_CONTAINER="sertantai_legal_electric"
ELECTRIC_COMPOSE_SERVICE="sertantai-legal-electric"
SITE_URL="https://legal.sertantai.com"
ELECTRIC_URL="${SITE_URL}/electric"
BACKEND_PORT=4000
ELECTRIC_INTERNAL_PORT=3000

# Hub dependency (legal depends on hub for auth/shared services)
HUB_CONTAINER="sertantai_hub_app"
HUB_COMPOSE_SERVICE="sertantai-hub"
HUB_HEALTH_URL="http://localhost:4006/health"

# Parse command line options
DEPLOY_FRONTEND=true
DEPLOY_BACKEND=true
DEPLOY_ELECTRIC=false
WITH_ELECTRIC=false
ELECTRIC_CLEAR_CACHE=false
RUN_MIGRATIONS=false
CHECK_ONLY=false
FOLLOW_LOGS=false
CHECK_HUB=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            DEPLOY_FRONTEND=true
            DEPLOY_BACKEND=true
            shift
            ;;
        --frontend)
            DEPLOY_FRONTEND=true
            DEPLOY_BACKEND=false
            shift
            ;;
        --backend)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=true
            shift
            ;;
        --electric)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=false
            DEPLOY_ELECTRIC=true
            shift
            ;;
        --with-electric)
            WITH_ELECTRIC=true
            shift
            ;;
        --electric-clear-cache)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=false
            DEPLOY_ELECTRIC=true
            ELECTRIC_CLEAR_CACHE=true
            shift
            ;;
        --migrate)
            RUN_MIGRATIONS=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --logs)
            FOLLOW_LOGS=true
            shift
            ;;
        --check-hub)
            CHECK_HUB=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --all              Deploy both frontend and backend (default)"
            echo "  --frontend         Deploy frontend only"
            echo "  --backend          Deploy backend only"
            echo "  --electric         Restart ElectricSQL only (safe restart)"
            echo "  --with-electric    Also restart ElectricSQL when deploying backend"
            echo "  --electric-clear-cache  Restart Electric and clear shape cache"
            echo "  --migrate          Run database migrations"
            echo "  --check-only       Only check status, don't deploy"
            echo "  --logs             Follow logs after deployment"
            echo "  --check-hub        Check hub service health before deploying"
            echo "  --help             Show this help message"
            echo ""
            echo "Hub Dependency:"
            echo "  sertantai-legal depends on sertantai-hub for auth and shared services."
            echo "  Use --check-hub to verify hub is healthy before deploying."
            echo ""
            echo "Production Details:"
            echo "  Server:        ${SERVER}"
            echo "  Infrastructure: ${DEPLOY_PATH}"
            echo "  Backend:       ${BACKEND_SERVICE}"
            echo "  Frontend:      ${FRONTEND_SERVICE}"
            echo "  Electric:      ${ELECTRIC_CONTAINER}"
            echo "  URL:           ${SITE_URL}"
            echo ""
            echo "Aliases:"
            echo "  sert-legal-deploy       This script"
            echo "  sert-legal-fe           Build frontend image"
            echo "  sert-legal-be           Build backend image"
            echo "  sert-legal-push-fe      Push frontend to GHCR"
            echo "  sert-legal-push-be      Push backend to GHCR"
            echo ""
            echo "ElectricSQL Notes:"
            echo "  - Uses 'docker restart' for safe restarts (preserves database)"
            echo "  - Use --electric-clear-cache after schema changes"
            echo "  - Check status: curl ${ELECTRIC_URL}/v1/health"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Navigate to project root
cd "$(dirname "$0")/../.."

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sertantai Legal - Production Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Server:${NC} ${SERVER}"
echo -e "${YELLOW}URL:${NC} ${SITE_URL}"

# Show what will be deployed
if [ "$DEPLOY_ELECTRIC" = true ]; then
    if [ "$ELECTRIC_CLEAR_CACHE" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} ElectricSQL (with cache clear)"
    else
        echo -e "${YELLOW}Deploying:${NC} ElectricSQL only"
    fi
elif [ "$DEPLOY_FRONTEND" = true ] && [ "$DEPLOY_BACKEND" = true ]; then
    if [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} Full stack (frontend + backend + electric)"
    else
        echo -e "${YELLOW}Deploying:${NC} Full stack (frontend + backend)"
    fi
elif [ "$DEPLOY_FRONTEND" = true ]; then
    echo -e "${YELLOW}Deploying:${NC} Frontend only"
elif [ "$DEPLOY_BACKEND" = true ]; then
    if [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} Backend + ElectricSQL"
    else
        echo -e "${YELLOW}Deploying:${NC} Backend only"
    fi
fi
echo ""

# Check SSH connectivity
echo -e "${BLUE}Checking SSH connection to ${SERVER}...${NC}"
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER}" "echo 'SSH OK'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to ${SERVER}${NC}"
    echo -e "${YELLOW}  Check your SSH configuration and try again${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection OK${NC}"
echo ""

# ============================================================
# HUB DEPENDENCY FUNCTIONS
# ============================================================
check_hub_health() {
    local HUB_STATUS
    HUB_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' ${HUB_CONTAINER}" 2>/dev/null || echo "not_found")
    if [ "$HUB_STATUS" = "healthy" ]; then
        echo -e "${GREEN}✓ Hub service is healthy${NC}"
        return 0
    elif [ "$HUB_STATUS" = "not_found" ]; then
        echo -e "${RED}✗ Hub container not found (${HUB_CONTAINER})${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ Hub health status: ${HUB_STATUS}${NC}"
        return 1
    fi
}

# ============================================================
# CHECK-ONLY MODE
# ============================================================
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BLUE}Checking production status...${NC}"
    echo ""

    echo -e "${BLUE}Backend Status:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose ps ${BACKEND_SERVICE}" 2>/dev/null || echo "  Backend not running"
    echo ""

    echo -e "${BLUE}Frontend Status:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose ps ${FRONTEND_SERVICE}" 2>/dev/null || echo "  Frontend not running"
    echo ""

    echo -e "${BLUE}ElectricSQL Status:${NC}"
    ssh "${SERVER}" "docker ps --filter name=${ELECTRIC_CONTAINER} --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" || echo "  Electric not running"

    # Check Electric health (no host port mapping — must exec into container)
    if ssh "${SERVER}" "docker exec ${ELECTRIC_CONTAINER} curl -sf http://localhost:3000/v1/health" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Electric health check passed"
    else
        echo -e "  ${YELLOW}⚠${NC} Electric health check failed"
    fi
    echo ""

    echo -e "${BLUE}Hub Dependency:${NC}"
    check_hub_health || true
    echo ""

    echo -e "${BLUE}Recent Backend Logs:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=15 ${BACKEND_SERVICE}" 2>/dev/null || echo "  No logs available"

    echo ""
    echo -e "${GREEN}Status check complete${NC}"
    exit 0
fi

# Track deployment success
FRONTEND_SUCCESS=true
BACKEND_SUCCESS=true
ELECTRIC_SUCCESS=true

# ============================================================
# HUB DEPENDENCY CHECK (before deploy)
# ============================================================
if [ "$CHECK_HUB" = true ]; then
    echo -e "${BLUE}Checking hub dependency...${NC}"
    if ! check_hub_health; then
        echo -e "${RED}✗ Hub is not healthy — legal deployment may have issues${NC}"
        echo -e "${YELLOW}  Deploy hub first: cd ~/Desktop/sertantai-hub && ./scripts/deployment/deploy-prod.sh --backend${NC}"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Deployment cancelled${NC}"
            exit 0
        fi
    fi
    echo ""
fi

# ============================================================
# DEPLOY FRONTEND (Docker container - pull and restart)
# ============================================================
if [ "$DEPLOY_FRONTEND" = true ]; then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying Frontend (container)                         │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Pull latest image
    echo -e "${BLUE}[1/3] Pulling latest frontend image from GHCR...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose pull ${FRONTEND_SERVICE}"; then
        echo -e "${GREEN}✓ Frontend image pulled${NC}"
    else
        echo -e "${RED}✗ Failed to pull frontend image${NC}"
        FRONTEND_SUCCESS=false
    fi
    echo ""

    if [ "$FRONTEND_SUCCESS" = true ]; then
        # Restart container
        echo -e "${BLUE}[2/3] Restarting frontend container...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${FRONTEND_SERVICE}"; then
            echo -e "${GREEN}✓ Frontend container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart frontend container${NC}"
            FRONTEND_SUCCESS=false
        fi
        echo ""
    fi

    if [ "$FRONTEND_SUCCESS" = true ]; then
        # Health check (no host port mapping — use Docker's built-in health status)
        echo -e "${BLUE}[3/3] Checking frontend health...${NC}"
        sleep 3
        FRONTEND_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' sertantai_legal_frontend" 2>/dev/null || echo "unknown")
        if [ "$FRONTEND_STATUS" = "healthy" ]; then
            echo -e "${GREEN}✓ Frontend container is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Frontend health status: ${FRONTEND_STATUS} (may still be starting)${NC}"
        fi
        echo ""
    fi

    # Reload nginx to pick up any config changes
    echo -e "${BLUE}Reloading nginx...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T nginx nginx -s reload" 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx reloaded${NC}"
    else
        echo -e "${YELLOW}⚠ Could not reload nginx (may need manual reload)${NC}"
    fi
    echo ""
fi

# ============================================================
# DEPLOY BACKEND
# ============================================================
if [ "$DEPLOY_BACKEND" = true ]; then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying Backend                                      │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Pull latest image
    echo -e "${BLUE}[1/4] Pulling latest backend image from GHCR...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose pull ${BACKEND_SERVICE}"; then
        echo -e "${GREEN}✓ Image pulled successfully${NC}"
    else
        echo -e "${RED}✗ Failed to pull image${NC}"
        BACKEND_SUCCESS=false
    fi
    echo ""

    if [ "$BACKEND_SUCCESS" = true ]; then
        # Restart container (picks up new image)
        echo -e "${BLUE}[2/3] Restarting container...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${BACKEND_SERVICE}"; then
            echo -e "${GREEN}✓ Container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart container${NC}"
            BACKEND_SUCCESS=false
        fi
        echo ""
    fi

    # Run migrations if requested (after container restart so new code is running)
    if [ "$BACKEND_SUCCESS" = true ] && [ "$RUN_MIGRATIONS" = true ]; then
        echo -e "${BLUE}[2b] Running migrations...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T ${BACKEND_SERVICE} /app/bin/sertantai_legal eval 'SertantaiLegal.Release.migrate'"; then
            echo -e "${GREEN}✓ Migrations complete${NC}"
        else
            echo -e "${RED}✗ Migration failed${NC}"
            BACKEND_SUCCESS=false
        fi
        echo ""
    fi

    if [ "$BACKEND_SUCCESS" = true ]; then
        # Wait and check health via Docker health status (no host port mapping)
        echo -e "${BLUE}[3/3] Waiting for backend to become healthy...${NC}"
        BACKEND_HEALTHY=false
        for i in 1 2 3 4 5 6; do
            sleep 5
            BACKEND_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' sertantai_legal_app" 2>/dev/null || echo "unknown")
            if [ "$BACKEND_STATUS" = "healthy" ]; then
                BACKEND_HEALTHY=true
                break
            fi
            echo -e "${YELLOW}  Attempt ${i}/6: status=${BACKEND_STATUS} — retrying in 5s...${NC}"
        done

        if [ "$BACKEND_HEALTHY" = true ]; then
            echo -e "${GREEN}✓ Backend is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Backend health status: ${BACKEND_STATUS} after 30s${NC}"
            echo -e "${YELLOW}  Check logs: ssh ${SERVER} 'cd ${DEPLOY_PATH} && docker compose logs --tail=20 ${BACKEND_SERVICE}'${NC}"
        fi
        echo ""
    fi
fi

# ============================================================
# DEPLOY ELECTRICSQL
# ============================================================
if [ "$DEPLOY_ELECTRIC" = true ] || ([ "$WITH_ELECTRIC" = true ] && [ "$DEPLOY_BACKEND" = true ]); then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying ElectricSQL                                  │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # CRITICAL: Use docker restart, NOT docker-compose up without --no-deps
    # docker-compose up can recreate dependent containers and WIPE the database!

    if [ "$ELECTRIC_CLEAR_CACHE" = true ]; then
        echo -e "${BLUE}[1/3] Stopping Electric container...${NC}"
        if ssh "${SERVER}" "docker stop ${ELECTRIC_CONTAINER}" 2>/dev/null; then
            echo -e "${GREEN}✓ Container stopped${NC}"
        else
            echo -e "${YELLOW}⚠ Container was not running${NC}"
        fi
        echo ""

        echo -e "${BLUE}[2/3] Removing container and clearing cache...${NC}"
        ssh "${SERVER}" "docker rm ${ELECTRIC_CONTAINER}" 2>/dev/null || true
        echo -e "${GREEN}✓ Container removed (cache will be cleared on restart)${NC}"
        echo ""

        echo -e "${BLUE}[3/3] Recreating Electric container (safe - no deps)...${NC}"
        # Use --no-deps to prevent recreating PostgreSQL!
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${ELECTRIC_COMPOSE_SERVICE} --no-deps"; then
            echo -e "${GREEN}✓ Electric container recreated${NC}"
        else
            echo -e "${RED}✗ Failed to recreate Electric container${NC}"
            ELECTRIC_SUCCESS=false
        fi
    else
        echo -e "${BLUE}[1/1] Restarting Electric container (safe restart)...${NC}"
        if ssh "${SERVER}" "docker restart ${ELECTRIC_CONTAINER}"; then
            echo -e "${GREEN}✓ Electric container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart Electric container${NC}"
            echo -e "${YELLOW}  Container may not exist. Try --electric-clear-cache to recreate.${NC}"
            ELECTRIC_SUCCESS=false
        fi
    fi
    echo ""

    # Wait and check Electric health
    if [ "$ELECTRIC_SUCCESS" = true ]; then
        echo -e "${BLUE}Waiting for Electric startup...${NC}"
        sleep 3

        echo -e "${BLUE}Checking Electric health...${NC}"
        ELECTRIC_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' ${ELECTRIC_CONTAINER}" 2>/dev/null || echo "unknown")
        if [ "$ELECTRIC_STATUS" = "healthy" ]; then
            echo -e "${GREEN}✓ Electric is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Electric health status: ${ELECTRIC_STATUS}${NC}"
            echo -e "${YELLOW}  Electric may still be starting up${NC}"
        fi
        echo ""

        echo -e "${BLUE}Electric container status:${NC}"
        ssh "${SERVER}" "docker ps --filter name=${ELECTRIC_CONTAINER} --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
        echo ""
    fi
fi

# ============================================================
# SUMMARY
# ============================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$FRONTEND_SUCCESS" = true ] && [ "$BACKEND_SUCCESS" = true ] && [ "$ELECTRIC_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Deployment complete!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Application:${NC} ${SITE_URL}"
    echo -e "${YELLOW}API:${NC} ${SITE_URL}/api"
    echo -e "${YELLOW}Health:${NC} ${SITE_URL}/health"
    if [ "$DEPLOY_ELECTRIC" = true ] || [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Electric:${NC} ${ELECTRIC_URL}/v1/health"
    fi
    echo ""

    if [ "$DEPLOY_BACKEND" = true ]; then
        echo -e "${BLUE}Recent backend logs:${NC}"
        ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=10 ${BACKEND_SERVICE}"
        echo ""
    fi

    if [ "$FOLLOW_LOGS" = true ] && [ "$DEPLOY_BACKEND" = true ]; then
        echo -e "${BLUE}Following logs (Ctrl+C to exit)...${NC}"
        echo ""
        ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs -f ${BACKEND_SERVICE}"
    else
        echo -e "${BLUE}To follow logs:${NC}"
        echo -e "  ${YELLOW}ssh ${SERVER} 'cd ${DEPLOY_PATH} && docker compose logs -f ${BACKEND_SERVICE}'${NC}"
        echo ""
    fi
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ "$DEPLOY_FRONTEND" = true ] && [ "$FRONTEND_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ Frontend deployment failed${NC}"
    fi
    if [ "$DEPLOY_BACKEND" = true ] && [ "$BACKEND_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ Backend deployment failed${NC}"
    fi
    if ([ "$DEPLOY_ELECTRIC" = true ] || [ "$WITH_ELECTRIC" = true ]) && [ "$ELECTRIC_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ ElectricSQL deployment failed${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Check the output above for error details${NC}"
    exit 1
fi
