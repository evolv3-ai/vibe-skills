# Cloudflare Tunnel

**Status**: Production Ready | **Dependencies**: None (cloudflared auto-downloaded)

## Contents
- Prerequisites
- How It Works
- Critical Rules
- DNS Verification Commands
- Wildcard Mode (Recommended for Coolify)
- Service Configuration
- Troubleshooting
- Setup Steps
- API Token Permissions
- Verification Checklist
- References

---

## Prerequisites

Before starting, ensure you have:

1. **Cloudflare Account** with a domain added
2. **API Token** with permissions: `Account.Cloudflare Tunnel:Edit`, `Zone.DNS:Edit`
3. **Account ID** (from Cloudflare dashboard URL)
4. **Server access** (SSH) if deploying remotely

Required configuration (save to `.env.local` or have ready):

```bash
# Cloudflare credentials
CLOUDFLARE_API_TOKEN=your_api_token
CLOUDFLARE_ACCOUNT_ID=your_account_id

# Tunnel configuration
TUNNEL_NAME=my-app-tunnel
TUNNEL_HOSTNAME=app.yourdomain.com

# Service to expose
SERVICE_PROTOCOL=https  # or http
SERVICE_IP=localhost
SERVICE_PORT=8443       # your service port

# Server access (for remote deployment)
SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa
```

---

## How It Works

```
Internet → Cloudflare Edge → Tunnel (outbound only) → Your Server → Service
                              No inbound ports needed!
```

| Benefit | Description |
|---------|-------------|
| No open ports | No firewall rules needed |
| DDoS protection | Cloudflare handles attacks |
| Free SSL | Automatic HTTPS certificates |
| Global CDN | Edge locations worldwide |

---

## Critical Rules

### Always Do

✅ Set `"proxied":true` on DNS CNAME records (orange cloud)
✅ Use `noTLSVerify: true` for self-signed certificates
✅ Include catchall ingress rule `{"service": "http_status:404"}`
✅ Test local service first: `curl http://localhost:PORT`

### Never Do

❌ Set `"proxied":false` (causes NXDOMAIN errors)
❌ Commit tunnel tokens to version control
❌ Use `nslookup` for DNS verification (not installed on minimal Ubuntu/Debian)

