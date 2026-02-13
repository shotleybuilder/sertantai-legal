################################################################################
# Builder Stage
################################################################################
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies for build)
RUN npm ci

# Copy application code
COPY . .

# Build the SvelteKit application
RUN npm run build

################################################################################
# Runner Stage
################################################################################
FROM node:20-alpine

# Install production dependencies for serving
RUN npm install -g serve@14

WORKDIR /app

# Copy built assets from builder
COPY --from=builder /app/build ./build

# Use existing non-root 'node' user (UID/GID 1000 in node:alpine images)
RUN chown -R node:node /app

USER node

EXPOSE 3000

# Health check - serve has built-in health at root
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Serve static files with optimizations
CMD ["serve", "-s", "build", "-l", "3000", "--no-request-logging"]
