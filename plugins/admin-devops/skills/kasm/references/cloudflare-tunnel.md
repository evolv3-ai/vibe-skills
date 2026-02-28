# Cloudflare Tunnel for KASM

Secure HTTPS access to KASM Workspaces via Cloudflare Tunnel.

## Contents
- Prerequisites
- Quick Setup
- Troubleshooting
- References

---

## Prerequisites

```bash
# Required environment variables
CLOUDFLARE_API_TOKEN=your_api_token      # Needs: Tunnel:Edit, DNS:Edit
CLOUDFLARE_ACCOUNT_ID=your_account_id
TUNNEL_NAME=kasm-tunnel
TUNNEL_HOSTNAME=kasm.yourdomain.com
KASM_SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa
```

---

## Quick Setup

### Step 1: Create Tunnel

```bash
TUNNEL_RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$TUNNEL_NAME\",\"config_src\":\"cloudflare\"}")

TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Tunnel ID: $TUNNEL_ID"
```

### Step 2: Create DNS Record

```bash
TUNNEL_DOMAIN=$(echo "$TUNNEL_HOSTNAME" | rev | cut -d'.' -f1-2 | rev)
HOSTNAME_PART=$(echo "$TUNNEL_HOSTNAME" | cut -d'.' -f1)

ZONE_ID=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones?name=$TUNNEL_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

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

### Step 3: Configure Ingress (KASM-specific)

> **CRITICAL**: KASM uses self-signed certificates. Must use `noTLSVerify: true`.

```bash
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {
          "hostname": "'$TUNNEL_HOSTNAME'",
          "service": "https://localhost:443",
          "originRequest": {
            "noTLSVerify": true,
            "connectTimeout": 30,
            "tlsTimeout": 30,
            "keepAliveTimeout": 90
          }
        },
        {"service": "http_status:404"}
      ]
    }
  }'
```

### Step 4: Get Token & Deploy

```bash
# Get tunnel token
TUNNEL_TOKEN=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"result":"[^"]*"' | cut -d'"' -f4)

# Install cloudflared on server
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP '
  ARCH=$(uname -m)
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    BINARY="cloudflared-linux-arm64"
  else
    BINARY="cloudflared-linux-amd64"
  fi
  curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/$BINARY" -o /tmp/cloudflared
  sudo mv /tmp/cloudflared /usr/local/bin/
  sudo chmod +x /usr/local/bin/cloudflared
'

# Create systemd service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "cat > /tmp/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel for KASM
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

# Start service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP 'sudo systemctl daemon-reload && sudo systemctl enable cloudflared && sudo systemctl start cloudflared'
```

### Step 5: Verify

```bash
# Check service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP 'sudo systemctl status cloudflared'

# Test access
curl -I https://$TUNNEL_HOSTNAME
```

---

## Troubleshooting

### x509: certificate signed by unknown authority

**Cause**: Missing `noTLSVerify: true` in ingress config.

**Fix**: Update tunnel configuration via API or Cloudflare Dashboard → Zero Trust → Tunnels → Edit → Public Hostname → TLS settings → Enable "No TLS Verify".

### Black screen / WebSocket errors

**Cause**: Session ports (3000-4000) blocked or timeout too short.

**Fix**: Increase timeouts in ingress:
```yaml
originRequest:
  noTLSVerify: true
  connectTimeout: 120
  keepAliveTimeout: 180
```

### DNS_PROBE_FINISHED_NXDOMAIN

**Cause**: DNS CNAME not proxied (gray cloud instead of orange).

**Fix**: Update DNS record to `proxied: true` or enable in Cloudflare Dashboard.

---

## References

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared GitHub](https://github.com/cloudflare/cloudflared)
