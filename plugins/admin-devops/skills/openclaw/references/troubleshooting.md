# OpenClaw Troubleshooting

Production-tested playbooks in **symptom -> root cause -> fix** format.

---

## Playbook 1: "1008 Token Mismatch"

**Symptom**: Gateway returns `1008` WebSocket error or "token mismatch" on connection.

**Root Cause**: Stale environment variables from a previous run override the current config. Docker layer caching preserves old values.

**Fix**:

```bash
# 1. Stop container
docker compose down

# 2. Verify .env has correct token
cat .env | grep OPENCLAW_GATEWAY_TOKEN

# 3. Rebuild without cache
docker compose build --no-cache

# 4. Restart
docker compose up -d

# 5. Verify token matches
docker exec openclaw env | grep OPENCLAW_GATEWAY_TOKEN
```

**Prevention**: Always explicitly set `OPENCLAW_GATEWAY_TOKEN` in `.env`. Don't rely on auto-generation across rebuilds.

---

## Playbook 2: EACCES Permission Denied

**Symptom**: Container fails to start with `EACCES` errors on `/home/node/.openclaw` or `/data`.

**Root Cause**: Container runs as non-root user `node` (uid 1000). Host directories have wrong ownership.

**Fix**:

```bash
# For bind mounts
sudo chown -R 1000:1000 /path/to/openclaw/data

# For named volumes (recreate if corrupted)
docker volume rm openclaw-data
docker compose up -d  # Volume recreated with correct perms
```

**Prevention**: Always set ownership before first run. Named volumes (default) handle this automatically.

---

## Playbook 3: "context_length_exceeded" False Positive

**Symptom**: "context_length_exceeded" error even when context isn't full.

**Root Cause**: Incorrect token count calculation in session history (GitHub issue #7483).

**Fix**:

```bash
# 1. Clear specific session
docker exec openclaw openclaw session clear <session-id>

# 2. Or reduce history limits
TELEGRAM_HISTORY_LIMIT=10   # Default: unlimited
DISCORD_HISTORY_LIMIT=10    # Default: 20
SLACK_HISTORY_LIMIT=20      # Default: 50
```

**Prevention**: Set explicit history limits for all channels. Don't rely on unlimited history.

---

## Playbook 4: Gateway Exposed to Internet

**Symptom**: Security scan shows port 18789 open publicly. Or: unexpected API usage/billing.

**Root Cause**: `OPENCLAW_GATEWAY_BIND` not set to `loopback`, defaulting to `0.0.0.0`.

**Fix**:

```bash
# 1. Immediately add to .env
echo "OPENCLAW_GATEWAY_BIND=loopback" >> .env

# 2. Restart
docker compose restart

# 3. Verify binding
docker exec openclaw ss -tlnp | grep 18789
# Must show 127.0.0.1:18789

# 4. Block at firewall
sudo ufw deny 18789/tcp

# 5. Rotate all API keys (assume compromised)
# Update ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.

# 6. Rotate gateway token
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
```

**Prevention**: Always set `OPENCLAW_GATEWAY_BIND=loopback` in every deployment. Add to deployment checklist.

---

## Playbook 5: Bot Not Responding (Any Channel)

**Symptom**: Messages to Telegram/Discord/Slack bot go unanswered.

**Root Cause**: Multiple possibilities - check in order.

**Diagnostic sequence**:

```bash
# 1. Check container is running
docker ps | grep openclaw

# 2. Check logs for errors
docker logs --tail 50 openclaw 2>&1 | grep -i error

# 3. Run diagnostic
docker exec openclaw openclaw doctor --fix

# 4. Check full status
docker exec openclaw openclaw status --all

# 5. Check specific channel
docker logs openclaw 2>&1 | grep -i telegram  # or discord/slack/whatsapp
```

**Common causes**:
- Invalid bot token → regenerate token, update env var
- Missing OAuth scopes (Slack/Discord) → check app configuration
- Gateway process crashed → `docker restart openclaw`
- Network connectivity → check DNS, firewall rules
- Rate limited → check provider dashboard for 429 errors

---

## Playbook 6: "401 Invalid Beta Flag" (Bedrock/Vertex)

**Symptom**: 401 errors with "invalid beta flag" when using AWS Bedrock or Google Vertex AI.

**Root Cause**: API version mismatch or incorrect endpoint configuration.

**Fix**:

```bash
# 1. Update to latest OpenClaw
docker compose pull
docker compose up -d

# 2. Verify AWS credentials
docker exec openclaw env | grep AWS

# 3. Check region
# AWS_REGION must match your Bedrock model availability
AWS_REGION=us-east-1
```

---

## Playbook 7: OAuth Callback Fails (Headless)

**Symptom**: OAuth flow tries to open `http://127.0.0.1:1455/auth/callback` in browser; fails in headless/Docker environment.

**Root Cause**: OAuth callbacks require local browser access, unavailable in containers.

**Fix**:

1. Watch container logs for the full redirect URL
2. Copy the complete URL (including all query parameters)
3. Open in a local browser OR paste back into the CLI wizard
4. Complete authentication in the browser
5. The callback URL will be captured

**On KASM**: Use a browser workspace to complete OAuth flows, then copy tokens to OpenClaw config.

---

## Playbook 8: Runtime Package Installation Fails

**Symptom**: `apt-get install` or `npm install -g` fails with permission errors inside container.

**Root Cause**: Container runs as non-root user `node`. No sudo access.

**Fix**:

```bash
# Option 1: Rebuild with packages
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg python3 build-essential"
docker compose build --no-cache
docker compose up -d

# Option 2: Custom Dockerfile
cat > Dockerfile.custom << 'EOF'
FROM coollabsio/openclaw:latest
USER root
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*
USER node
EOF
docker build -t openclaw-custom:latest -f Dockerfile.custom .
# Update docker-compose.yml to use openclaw-custom:latest
```

---

## Playbook 9: WhatsApp Configuration Ignored

**Symptom**: WhatsApp settings from JSON config not applied; channel uses defaults.

**Root Cause**: WhatsApp uses **full-overwrite mode**. When `WHATSAPP_ENABLED=true`, the entire WhatsApp config block is replaced by environment variables. Unset env vars revert to defaults.

**Fix**:

Set ALL WhatsApp variables when enabling:

```bash
WHATSAPP_ENABLED=true
WHATSAPP_DM_POLICY=allow           # Don't rely on JSON default
WHATSAPP_ALLOW_FROM=+1234567890    # Must re-specify
WHATSAPP_MEDIA_MAX_MB=50           # Must re-specify
```

**Note**: This only affects WhatsApp. Telegram, Discord, and Slack use merge mode.

---

## General Diagnostic Commands

```bash
# Full diagnostic scan (auto-fixes common issues)
docker exec openclaw openclaw doctor --fix

# System status
docker exec openclaw openclaw status --all

# Health check
docker inspect --format='{{.State.Health.Status}}' openclaw

# Gateway health
docker exec openclaw node dist/index.js health \
  --token "$OPENCLAW_GATEWAY_TOKEN"

# View all logs
docker logs -f openclaw

# Filter error logs
docker logs openclaw 2>&1 | grep -i error | tail -20

# Check resource usage
docker stats openclaw --no-stream

# Verify environment
docker exec openclaw env | sort

# Check binding (security)
docker exec openclaw ss -tlnp | grep 18789
```
