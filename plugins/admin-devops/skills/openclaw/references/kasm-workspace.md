# OpenClaw on KASM Workspaces

Deploy OpenClaw as a KASM workspace for browser-accessible AI gateway management.

## Prerequisites

- KASM Workspaces 1.17.0+ installed and running (see `kasm` skill)
- Docker available on KASM server
- At least one AI provider API key

## Strategy: Docker-in-Docker via KASM

OpenClaw runs as a Docker container. On KASM, there are two deployment approaches:

### Option A: Dedicated Docker Service (Recommended)

Run OpenClaw alongside KASM as a standalone Docker service on the same host.
Access via KASM's reverse proxy or direct port.

**Advantages**: Independent lifecycle, survives KASM restarts, simpler resource management.

### Option B: KASM Custom Workspace Image

Build a custom KASM workspace image that includes OpenClaw.
Users launch it like any other KASM workspace.

**Advantages**: Per-user isolation, KASM session management, browser-based access.

---

## Option A: Standalone Service on KASM Host

### Step 1: Create OpenClaw directory

```bash
sudo mkdir -p /opt/openclaw
sudo chown -R 1000:1000 /opt/openclaw
cd /opt/openclaw
```

### Step 2: Create docker-compose.yml

```yaml
services:
  openclaw-gateway:
    image: coollabsio/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "8180:8080"    # Use 8180 to avoid KASM port conflicts
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AUTH_USERNAME=admin
      - AUTH_PASSWORD=${AUTH_PASSWORD}
      - OPENCLAW_GATEWAY_BIND=loopback
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
    volumes:
      - /opt/openclaw/data:/data
    networks:
      - openclaw-net

networks:
  openclaw-net:
    driver: bridge
```

### Step 3: Create .env

```bash
cat > /opt/openclaw/.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-your-key
AUTH_PASSWORD=strong-password
OPENCLAW_GATEWAY_TOKEN=generated-token
EOF
```

### Step 4: Launch

```bash
cd /opt/openclaw
docker compose up -d
```

### Step 5: Access via KASM

Add a KASM Web Application pointing to `http://localhost:8180/`.

In KASM Admin > Workspaces > Add Workspace:
- **Workspace Type**: Container
- **Friendly Name**: OpenClaw AI Gateway
- **Docker Image**: `kasmweb/chrome:1.17.0` (browser to access OpenClaw UI)
- **Launch URL**: `http://host.docker.internal:8180/` or `http://<host-ip>:8180/`

Or configure a KASM Cast link for direct browser access.

---

## Option B: Custom KASM Workspace Image

### Step 1: Create Dockerfile

```dockerfile
FROM kasmweb/core-ubuntu-jammy:1.17.0
USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install

# Install Docker CLI (for managing openclaw container)
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu jammy stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (for native openclaw CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install OpenClaw CLI globally
RUN npm install -g openclaw@latest

# Copy startup script
COPY --chown=1000:0 startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

USER 1000

WORKDIR $HOME
```

### Step 2: Create startup.sh

```bash
#!/bin/bash
set -e

# Start OpenClaw daemon if API key is configured
if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$OPENAI_API_KEY" ]; then
    echo "Starting OpenClaw gateway..."
    openclaw daemon start &
    sleep 3
    echo "OpenClaw gateway started"
fi

# Open browser to OpenClaw dashboard
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    URL="http://localhost:18789"
    export KASM_LAUNCH_URL="$URL"
fi
```

### Step 3: Build and register

```bash
docker build -t openclaw-kasm:latest .
```

In KASM Admin > Workspaces > Add Workspace:
- **Workspace Type**: Container
- **Friendly Name**: OpenClaw AI Gateway
- **Docker Image**: `openclaw-kasm:latest`
- **Cores**: 2
- **Memory (MB)**: 4096
- **Persistent Profile Path**: `/opt/kasm/profiles/openclaw/{username}`

### Step 4: Configure environment variables

In KASM Admin > Workspace > Docker Run Config (Override):

```json
{
  "environment": {
    "ANTHROPIC_API_KEY": "sk-ant-your-key",
    "OPENCLAW_GATEWAY_BIND": "loopback",
    "AUTH_PASSWORD": "strong-password"
  }
}
```

---

## Persistent Storage on KASM

### Persistent Profile

Configure persistent profiles to preserve OpenClaw state across sessions:

KASM Admin > Workspace > Persistent Profile Path:
```
/opt/kasm/profiles/openclaw/{username}
```

This preserves:
- `/home/kasm-default-profile/.openclaw/` - Configuration and agent sessions
- Conversation history
- Custom agent configurations

### Volume Mapping

For shared data accessible across workspaces:

```json
{
  "volume_mappings": {
    "/opt/openclaw/shared": {
      "bind": "/home/kasm-user/openclaw-shared",
      "mode": "rw",
      "uid": 1000,
      "gid": 1000,
      "required": false
    }
  }
}
```

---

## Networking on KASM

### Port Considerations

| Port | Usage | Notes |
|------|-------|-------|
| 443 | KASM web interface | Standard KASM |
| 8080 | OpenClaw default | Change if conflicts |
| 8180 | OpenClaw alternate | Recommended for KASM hosts |
| 18789 | Gateway internal | Keep loopback only |

### Accessing OpenClaw from KASM Workspaces

If OpenClaw runs as standalone service (Option A), access from inside KASM workspaces:

```bash
# From inside a KASM workspace container
curl http://host.docker.internal:8180/healthz

# Or use the host IP directly
curl http://172.17.0.1:8180/healthz
```

### Reverse Proxy with KASM's nginx

To serve OpenClaw through KASM's existing nginx (port 443):

Add to `/opt/kasm/current/conf/nginx/containers.d/openclaw.conf`:

```nginx
location /openclaw/ {
    proxy_pass http://127.0.0.1:8180/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 86400;
}
```

Restart KASM nginx: `sudo /opt/kasm/bin/stop && sudo /opt/kasm/bin/start`

---

## Resource Planning

### Per-User OpenClaw Instance (Option B)

| Concurrent Users | Cores | RAM | Disk |
|-----------------|-------|-----|------|
| 1 | 2 | 4 GB | 10 GB |
| 5 | 10 | 20 GB | 50 GB |
| 10 | 16 | 40 GB | 100 GB |

### Shared OpenClaw Instance (Option A)

| Concurrent Conversations | Cores | RAM | Notes |
|--------------------------|-------|-----|-------|
| 1-5 | 2 | 4 GB | Single instance handles multiple channels |
| 5-20 | 4 | 8 GB | Add browser sidecar |
| 20+ | 8 | 16 GB | Consider multiple instances |

---

## Monitoring

```bash
# OpenClaw container health
docker inspect --format='{{.State.Health.Status}}' openclaw

# Resource usage
docker stats openclaw

# Gateway status
docker exec openclaw openclaw status --all

# KASM workspace sessions using OpenClaw
sudo docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT * FROM workspaces WHERE image LIKE '%openclaw%';"
```
