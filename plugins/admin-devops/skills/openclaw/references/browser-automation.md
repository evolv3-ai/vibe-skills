# OpenClaw Browser Automation

## Overview

OpenClaw supports browser automation via Chrome DevTools Protocol (CDP). This enables:
- Authenticated web interactions
- Screenshot capture
- Script evaluation (optional, security-gated)
- Session persistence across restarts

Browser automation requires a **sidecar container** - OpenClaw does not bundle Chromium.

## Browser Sidecar Setup

### Option 1: Official OpenClaw Browser (Recommended)

```yaml
services:
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
  browser-data:
```

### Option 2: KASM Chrome Image

Useful when running on KASM infrastructure - provides VNC access for manual auth workflows.

```yaml
services:
  browser:
    image: kasmweb/chrome:1.17.0
    container_name: openclaw-browser
    restart: unless-stopped
    shm_size: 2gb
    environment:
      - PUID=1000
      - PGID=1000
      - VNC_PW=password
    ports:
      - "6901:6901"    # noVNC web access for manual auth
    volumes:
      - browser-data:/config

volumes:
  browser-data:
```

Access VNC at `https://localhost:6901/` for manual authentication workflows.

## Connecting OpenClaw to Browser

```bash
# Environment variable
BROWSER_CDP_URL=http://browser:9223
```

Or in docker-compose.yml:

```yaml
services:
  openclaw-gateway:
    environment:
      - BROWSER_CDP_URL=http://browser:9223
    depends_on:
      - browser
```

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `BROWSER_CDP_URL` | - | Chrome DevTools Protocol URL |
| `BROWSER_EVALUATE_ENABLED` | `false` | Enable script evaluation (security risk) |
| `BROWSER_REMOTE_TIMEOUT_MS` | `1500` | Connection timeout in ms |

### Script Evaluation

**WARNING**: Enabling script evaluation allows OpenClaw to execute arbitrary JavaScript in the browser context. Only enable in trusted environments.

```bash
BROWSER_EVALUATE_ENABLED=true   # Default: false
```

## Use Cases

### Screenshot Capture

OpenClaw agents can take screenshots of web pages for visual context.

### Authenticated Web Sessions

For services requiring login (OAuth, session-based):
1. Use VNC access (kasmweb/chrome) to manually log in
2. Session cookies persist in browser volume
3. OpenClaw can then interact with authenticated pages

### Web Scraping

Agents can navigate pages and extract content via CDP.

## Resource Requirements

The browser sidecar needs:
- **RAM**: 2 GB minimum (`shm_size: 2gb` required for Chrome)
- **Disk**: 1-2 GB for browser data
- **CPU**: 1 core minimum

## Troubleshooting

### Browser not connecting

```bash
# Check browser container is running
docker ps | grep browser

# Test CDP connection
docker exec openclaw curl -s http://browser:9223/json/version

# Check browser logs
docker logs openclaw-browser
```

### Shared memory errors

Chrome requires adequate shared memory. Always set `shm_size: 2gb` in compose file.

```yaml
services:
  browser:
    shm_size: 2gb    # Required for Chrome stability
```

### Session data lost

Ensure browser volume is persistent:

```yaml
volumes:
  browser-data:    # Named volume persists across restarts
```

For KASM deployments, use persistent profiles or named volumes that survive workspace sessions.
