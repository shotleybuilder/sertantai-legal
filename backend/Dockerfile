################################################################################
# Builder Stage
################################################################################
FROM elixir:1.18.4-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    postgresql-client

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Copy dependency files first (for better layer caching)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile application
RUN mix compile

# Build release
RUN mix release

################################################################################
# Runner Stage
################################################################################
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    postgresql-client \
    bash

# Set ERL tuning for containerized environment
ENV ERL_MAX_PORTS=8192 \
    ERL_MAX_ETS_TABLES=1024 \
    LANG=C.UTF-8

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/sertantai_legal ./

# Create non-root user
RUN addgroup -g 1000 sertantai && \
    adduser -D -u 1000 -G sertantai sertantai && \
    chown -R sertantai:sertantai /app

USER sertantai

EXPOSE 4000

# Health check using the dedicated endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start script: run migrations then start server
CMD ["/bin/bash", "-c", "/app/bin/sertantai_legal eval 'SertantaiLegal.Release.migrate()' && /app/bin/sertantai_legal start"]
