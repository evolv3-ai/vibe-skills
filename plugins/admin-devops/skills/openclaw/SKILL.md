---
name: openclaw
description: |
  Deploy and configure OpenClaw AI gateway on KASM workspaces or standalone Docker.
  Multi-provider LLM routing (Anthropic, OpenAI, Gemini, Groq, Bedrock) with multi-channel
  messaging (WhatsApp, Telegram, Discord, Slack). Covers Docker deployment, security
  hardening, persistent storage, browser sidecar, and webhook automation.

  Use when: deploying OpenClaw, configuring AI gateway channels, setting up openclaw
  container on KASM, troubleshooting "token mismatch" or "EACCES" errors, or securing
  gateway binding.
---

# OpenClaw - Self-Hosted AI Gateway

Deploy and manage OpenClaw (coollabsio/openclaw) as a containerized AI gateway.
Routes conversations between messaging platforms and multiple LLM providers with
full tool use, session isolation, and browser automation.

**Production Tested**: OpenClaw v2026.1.x on KASM 1.17.0 (Ubuntu 22.04)
**Source**: https://github.com/coollabsio/openclaw

---

## Step 0: Route to the Right Reference

| Task | Reference |
|------|-----------|
| Fresh Docker deployment | `references/installation.md` |
| KASM workspace setup | `references/kasm-workspace.md` |
| Environment variables & config | `references/configuration.md` |
| Messaging channels (Telegram, Discord, etc.) | `references/channels.md` |
| Security hardening | `references/security.md` |
| Troubleshooting errors | `references/troubleshooting.md` |
| Browser sidecar & automation | `references/browser-automation.md` |

---

## Critical Rules

1. **ALWAYS set `OPENCLAW_GATEWAY_BIND=loopback`** - Default binding exposes gateway to public internet on port 18789. This is a known critical security issue (Feb 2026).
2. **Never skip `AUTH_PASSWORD`** - nginx basic auth is the first defense layer.
3. **Set directory ownership to uid 1000** before mounting volumes - Container runs as non-root user `node`.
4. **API keys are environment-only** - Never put provider keys in JSON config files.
5. **WhatsApp uses full-overwrite mode** - When `WHATSAPP_ENABLED=true`, entire WhatsApp block is replaced (not merged).
6. **Environment variables override everything** - Three-tier merge: JSON < persisted state < env vars.
7. **On KASM**: Allocate minimum 4GB RAM per OpenClaw workspace, configure persistent profile for `/data` volume.

---

## Quick Reference

### Architecture

```
[Messaging Channels] → [OpenClaw Gateway :18789] → [LLM Providers]
       ↑                        ↑                         ↑
  WhatsApp, Telegram    nginx reverse proxy :8080    Anthropic, OpenAI
  Discord, Slack        HTTP Basic Auth              Gemini, Groq, etc.
  Google Chat, Signal   Webhook routing
```

### Default Ports

| Port | Service | Binding |
|------|---------|---------|
| 8080 | nginx reverse proxy (external) | Configurable via `PORT` |
| 18789 | OpenClaw gateway (internal) | **Must be loopback** |
| 9223 | Chrome CDP (browser sidecar) | Internal only |

### Supported AI Providers

Anthropic, OpenAI, Google Gemini, xAI Grok, Groq, Mistral, Cerebras,
Venice, Moonshot, Kimi, MiniMax, AWS Bedrock, Ollama (local), GitHub Copilot

### Supported Channels

WhatsApp (Baileys), Telegram (grammY), Discord (discord.js), Slack (Bolt),
Google Chat, Signal, iMessage/BlueBubbles, Microsoft Teams, Matrix, Zalo

---

## System Requirements

### Standalone Docker

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 2 GB | 4 GB+ |
| Disk | 10 GB | 20 GB+ |
| Docker | Engine + Compose v2 | Latest stable |
| Architecture | amd64 or arm64 | Either |

### KASM Workspace

| Resource | Value |
|----------|-------|
| Cores | 2 |
| Memory | 4096 MB |
| Docker image | `coollabsio/openclaw:latest` |
| Persistent profile | Required for `/data` |
| GPU | Not required |

### Required Configuration

At minimum, OpenClaw needs:
1. One AI provider API key (e.g., `ANTHROPIC_API_KEY`)
2. `AUTH_PASSWORD` for nginx basic auth
3. `OPENCLAW_GATEWAY_BIND=loopback` for security

---

## Minimal Deployment

```bash
docker run -d --name openclaw \
  -p 8080:8080 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e AUTH_PASSWORD=changeme \
  -e OPENCLAW_GATEWAY_BIND=loopback \
  -e OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32) \
  -v openclaw-data:/data \
  coollabsio/openclaw:latest
```

Access dashboard: `http://localhost:8080/`

---

## Health Check

```bash
# Container health
docker inspect --format='{{.State.Health.Status}}' openclaw

# Gateway health
docker exec openclaw node dist/index.js health \
  --token "$OPENCLAW_GATEWAY_TOKEN"

# Diagnostic scan
docker exec openclaw openclaw doctor --fix

# Full status
docker exec openclaw openclaw status --all

# Logs
docker logs -f openclaw
```

---

## Docker Compose (Full Setup with Browser)

```yaml
services:
  openclaw-gateway:
    image: coollabsio/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AUTH_USERNAME=admin
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

---

## Errors Prevented by This Skill

| # | Error | Root Cause | Prevention |
|---|-------|------------|------------|
| 1 | Gateway exposed to internet | Default `0.0.0.0` binding | Always set `OPENCLAW_GATEWAY_BIND=loopback` |
| 2 | "1008 token mismatch" | Stale env vars override config | Rebuild with `--no-cache`, verify env |
| 3 | EACCES permission denied | Non-root container (uid 1000) | `chown -R 1000:1000` on mount dirs |
| 4 | "context_length_exceeded" false positive | Incorrect token count | Clear session, reduce history limits |
| 5 | WhatsApp config ignored | Full-overwrite mode | Set all WhatsApp vars when enabled |
| 6 | API keys in config file | Keys leaked to logs/backups | Environment variables only |
| 7 | No runtime package install | Non-root container | Use `OPENCLAW_DOCKER_APT_PACKAGES` at build |
| 8 | Browser automation fails | No bundled Chromium | Use browser sidecar container |
