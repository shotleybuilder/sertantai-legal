#!/bin/bash
#
# build-backend.sh - Build production Docker image for sertantai-legal Backend
#
# This script builds the production Docker image for the Phoenix/Ash backend.
# The image is tagged for GitHub Container Registry (GHCR).
#
# Usage:
#   sert-legal-be [tag]
#   ./scripts/deployment/build-backend.sh [tag]
#
# Arguments:
#   tag - Optional image tag (default: latest)
#
# Prerequisites:
#   - Docker installed and running
#   - backend/Dockerfile present
#
# Next steps after successful build:
#   - Push to GHCR: sert-legal-push-be
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help text
show_help() {
    echo "Usage: $0 [options] [tag]"
    echo ""
    echo "Build production Docker image for Sertantai Legal Backend."
    echo ""
    echo "Arguments:"
    echo "  tag              Image tag (default: latest)"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  --no-cache       Build without Docker cache"
    echo ""
    echo "Examples:"
    echo "  $0               Build with tag 'latest'"
    echo "  $0 v1.2.3        Build with tag 'v1.2.3'"
    echo "  $0 --no-cache    Build 'latest' without cache"
    exit 0
}

# Parse flags
NO_CACHE=""
IMAGE_TAG="latest"

for arg in "$@"; do
    case "$arg" in
        -h|--help) show_help ;;
        --no-cache) NO_CACHE="--no-cache" ;;
        *) IMAGE_TAG="$arg" ;;
    esac
done

# Image configuration (update with your GitHub org/user)
IMAGE_NAME="ghcr.io/shotleybuilder/sertantai-legal-backend"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Navigate to project root (two levels up from scripts/deployment/)
cd "$(dirname "$0")/../.."

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sertantai Legal Backend - Docker Build${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
echo -e "${YELLOW}Dockerfile:${NC} backend/Dockerfile"
echo -e "${YELLOW}Context:${NC} ./backend"
echo ""

# Check if Dockerfile exists
if [ ! -f "backend/Dockerfile" ]; then
    echo -e "${RED}✗ Error: backend/Dockerfile not found${NC}"
    echo -e "${YELLOW}  Current directory: $(pwd)${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Error: Docker is not running${NC}"
    echo -e "${YELLOW}  Please start Docker and try again${NC}"
    exit 1
fi

# Display build information
echo -e "${BLUE}Building Docker image...${NC}"
echo ""

# Build the image with progress output
docker build \
    ${NO_CACHE} \
    --tag "${FULL_IMAGE}" \
    --file backend/Dockerfile \
    backend/

# Check build success
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Backend build complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"

    # Display image details
    IMAGE_SIZE=$(docker images --format "{{.Size}}" "${FULL_IMAGE}" | head -1)
    IMAGE_ID=$(docker images --format "{{.ID}}" "${FULL_IMAGE}" | head -1)
    echo -e "${YELLOW}Size:${NC} ${IMAGE_SIZE}"
    echo -e "${YELLOW}ID:${NC} ${IMAGE_ID}"
    echo ""

    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  ${GREEN}→${NC} Push to GHCR:  ${YELLOW}sert-legal-push-be${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Backend build failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Check the output above for error details${NC}"
    exit 1
fi