❌ Omit catchall rule (tunnel won't start)
❌ Use short timeouts for streaming apps

### DNS Verification Commands

**IMPORTANT**: Do NOT use `nslookup` - it is not available on minimal Linux systems.

Use these commands instead:
```bash
# DNS lookup
dig ${TUNNEL_HOSTNAME} +short
# Expected: Cloudflare IPs

# HTTP verification
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://${TUNNEL_HOSTNAME}
# Expected: 200 or 302
```

---

## Wildcard Mode (Recommended for Coolify)

Wildcard routing enables ANY subdomain to work automatically without creating individual DNS records. This is ideal for Coolify where you deploy multiple apps.

```
*.yourdomain.com → Tunnel → Coolify Traefik → app1, app2, app3...
```

| Mode | DNS Records | Use Case |
|------|-------------|----------|
| **Single hostname** | `coolify.domain.com` | Single service |
| **Wildcard** | `*.domain.com` | Multiple apps via Coolify/Traefik |

**To enable wildcard mode**, set these in your configuration:

```bash
# Enable wildcard routing
WILDCARD_MODE=true

# Extract base domain from hostname
# e.g., coolify.example.com → example.com
BASE_DOMAIN=$(echo "$TUNNEL_HOSTNAME" | sed 's/^[^.]*\.//')
```

See Steps 4 and 5 for wildcard-specific commands.

---

## Service Configuration

<details>
<summary><strong>HTTPS services (KASM, self-signed certs)</strong></summary>

```yaml
ingress:
  - hostname: kasm.example.com
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
      tlsTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveConnections: 10
      keepAliveTimeout: 90s
  - service: http_status:404
```

**Key settings**:
- `noTLSVerify: true` - Required for self-signed certs
- Extended timeouts for desktop streaming

</details>

<details>
<summary><strong>HTTP services (Coolify, web apps)</strong></summary>

```yaml
ingress:
  - hostname: coolify.example.com
    service: http://localhost:8000
    originRequest:
      connectTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveConnections: 10
      keepAliveTimeout: 90s
  - service: http_status:404
```

No TLS settings needed for HTTP services.

</details>

<details>
<summary><strong>Multiple services (single tunnel)</strong></summary>

```yaml
ingress:
  - hostname: app.example.com
    service: http://localhost:3000

  - hostname: api.example.com
    service: http://localhost:8080

  - hostname: admin.example.com
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true

  - service: http_status:404
```

Create separate DNS CNAME records for each hostname.

</details>

<details>
<summary><strong>TCP services (databases)</strong></summary>

```yaml
ingress:
  - hostname: db.example.com
    service: tcp://localhost:5432

  - hostname: cache.example.com
    service: tcp://localhost:6379

  - service: http_status:404
```

Requires Cloudflare Access for security.

</details>

---

## Troubleshooting

<details>
<summary><strong>DNS_PROBE_FINISHED_NXDOMAIN</strong></summary>

**Cause**: CNAME record has `proxied:false` (gray cloud)

**Fix**: Update DNS record to enable proxy (orange cloud):

```bash
# Get current record
curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$TUNNEL_HOSTNAME" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Update to proxied
curl -s -X PATCH \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$DNS_RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"CNAME\",
    \"name\": \"$HOSTNAME_PART\",
    \"content\": \"$TUNNEL_ID.cfargotunnel.com\",
    \"proxied\": true
  }"
```

Or verify in Cloudflare dashboard: DNS → your record → ensure "Proxied" is enabled (orange cloud)

**Verify**:
```bash
# Use dig (more common than nslookup)
dig your-hostname.com +short
# Should return Cloudflare IPs, not cfargotunnel.com

# Or test HTTP directly
curl -sI https://your-hostname.com | head -5
```

</details>

<details>
<summary><strong>x509: certificate signed by unknown authority</strong></summary>

**Cause**: Origin has self-signed certificate

**Fix**: Add to ingress config:
```yaml
originRequest:
  noTLSVerify: true
```

</details>

<details>
<summary><strong>Tunnel connects but origin unreachable</strong></summary>

**Checklist**:
1. Verify local service: `curl http://localhost:PORT`
2. Check firewall allows localhost
3. Confirm correct port in ingress config
4. Check service is running: `systemctl status your-service`

</details>

<details>
<summary><strong>Connection timeout during uploads/streaming</strong></summary>

**Cause**: Default timeouts too short

**Fix**: Increase timeouts in originRequest:
```yaml
originRequest:
  connectTimeout: 120s
  tlsTimeout: 60s
  keepAliveTimeout: 180s
```

</details>

<details>
<summary><strong>Systemd service won't start</strong></summary>

**Cause**: Permission issues on credentials

**Fix**:
```bash
# Check permissions
ls -la /etc/cloudflared/tunnel-credentials.json

# Should be 600, owned by root
sudo chmod 600 /etc/cloudflared/tunnel-credentials.json
sudo chown root:root /etc/cloudflared/tunnel-credentials.json

# Restart
sudo systemctl restart cloudflared-your-tunnel
```

</details>

<details>
<summary><strong>Tunnel token retrieval fails</strong></summary>

**Cause**: Tunnel not fully initialized

**Fix**: Wait 2-3 seconds after tunnel creation before getting token:
```bash
sleep 3
# Then get token
```

</details>

---

## Setup Steps

### Step 1: Install cloudflared

**Auto-detect architecture** (recommended):
```bash
# Detect architecture and download correct binary
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  BINARY="cloudflared-linux-arm64"
elif [ "$ARCH" = "x86_64" ]; then
  BINARY="cloudflared-linux-amd64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/$BINARY" -o cloudflared
sudo mv cloudflared /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
cloudflared --version
```

<details>
<summary><strong>Manual architecture selection</strong></summary>

If you know your architecture, use the direct URL:

```bash
# ARM64 (Oracle Cloud, Hetzner CAX, Raspberry Pi)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared

# AMD64 (Hetzner CX/CPX, most x86 servers)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared

sudo mv cloudflared /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

</details>

### Step 2: Create tunnel via API

```bash
TUNNEL_RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$TUNNEL_NAME\",\"config_src\":\"cloudflare\"}")

TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Tunnel ID: $TUNNEL_ID"
```

### Step 3: Get Zone ID

```bash
TUNNEL_DOMAIN=$(echo "$TUNNEL_HOSTNAME" | rev | cut -d'.' -f1-2 | rev)

ZONE_ID=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones?name=$TUNNEL_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
```

### Step 4: Create DNS CNAME

**Option A: Single hostname** (for KASM or single services)
```bash
HOSTNAME_PART=$(echo "$TUNNEL_HOSTNAME" | cut -d'.' -f1)

curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"CNAME\",
    \"name\":\"$HOSTNAME_PART\",
    \"content\":\"$TUNNEL_ID.cfargotunnel.com\",
    \"proxied\":true
  }"
```

**Option B: Wildcard** (recommended for Coolify - enables all subdomains)
```bash
# Extract base domain: coolify.example.com → example.com
BASE_DOMAIN=$(echo "$TUNNEL_HOSTNAME" | sed 's/^[^.]*\.//')

