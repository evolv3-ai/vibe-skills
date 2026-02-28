# OpenClaw Security Hardening

## Critical: Gateway Binding

**The single most important security setting.**

OpenClaw's default configuration in some deployments binds the gateway to `0.0.0.0:18789`, exposing it to the public internet. This was flagged as a critical security issue in February 2026 by STRIKE researchers.

### What's at risk

An exposed gateway allows attackers to:
- Steal API keys (financial liability)
- Read conversation history
- Execute tools on the server
- Abuse your AI provider accounts

### Fix

**Always set in every deployment**:

```bash
OPENCLAW_GATEWAY_BIND=loopback
```

### Verify

```bash
# Check binding
docker exec openclaw ss -tlnp | grep 18789

# SAFE output:
# LISTEN 0 128 127.0.0.1:18789 ...

# DANGEROUS output:
# LISTEN 0 128 0.0.0.0:18789 ...
```

### Binding options

| Value | Binds to | Use case |
|-------|----------|----------|
| `loopback` | `127.0.0.1` | **Default for production** |
| `lan` | `0.0.0.0` | **DANGEROUS** - all interfaces |
| `tailnet` | Tailscale IP | Tailscale network only |
| `auto` | Auto-detect | Let OpenClaw decide |

## Authentication Layers

OpenClaw has three independent authentication systems:

### Layer 1: nginx Basic Auth

Protects the web dashboard and proxied gateway.

```bash
AUTH_USERNAME=admin          # Default username
AUTH_PASSWORD=strong-pass    # REQUIRED - set this
```

### Layer 2: Gateway Token

Bearer token for API access. Used by CLI tools and webhooks.

```bash
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
```

### Layer 3: Webhook Token

Separate token for webhook endpoints (if enabled).

```bash
HOOKS_TOKEN=$(openssl rand -hex 16)
```

**Important**: Each layer is independent. Compromising one doesn't compromise others.

## API Key Security

### Rules

1. **Environment variables only** - Never put API keys in JSON config files
2. **Never commit to git** - Use `.env` files (gitignored) or secrets management
3. **Rotate regularly** - Especially if you suspect exposure
4. **Use minimum permissions** - Use API keys with restricted scopes where possible

### Checking for exposed keys

```bash
# Verify keys aren't in JSON config
docker exec openclaw cat /data/.openclaw/config.json | grep -i api_key
# Should return nothing

# Check keys are only in environment
docker exec openclaw env | grep API_KEY
```

## Container Security

### Non-root execution

Container runs as user `node` (uid 1000). This limits damage if compromised.

**Implications**:
- Cannot install packages at runtime (`apt-get` fails)
- Cannot bind to ports < 1024
- Cannot modify system files
- Must pre-set volume permissions to uid 1000

### Volume permissions

```bash
# Set correct ownership before mounting
sudo chown -R 1000:1000 /path/to/data
```

### Read-only mounts

For extra security, mount non-writable data as read-only:

```bash
OPENCLAW_EXTRA_MOUNTS="/etc/ssl/certs:/etc/ssl/certs:ro"
```

## Network Security

### Firewall Rules

Only expose the nginx port (8080). Never expose the gateway port (18789).

```bash
# UFW example
sudo ufw allow 8080/tcp    # OpenClaw web UI
sudo ufw deny 18789/tcp    # Block direct gateway access
```

### HTTPS

For production, always terminate TLS:

**Option 1: Cloudflare Tunnel** (recommended for KASM setups)
- See `kasm` skill > `references/cloudflare-tunnel.md`
- Set `noTLSVerify: true` in tunnel config for OpenClaw

**Option 2: Reverse proxy with Let's Encrypt**

```nginx
server {
    listen 443 ssl;
    server_name openclaw.example.com;

    ssl_certificate /etc/letsencrypt/live/openclaw.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/openclaw.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
}
```

## Agent Sandboxing

For multi-user deployments, enable sandboxed tool execution:

```bash
# Build sandbox image
docker exec openclaw scripts/sandbox-setup.sh

# Configure in JSON config
{
  "agents": {
    "defaults": {
      "sandbox": true
    }
  }
}
```

Non-main sessions execute tools in isolated containers (`openclaw-sandbox:bookworm-slim`).

## Security Checklist

- [ ] `OPENCLAW_GATEWAY_BIND=loopback` set
- [ ] Strong `AUTH_PASSWORD` configured
- [ ] `OPENCLAW_GATEWAY_TOKEN` generated with `openssl rand -hex 32`
- [ ] API keys in environment variables only (not JSON config)
- [ ] `.env` file not committed to git
- [ ] Firewall blocks port 18789 from external access
- [ ] HTTPS configured (Cloudflare Tunnel or reverse proxy)
- [ ] Volume permissions set to uid 1000
- [ ] Regular API key rotation scheduled
- [ ] Agent sandboxing enabled for multi-user deployments
- [ ] Binding verified: `ss -tlnp | grep 18789` shows `127.0.0.1`
