---
name: provision-agent
description: Provision an OpenClaw AI agent on a server via TUI interview
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[server-id]"
---

# /provision-agent Command

Provision an OpenClaw AI agent on a server through an interactive TUI interview.
Generates the `.env` file, deploys via Docker Compose, and configures messaging channels.

## Prerequisites

- Device profile must exist with at least one server
- Target server must have Docker and Docker Compose installed
- SSH access to the target server

## Workflow

### Step 1: Profile Gate

Verify profile exists and has servers:

```bash
result=$("${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "HALT: No profile. Run /setup-profile first."
    exit 1
fi

PROFILE_PATH=$(echo "$result" | jq -r '.path')
SERVERS=$(jq '.servers | length' "$PROFILE_PATH")
if [[ "$SERVERS" -eq 0 ]]; then
    echo "No servers in profile. Run /provision first."
    exit 1
fi
```

### Step 2: Server Selection

If no server-id argument, list servers and ask:

Ask: "Which server should the OpenClaw agent be deployed to?"

Display servers from profile with role and status. Prefer servers with role `openclaw` or `empty`.

### Step 3: Agent Identity

Ask: "What should this agent be named?"

- Agent name becomes the Docker container name and config directory
- Default suggestion: `openclaw-<purpose>` (e.g., `openclaw-support`, `openclaw-dev`)

### Step 4: AI Provider Selection

Ask: "Which AI providers should this agent use?" (multi-select)

| Option | Env Var | Notes |
|--------|---------|-------|
| Anthropic Claude (Recommended) | `ANTHROPIC_API_KEY` | Best tool use support |
| OpenAI | `OPENAI_API_KEY` | GPT-4o and variants |
| Google Gemini | `GEMINI_API_KEY` | Gemini Pro/Ultra |
| Groq | `GROQ_API_KEY` | Fast inference |
| Ollama (local) | `OLLAMA_BASE_URL` | Self-hosted models |

For each selected provider, ask for the API key. Retrieve from secrets backend first:

```bash
source "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/secrets"
# Try to retrieve existing key
existing=$(get_secret "ANTHROPIC_API_KEY" 2>/dev/null)
```

If a key exists in secrets, offer to reuse it.

### Step 5: Messaging Channels

Ask: "Which messaging channels should this agent connect to?" (multi-select)

| Option | Required Config |
|--------|----------------|
| Web UI only (default) | None — dashboard at `:8080` |
| Telegram | Bot token, DM policy, allowed users |
| Discord | Bot token, DM policy |
| Slack | Bot token, app token |
| WhatsApp | DM policy, allowed numbers |

For each selected channel, gather required configuration:

#### Telegram
1. Bot token (from @BotFather)
2. DM policy: `pairing` / `allow` / `deny`
3. Allowed user IDs (comma-separated, optional if policy is `pairing`)

#### Discord
1. Bot token (from Discord Developer Portal)
2. DM policy: `pairing` / `allow` / `deny`

#### Slack
1. Bot token (`xoxb-...`)
2. App token (`xapp-...`)

#### WhatsApp
1. DM policy: `pairing` / `allow` / `deny`
2. Allowed phone numbers (E.164 format)

### Step 6: Optional Features

Ask: "Enable any additional features?" (multi-select)

| Option | Config |
|--------|--------|
| Browser automation | Adds browser sidecar container |
| Webhooks | Sets `HOOKS_ENABLED=true`, generates token |
| Audio transcription | Requires `DEEPGRAM_API_KEY` |

### Step 7: Security Configuration

Auto-generate security tokens:

```bash
GATEWAY_TOKEN=$(openssl rand -hex 32)
AUTH_PASSWORD=$(openssl rand -base64 16)
```

Ask: "Set a custom auth password, or use the generated one?"

Show the generated password and let user override.

### Step 8: Confirm and Deploy

Show summary:

```
Agent Provisioning Summary:
- Name: openclaw-support
- Server: kasm-one (98.76.54.32)
- Providers: Anthropic, OpenAI
- Channels: Telegram, Web UI
- Browser sidecar: Yes
- Auth password: ********

This will:
1. SSH to server
2. Create /opt/<agent-name>/ directory
3. Write .env and docker-compose.yml
4. Pull images and start containers
5. Verify health

Proceed?
```