# Create wildcard DNS record: *.example.com
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"CNAME\",
    \"name\":\"*.$BASE_DOMAIN\",
    \"content\":\"$TUNNEL_ID.cfargotunnel.com\",
    \"proxied\":true
  }"
```

**Note**: Wildcard mode means `coolify.example.com`, `app1.example.com`, `anything.example.com` all route through the tunnel automatically.

### Step 5: Configure ingress rules

**Option A: Single hostname** (matches Step 4 Option A)
```bash
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {"hostname": "'$TUNNEL_HOSTNAME'", "service": "'$SERVICE_PROTOCOL://$SERVICE_IP:$SERVICE_PORT'"},
        {"service": "http_status:404"}
      ]
    }
  }'
```

**Option B: Wildcard + Coolify UI ingress** (matches Step 4 Option B - for Coolify)

> **CRITICAL**: Coolify requires TWO routes - one for the UI (port 8000) and one for deployed apps (port 443). Routes are processed in order - most specific first!

```bash
# BASE_DOMAIN should be set from Step 4
# COOLIFY_HOSTNAME is the Coolify UI hostname (e.g., coolify.example.com)

curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {
          "hostname": "'$COOLIFY_HOSTNAME'",
          "service": "http://localhost:8000"
        },
        {
          "hostname": "*.'$BASE_DOMAIN'",
          "service": "https://localhost:443",
          "originRequest": {
            "noTLSVerify": true,
            "connectTimeout": 30,
            "originServerName": "'$BASE_DOMAIN'"
          }
        },
        {"service": "http_status:404"}
      ]
    }
  }'
```

> **IMPORTANT - Route Order**:
> 1. **Coolify UI** (`coolify.domain.com` → `http://localhost:8000`) - MUST be first
> 2. **Deployed Apps** (`*.domain.com` → `https://localhost:443`) - Traefik handles routing
> 3. **Catchall** (`http_status:404`) - Required fallback

> **Why two routes?**
> - Coolify UI runs on port **8000** (HTTP) - NOT through Traefik
> - Deployed apps go through Traefik on port **443** (HTTPS)
> - Without the explicit Coolify route, accessing `coolify.domain.com` returns 503

> **IMPORTANT - API vs config.yml format**:
> - **API format**: Timeout values must be **integers** (seconds): `"connectTimeout": 30`
> - **config.yml format**: Can use **strings** with units: `connectTimeout: 30s`
> - Do NOT use strings like `"30s"` in API calls - they will fail with "is not an integer" error

> **TLS Settings for HTTPS origins**:
> - `noTLSVerify: true` - Required for self-signed or Cloudflare Origin certificates
> - `originServerName` - Sets SNI hostname for TLS handshake (use base domain for wildcard routes)

**Port mapping reference**:
| Service | Port | Protocol | Route |
|---------|------|----------|-------|
| Coolify UI | 8000 | HTTP | `coolify.domain.com` |
| Traefik (deployed apps) | 443 | HTTPS | `*.domain.com` |

**API Response Handling**: Cloudflare API returns JSON with `success` field. To verify:
```bash
# Add to end of curl command to show clear success/failure:
| jq '{success: .success, errors: .errors}'
```
A response of `{"success":true,"errors":[]}` indicates success.

### Step 6: Get tunnel token

```bash
TUNNEL_TOKEN=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"result":"[^"]*"' | cut -d'"' -f4)
```

### Step 7: Generate config.yml

**Option A: Single hostname**
```bash
cat > config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/tunnel-credentials.json

ingress:
  - hostname: $TUNNEL_HOSTNAME
    service: $SERVICE_PROTOCOL://$SERVICE_IP:$SERVICE_PORT
    originRequest:
      noTLSVerify: true  # Remove if not using self-signed certs
      connectTimeout: 30s
      keepAliveTimeout: 90s
  - service: http_status:404
EOF
```

**Option B: Wildcard + Coolify UI** (for Coolify)

> **CRITICAL**: Coolify requires TWO routes - one for the UI (port 8000) and one for deployed apps (port 443). Routes are processed in order - most specific first!

```bash
cat > config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/tunnel-credentials.json

ingress:
  # Route 1: Coolify UI (MUST be first - specific hostname)
  - hostname: $COOLIFY_HOSTNAME
    service: http://localhost:8000
    originRequest:
      connectTimeout: 30s
      keepAliveTimeout: 90s

  # Route 2: Deployed apps via Traefik (wildcard)
  - hostname: "*.$BASE_DOMAIN"
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
      tlsTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveConnections: 10
      keepAliveTimeout: 90s
      originServerName: $BASE_DOMAIN

  # Route 3: Catchall (required)
  - service: http_status:404
EOF
```

