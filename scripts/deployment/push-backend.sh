#!/bin/bash
#
# push-backend.sh - Push sertantai-legal Backend Docker image to GitHub Container Registry
#
# This script pushes the built backend Docker image to GHCR. You must be logged in
# to GHCR before running this script.
#
# Usage:
#   sert-legal-push-be [tag]
#   ./scripts/deployment/push-backend.sh [tag]
#
# Arguments:
#   tag - Optional image tag (default: latest)
#
# Prerequisites:
#   - Docker image built: sert-legal-be
#   - Logged in to GHCR: echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin
#
# Next steps after successful push:
#   - Deploy to production server via infrastructure
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Image configuration (update with your GitHub org/user)
IMAGE_NAME="ghcr.io/shotleybuilder/sertantai-legal-backend"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sertantai Legal Backend - Push to GHCR${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
echo ""

# Check if image exists locally
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${FULL_IMAGE}$"; then
    echo -e "${RED}✗ Error: Image not found locally${NC}"
    echo -e "${YELLOW}  Build it first: ./scripts/deployment/build-backend.sh${NC}"
    exit 1
fi

# Ensure logged in to GHCR
echo -e "${BLUE}Checking GHCR authentication...${NC}"
if [ -n "$GHCR_TOKEN" ]; then
    GHCR_USER="${GHCR_USER:-shotleybuilder}"
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Logged in to GHCR as ${GHCR_USER}${NC}"
    else
        echo -e "${RED}✗ GHCR login failed (check GHCR_TOKEN)${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ GHCR_TOKEN not set — assuming already logged in${NC}"
    echo -e "${YELLOW}  Set GHCR_TOKEN in ~/.bashrc for automatic login${NC}"
    echo -e "${YELLOW}  Or login manually: echo \$TOKEN | docker login ghcr.io -u USERNAME --password-stdin${NC}"
    echo ""
fi

# Push the image
echo ""
echo -e "${BLUE}Pushing to GitHub Container Registry...${NC}"
echo ""

docker push "${FULL_IMAGE}"

# Check push success
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Backend push successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
    echo -e "${YELLOW}Registry:${NC} GitHub Container Registry (GHCR)"
    echo ""

    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  ${GREEN}→${NC} Push frontend: ${YELLOW}sert-legal-push-fe${NC}"
    echo -e "  ${GREEN}→${NC} Deploy to production via your infrastructure setup"
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Push failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  • Not logged in to GHCR"
    echo -e "  • Insufficient permissions"
    echo -e "  • Network connectivity issues"
    echo ""
    echo -e "${YELLOW}Login command:${NC}"
    echo -e "  ${BLUE}echo \$GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin${NC}"
    echo ""
    exit 1
fi
