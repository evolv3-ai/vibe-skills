# Networking & Access

## Cloudflare Tunnel (Production-Tested)

Expose KASM securely without opening ports.

### Prerequisites

- Cloudflare account with a domain
- `cloudflared` installed on the KASM server
- Cloudflare Tunnel created

### Tunnel Configuration

Create or update the tunnel config (`~/.cloudflared/config.yml` or `/etc/cloudflared/config.yml`):

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: kasm.yourdomain.com
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```

**Critical**: `noTLSVerify: true` is required because KASM uses a self-signed certificate internally.

### KASM Zone Configuration

After setting up the tunnel:

1. Log into KASM Admin UI
2. Go to Infrastructure > Zones
3. Edit the default zone
4. Set **Upstream Auth Address**: `kasm.yourdomain.com` (your tunnel hostname)
5. Set **Proxy Port**: `0` (auto-detect)
6. Save

Changes apply to NEW sessions only. Existing sessions keep old settings.

### Start Tunnel

```bash
# As a service
sudo cloudflared service install
sudo systemctl start cloudflared

# Or manually (for testing)
cloudflared tunnel run <TUNNEL_NAME>
```

### Verify

1. Access `https://kasm.yourdomain.com`
2. Should see KASM login page (no certificate warnings)
3. Login and launch a workspace to verify streaming works

---

## Reverse Proxy (Nginx)

### Basic Configuration

```nginx
upstream kasm_backend {
    server 127.0.0.1:443;
}

server {
    listen 443 ssl;
    server_name kasm.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass https://kasm_backend;
        proxy_http_version 1.1;

        # WebSocket support (required for desktop streaming)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

WebSocket upgrade headers are mandatory - without them desktop streaming will not work.

### After Reverse Proxy Setup

Update KASM zone settings:
1. Infrastructure > Zones > Edit default zone
2. **Upstream Auth Address**: Set to server IP or FQDN (or "proxy")
3. **Proxy Port**: `0` (auto-detect from browser)

---

## Zone Configuration

Zones control how KASM routes traffic to agents.

### Access

Admin UI > Infrastructure > Zones > Edit

### Key Settings

| Setting | Purpose | Default |
|---------|---------|---------|
| Upstream Auth Address | Where to authenticate users | Server IP |
| Proxy Port | Port for session traffic | 443 |

### Single-Server Setup

- Upstream Auth Address: Server IP or "proxy"
- Proxy Port: 0 (auto-detect)

### Multi-Server Setup

- Upstream Auth Address: IP/FQDN of the Web App role server
- Proxy Port: 0 (auto-detect)

### Important Notes

- Zone changes apply to NEW sessions only
- Existing sessions continue with old zone settings
- After changing zone settings, users should end current sessions and start new ones

---

## Direct Access (Development)

For development/testing without a reverse proxy or tunnel:

1. Access `https://<SERVER_IP>`
2. Accept the self-signed certificate warning
3. Login normally

**Security note**: Do not expose port 8443 or 443 to the public internet without proper HTTPS. The self-signed cert provides encryption but not identity verification.

---

## Firewall Configuration

### Minimum Required Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 443 | TCP | KASM web UI and session traffic |
| 22 | TCP | SSH (management) |

### If Using Cloudflare Tunnel

No inbound ports needed - tunnel handles all traffic.

### If Using Direct Access

```bash
# UFW example
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # KASM
sudo ufw enable
```
