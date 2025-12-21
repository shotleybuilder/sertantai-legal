# Development Scripts

Quick start/stop scripts for Ash + ElectricSQL + Svelte + TanStack development.

## Quick Start

```bash
# From anywhere in your project
./scripts/development/dev-start

# Stop servers
./scripts/development/dev-stop
```

## Global Installation (Optional)

Create symlinks for easy access from anywhere:

```bash
# Replace 'myproject' with your project name
sudo ln -sf $(pwd)/scripts/development/dev-start /usr/local/bin/myproject-start
sudo ln -sf $(pwd)/scripts/development/dev-stop /usr/local/bin/myproject-stop

# Then use from anywhere:
myproject-start
myproject-stop
```

## What Gets Started

The `dev-start` script opens **3 terminal windows**:

1. **Backend** (`{project}-backend`) - Phoenix/Ash server
2. **Frontend** (`{project}-frontend`) - SvelteKit dev server
3. **Console** (`{project}-console`) - Interactive shell with helpful info

## Port Configuration

Default ports can be customized via environment variables:

```bash
# Custom ports (add to ~/.bashrc or run before starting)
export BACKEND_PORT=4002
export FRONTEND_PORT=5173
export DB_PORT=5434
export ELECTRIC_PORT=3001

# Then start normally
./scripts/development/dev-start
```

**Default Ports:**
- Backend: `4000`
- Frontend: `5173`
- Database: `5432`
- Electric: `3000`

## Project-Specific Setup

When creating a new project from this template:

1. **Copy scripts** to your new project
2. **Update symlinks** with your project name
3. **Set custom ports** if needed (to avoid conflicts with other projects)
4. **Verify docker-compose.dev.yml** matches your port configuration

### Example: Multiple Projects

```bash
# Project 1: sertantai-auth (default ports)
cd ~/projects/sertantai-auth
sudo ln -sf $(pwd)/scripts/development/dev-start /usr/local/bin/sert-auth-start
sudo ln -sf $(pwd)/scripts/development/dev-stop /usr/local/bin/sert-auth-stop

# Project 2: sertantai-enforcement (custom ports)
cd ~/projects/sertantai-enforcement
export BACKEND_PORT=4002 FRONTEND_PORT=5173 DB_PORT=5434 ELECTRIC_PORT=3001
sudo ln -sf $(pwd)/scripts/development/dev-start /usr/local/bin/sert-enf-start
sudo ln -sf $(pwd)/scripts/development/dev-stop /usr/local/bin/sert-enf-stop
```

## Features

- ✅ Auto-detects project name from directory
- ✅ Verifies Docker services are running (starts if needed)
- ✅ Checks for already-running servers (prevents conflicts)
- ✅ Named terminal windows for easy identification
- ✅ Auto-closes backend/frontend windows on stop
- ✅ Console window stays open for reference
- ✅ Works from symlinks (resolves actual script location)
- ✅ Configurable ports via environment variables

## Prerequisites

- **gnome-terminal** (Ubuntu default)
- **Docker** + **docker-compose**
- **Phoenix/Ash** backend in project root
- **SvelteKit** frontend in `frontend/` subdirectory

## Troubleshooting

### Frontend shows "vite: not found"

Install dependencies first:
```bash
cd frontend
npm install
```

### Only one terminal window opens

Check gnome-terminal version. Scripts use separate windows for compatibility.

### Ports already in use

Either stop conflicting services or set custom ports:
```bash
export BACKEND_PORT=4003 FRONTEND_PORT=5174
./scripts/development/dev-start
```

### Docker services not starting

Manually start Docker services:
```bash
docker compose -f docker-compose.dev.yml up -d postgres electric redis
```

## How It Works

**dev-start:**
1. Resolves symlink to find actual project location
2. Auto-detects project name from directory
3. Validates project structure (mix.exs, frontend/)
4. Checks for running servers
5. Starts Docker services if needed
6. Opens 3 terminal windows with appropriate commands

**dev-stop:**
1. Kills Phoenix processes (`mix phx.server`)
2. Kills Vite processes on configured port
3. Terminal windows auto-close (except console)

## Customization

Edit the scripts directly to customize:
- Docker service names
- Additional checks or validations
- Terminal window layout
- Console information displayed

The scripts are designed to be simple and hackable!