> **Route Order Matters**:
> 1. **Coolify UI** (`coolify.domain.com` → `http://localhost:8000`) - MUST be first
> 2. **Deployed Apps** (`*.domain.com` → `https://localhost:443`) - Traefik handles routing
> 3. **Catchall** (`http_status:404`) - Required fallback

> **Why two routes?**
> - Coolify UI runs on port **8000** (HTTP) - NOT through Traefik
> - Deployed apps go through Traefik on port **443** (HTTPS)
> - Without the explicit Coolify route, accessing `coolify.domain.com` returns 503

> **Variables required**:
> - `COOLIFY_HOSTNAME` - Coolify UI hostname (e.g., `coolify.example.com`)
> - `BASE_DOMAIN` - Base domain for apps (e.g., `example.com`)

### Step 8: Deploy to server

**Install cloudflared with auto-detection** (recommended):
```bash
# Auto-detect architecture on remote server and install cloudflared
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP '
  ARCH=$(uname -m)
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    BINARY="cloudflared-linux-arm64"
  elif [ "$ARCH" = "x86_64" ]; then
    BINARY="cloudflared-linux-amd64"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
  echo "Detected architecture: $ARCH -> downloading $BINARY"
  curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/$BINARY" -o /tmp/cloudflared
  sudo mv /tmp/cloudflared /usr/local/bin/
  sudo chmod +x /usr/local/bin/cloudflared
  cloudflared --version
'

# Create directories
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'sudo mkdir -p /etc/cloudflared'

# Copy config
scp -i $SSH_KEY_PATH config.yml $SSH_USER@$SERVER_IP:/tmp/
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'sudo mv /tmp/config.yml /etc/cloudflared/'

# Create credentials from token
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "echo '$TUNNEL_TOKEN' | sudo tee /etc/cloudflared/tunnel-credentials.json > /dev/null && sudo chmod 600 /etc/cloudflared/tunnel-credentials.json"
```

<details>
<summary><strong>If using SERVER_ARCH from .env.local</strong></summary>

If the infrastructure skill set `SERVER_ARCH` in `.env.local`, you can use it directly:

```bash
# Using SERVER_ARCH variable (set by oci-infrastructure or hetzner-infrastructure)
BINARY="cloudflared-linux-${SERVER_ARCH:-arm64}"
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/$BINARY -o /tmp/cloudflared && sudo mv /tmp/cloudflared /usr/local/bin/ && sudo chmod +x /usr/local/bin/cloudflared"
```

</details>

### Step 9: Create systemd service

**Option A: Config file method** (recommended if config.yml was created in Step 7):
```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'cat > /tmp/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/cloudflared.service /etc/systemd/system/'
```

**Option B: Token method** (if using managed tunnel without config.yml):
```bash
# Embed token directly - shell substitution doesn't work in systemd
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "cat > /tmp/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/cloudflared.service /etc/systemd/system/"
```

> **Warning**: Do NOT use `$(cat ...)` in systemd ExecStart - systemd doesn't execute shell commands. Embed the token directly as shown above.

### Step 10: Start service

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'sudo systemctl daemon-reload && sudo systemctl enable cloudflared && sudo systemctl start cloudflared'

# Verify
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'sudo systemctl status cloudflared'
```

---

## API Token Permissions

Required permissions:
- `Account.Cloudflare Tunnel:Edit`
- `Zone.DNS:Edit`

<details>
<summary><strong>How to create API token</strong></summary>

1. Go to: Cloudflare Dashboard → Profile → API Tokens
2. Click "Create Token"
3. Use "Custom token" template
4. Add permissions:
   - Account → Cloudflare Tunnel → Edit
   - Zone → DNS → Edit
5. Set Zone Resources to your domain
6. Create and copy token

</details>

---

## Verification Checklist

- [ ] cloudflared installed (`cloudflared --version`)
- [ ] Tunnel created (TUNNEL_ID saved)
- [ ] DNS CNAME proxied (orange cloud)
- [ ] Ingress rules configured
- [ ] Token retrieved
- [ ] Service deployed and running
- [ ] DNS resolves (`dig hostname +short` or `curl -sI https://hostname`)
- [ ] Service accessible (`curl https://hostname`)

---

## References

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Tunnel API Reference](https://developers.cloudflare.com/api/operations/cloudflare-tunnel-list-cloudflare-tunnels)
- [cloudflared GitHub](https://github.com/cloudflare/cloudflared)
- [Configuration Reference](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/configuration-file/)
