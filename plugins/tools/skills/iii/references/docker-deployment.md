# iii Docker Deployment Reference

> Docker Compose patterns, project structure, deployment configurations, and iii Console.

---

## Docker Compose Pattern

```yaml
services:
  my-service:
    build: ./services/my-service
    environment:
      III_BRIDGE_URL: ws://host.docker.internal:49134
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Required on Linux
    restart: unless-stopped
```

Run the iii engine on the **host**, not inside Docker. Services connect via `host.docker.internal`.

---

## Project Structure

```
my-iii-project/
├── iii-config.yaml          # Engine configuration
├── docker-compose.yaml      # Optional: containerized services
├── services/
│   ├── client/              # TypeScript orchestrator
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/worker.ts
│   ├── data-service/        # Python service
│   │   ├── requirements.txt
│   │   └── data_service.py
│   └── compute-service/     # Rust service
│       ├── Cargo.toml
│       └── src/main.rs
└── data/                    # Engine data (gitignored)
    ├── state_store.db
    └── streams_store/
```

---

## Docker Deployment

### Single Container

```bash
docker pull iiidev/iii:latest

docker run -p 3111:3111 -p 49134:49134 -p 3112:3112 -p 9464:9464 \
  -v ./iii-config.yaml:/app/config.yaml:ro \
  iiidev/iii:latest
```

### Production with Caddy (TLS)

```bash
docker compose -f docker-compose.prod.yml up -d
```

Caddy reverse proxy routes:
- `/api/*` -> port 3111 (REST API)
- `/ws` -> port 49134 (WebSocket)
- `/streams/*` -> port 3112 (Streams)

### Security Hardening

```bash
docker run --read-only --tmpfs /tmp \
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  -v ./config.yaml:/app/config.yaml:ro \
  iiidev/iii:latest
```

---

## iii Console

The iii Console is a web UI for inspecting engine state. Install via npm:

```bash
npm install -g @anthropic/iii-console  # Check iii.dev/docs for current install
```

The Console connects to the engine's REST API (port 3111) and provides:
- Live function registry view
- Connected workers list
- Trigger configuration overview
- State and KV Server browser
