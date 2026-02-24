# OpenClaw Installation Guide

## Prerequisites

- Docker Engine + Docker Compose v2
- 4 GB+ RAM (2 GB absolute minimum)
- 10 GB+ disk space
- At least one AI provider API key
- Ubuntu 22.04/24.04 recommended (works on any Docker-capable Linux, macOS, WSL2)

## Method 1: Quick Docker Run

```bash
# Generate a gateway token
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)

# Run OpenClaw
docker run -d --name openclaw \
  -p 8080:8080 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e AUTH_PASSWORD=changeme \
  -e OPENCLAW_GATEWAY_BIND=loopback \
  -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN \
  -v openclaw-data:/data \
  coollabsio/openclaw:latest

# Verify
docker logs -f openclaw
```

Access: `http://localhost:8080/` (user: admin, password: your AUTH_PASSWORD)

## Method 2: Docker Compose (Recommended)

### Step 1: Create project directory

```bash
mkdir -p ~/openclaw && cd ~/openclaw
```

### Step 2: Create .env file

Copy from `assets/env-template` or create manually:

```bash
cat > .env << 'EOF'
OPENCLAW_GATEWAY_BIND=loopback
AUTH_USERNAME=admin
AUTH_PASSWORD=your-strong-password-here
OPENCLAW_GATEWAY_TOKEN=your-token-here
ANTHROPIC_API_KEY=sk-ant-your-key-here
PORT=8080
EOF
```

Generate token: `openssl rand -hex 32`

### Step 3: Create docker-compose.yml

```yaml
services:
  openclaw-gateway:
    image: coollabsio/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "${PORT:-8080}:8080"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AUTH_USERNAME=${AUTH_USERNAME:-admin}
      - AUTH_PASSWORD=${AUTH_PASSWORD}
      - OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-loopback}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
    volumes:
      - openclaw-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 5s
      start_period: 10s
      retries: 3

volumes:
  openclaw-data:
```

### Step 4: Launch

```bash
docker compose up -d
docker compose logs -f
```

### Step 5: Verify

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' openclaw

# Run diagnostic
docker exec openclaw openclaw doctor --fix

# Verify secure binding
docker exec openclaw ss -tlnp | grep 18789
# Expected: 127.0.0.1:18789 (NOT 0.0.0.0:18789)
```

## Method 3: Clone & Setup Script

```bash
git clone https://github.com/coollabsio/openclaw.git
cd openclaw
./docker-setup.sh
```

The setup script runs an interactive wizard that:
1. Builds the OpenClaw image
2. Walks through provider API key configuration
3. Generates gateway token
4. Creates `.env` file
5. Launches via docker-compose

## With Browser Sidecar

Add browser automation support for web interactions, screenshots, and authenticated sessions:

```yaml
services:
  openclaw-gateway:
    image: coollabsio/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "${PORT:-8080}:8080"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AUTH_USERNAME=${AUTH_USERNAME:-admin}
      - AUTH_PASSWORD=${AUTH_PASSWORD}
      - OPENCLAW_GATEWAY_BIND=loopback
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
      - BROWSER_CDP_URL=http://browser:9223
    volumes:
      - openclaw-data:/data
    depends_on:
      - browser

  browser:
    image: coollabsio/openclaw-browser:latest
    container_name: openclaw-browser
    restart: unless-stopped
    shm_size: 2gb
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - browser-data:/config

volumes:
  openclaw-data:
  browser-data:
```

Alternative browser image: `kasmweb/chrome:latest` (includes VNC access for manual auth workflows).

## Adding System Packages

Container runs as non-root (`node` user, uid 1000). Cannot install packages at runtime.

Install packages at build time:

```bash
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential python3"
./docker-setup.sh
```

Or add to Dockerfile:

```dockerfile
FROM coollabsio/openclaw:latest
USER root
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*
USER node
```

## Swap Configuration

For servers with < 4 GB RAM:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Volume Permissions

**Critical**: Container runs as uid 1000. Set ownership before first run:

```bash
sudo mkdir -p /path/to/openclaw-data
sudo chown -R 1000:1000 /path/to/openclaw-data
```

For named volumes (default), Docker handles permissions automatically.

## Updating

```bash
cd ~/openclaw
docker compose pull
docker compose down
docker compose up -d
```

Or with the setup script:

```bash
cd ~/openclaw
git pull
./docker-setup.sh
```

**Important**: After updating, rebuild without cache if experiencing stale config issues:

```bash
docker compose build --no-cache
docker compose up -d
```

## Uninstalling

```bash
docker compose down
docker volume rm openclaw-data browser-data  # Removes all data
# Or keep data: docker compose down (volumes persist)
```