### Step 9: Execute Deployment

```bash
SERVER_HOST=$(jq -r ".servers[] | select(.id == \"$SERVER_ID\") | .host" "$PROFILE_PATH")
SERVER_USER=$(jq -r ".servers[] | select(.id == \"$SERVER_ID\") | .username // \"root\"" "$PROFILE_PATH")
AGENT_DIR="/opt/${AGENT_NAME}"

# Create directory
ssh "${SERVER_USER}@${SERVER_HOST}" "mkdir -p ${AGENT_DIR}"

# Upload .env
scp /tmp/${AGENT_NAME}.env "${SERVER_USER}@${SERVER_HOST}:${AGENT_DIR}/.env"

# Upload docker-compose.yml
scp /tmp/${AGENT_NAME}-compose.yml "${SERVER_USER}@${SERVER_HOST}:${AGENT_DIR}/docker-compose.yml"

# Set permissions
ssh "${SERVER_USER}@${SERVER_HOST}" "chmod 600 ${AGENT_DIR}/.env && chown -R 1000:1000 ${AGENT_DIR}"

# Deploy
ssh "${SERVER_USER}@${SERVER_HOST}" "cd ${AGENT_DIR} && docker compose pull && docker compose up -d"
```

### Step 10: Health Check

```bash
# Wait for startup
sleep 10

# Check container status
ssh "${SERVER_USER}@${SERVER_HOST}" "docker inspect --format='{{.State.Health.Status}}' ${AGENT_NAME}"

# Verify gateway binding
ssh "${SERVER_USER}@${SERVER_HOST}" "docker exec ${AGENT_NAME} ss -tlnp | grep 18789"
# Expected: 127.0.0.1:18789 (NOT 0.0.0.0)
```

### Step 11: Update Profile

Add deployment to profile:

```bash
jq --arg name "$AGENT_NAME" --arg server "$SERVER_ID" --arg date "$(date -Iseconds)" \
  '.deployments[$name] = {"type":"openclaw","serverId":$server,"status":"active","deployedAt":$date}' \
  "$PROFILE_PATH" > /tmp/profile-update.json && mv /tmp/profile-update.json "$PROFILE_PATH"
```

### Step 12: Log and Report

```bash
log_admin_event "Provisioned OpenClaw agent ${AGENT_NAME} on ${SERVER_ID}" "OK"
```

Report success with:
- Dashboard URL: `http://<server-ip>:8080/`
- Auth credentials (remind to save securely)
- Connected channels summary
- Verification: `docker exec <agent-name> openclaw doctor --fix`
- Next steps: configure Cloudflare Tunnel for HTTPS

## Docker Compose Template

The command generates a `docker-compose.yml` from the openclaw skill template:

- **Base**: `coollabsio/openclaw:latest` with security defaults
- **Browser sidecar** (if enabled): `coollabsio/openclaw-browser:latest` with 2GB shm
- **Volumes**: Named volumes for persistence (`<agent-name>-data`, `<agent-name>-browser`)
- **Security**: `OPENCLAW_GATEWAY_BIND=loopback` always set

Reference: `${CLAUDE_PLUGIN_ROOT}/skills/openclaw/SKILL.md` for compose template and security rules.

## Error Handling

- **SSH connection failed**: Verify server is running, check SSH key in profile
- **Docker not installed**: Offer to install via `/deploy` prerequisites
- **Port 8080 in use**: Ask user for alternative port or detect existing OpenClaw
- **Image pull failed**: Check internet connectivity on server
- **Health check failed**: Show container logs, suggest `openclaw doctor --fix`
- **Binding not loopback**: CRITICAL — stop and fix before proceeding

## Tips

- One server can run multiple OpenClaw agents on different ports
- Use Cloudflare Tunnel instead of exposing ports directly
- Store API keys in Infisical/vault, not in the `.env` file on disk
- Each agent gets isolated session storage under `/data/.openclaw/agents/`
