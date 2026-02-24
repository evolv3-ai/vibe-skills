# Cloudflare Origin Certificates

**Status**: Production Ready | **Validity**: 15 years | **Cost**: Free

## Contents
- Problem Solved
- Prerequisites
- When You Need This
- Setup Methods
- Method A: Automated Setup (API with Global Key)
- Method B: Manual Setup (Dashboard)
- Service Configuration
- Cloudflare SSL Modes
- Troubleshooting
- Certificate Details
- Security
- References

---

## Problem Solved

```
Without Origin Certs:  User → HTTPS → Cloudflare → HTTP → Origin ❌
With Origin Certs:     User → HTTPS → Cloudflare → HTTPS → Origin ✅
```

**Result**: OAuth callbacks work, webhooks accepted, end-to-end encryption.

---

## Prerequisites

Before starting, ensure you have:

1. **Cloudflare Account** with a domain added
2. **Authentication** - one of:
   - **Global API Key** (required for automated certificate generation via API)
   - **API Token** with `Zone:SSL and Certificates:Edit` + `Zone:Settings:Edit` (for zone settings only)
3. **Zone ID** (from Cloudflare dashboard)
4. **Server access** (SSH) if deploying remotely

> **IMPORTANT - Origin CA Authentication**: The Origin CA API (`/certificates` endpoint) requires **Global API Key** authentication, NOT a bearer API token. Regular API tokens will fail with error code `10001: Unable to authenticate request`.
>
> **To get your Global API Key**:
> 1. Go to: https://dash.cloudflare.com/profile/api-tokens
> 2. Scroll to **Global API Key** section
> 3. Click **View** and copy the key
> 4. Use this as `CLOUDFLARE_GLOBAL_API_KEY`

Required configuration (save to `.env.local` or have ready):

```bash
# Cloudflare credentials
CLOUDFLARE_GLOBAL_API_KEY=your_global_api_key  # Required for API method
CLOUDFLARE_API_TOKEN=your_api_token            # For zone settings (optional)
CLOUDFLARE_ZONE_ID=your_zone_id
CLOUDFLARE_EMAIL=your_email@example.com

# Certificate config
CERT_HOSTNAME=yourdomain.com
CERT_ADDITIONAL_HOSTNAMES="*.yourdomain.com"  # Optional

# Server connection
SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa
```

---

## When You Need This

| Scenario | Origin Cert Required? |
|----------|----------------------|
| n8n with Google OAuth | ✅ Yes |
| GitHub/GitLab webhooks | ✅ Yes |
| Apps generating callback URLs | ✅ Yes |
| JWT token issuers | ✅ Yes |
| Simple static sites | ❌ No |
| Internal tools (no OAuth) | ❌ No |

---

## Setup Methods

| Method | Recommended? | When to Use |
|--------|-------------|-------------|
| **Method B: Manual (Dashboard)** | ✅ **Recommended** | Simple, no API key needed, copy/paste from dashboard |
| **Method A: Automated (API)** | Optional | You already have Global API Key and prefer automation |

> **Why Manual is Recommended**: The dashboard method is simpler, more reliable, and doesn't require exposing your Global API Key. Generate the certificate in Cloudflare's dashboard, copy the cert and key, then let the agent deploy them to your server.

---

## Method A: Automated Setup (API with Global Key) - Optional

> **Use Method B (Manual) unless you specifically need automation.**
>
> **Requires**: Cloudflare **Global API Key** (NOT a regular API token)
>
> The Origin CA API uses legacy authentication. If you see error `10001: Unable to authenticate request`, you're using the wrong credential type - switch to Method B instead.

### Step 0: Verify Global API Key Works

```bash
# Test Global API Key authentication
AUTH_TEST=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY")

# Check for success
if echo "$AUTH_TEST" | grep -q '"success":true'; then
  echo "✅ Global API Key authentication successful"
else
  echo "❌ Authentication failed - check your Global API Key"
  echo "$AUTH_TEST"
  echo ""
  echo "If you see error 10001, use Method B (Manual Dashboard) instead"
  exit 1
fi
```

### Step 1: Generate Origin Certificate

```bash
# Build hostnames JSON array
HOSTNAMES="\"$CERT_HOSTNAME\""
if [ -n "$CERT_ADDITIONAL_HOSTNAMES" ]; then
  HOSTNAMES="$HOSTNAMES,\"$CERT_ADDITIONAL_HOSTNAMES\""
fi

# Generate certificate via API (uses Global API Key)
CERT_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/certificates" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY" \
  -H "Content-Type: application/json" \
  --data "{
    \"hostnames\": [$HOSTNAMES],
    \"requested_validity\": 5475,
    \"request_type\": \"origin-rsa\",
    \"csr\": \"\"
  }")

# Check for authentication error
if echo "$CERT_RESPONSE" | grep -q '"code":10001'; then
  echo "❌ Authentication failed (error 10001)"
  echo "The Origin CA API requires Global API Key, not API Token"
  echo "Use Method B (Manual Dashboard) instead, or get your Global API Key from:"
  echo "https://dash.cloudflare.com/profile/api-tokens → Global API Key section"
  exit 1
fi

# Extract certificate and private key
CERTIFICATE=$(echo "$CERT_RESPONSE" | grep -o '"certificate":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
PRIVATE_KEY=$(echo "$CERT_RESPONSE" | grep -o '"private_key":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
CERT_ID=$(echo "$CERT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

echo "Certificate ID: $CERT_ID"
```

### Step 2: Save Certificate Files

```bash
# Generate safe filename
CERT_FILENAME=$(echo "$CERT_HOSTNAME" | sed 's/\./_/g' | sed 's/\*//g')

# Save to local files
echo "$CERTIFICATE" > ${CERT_FILENAME}.cert
echo "$PRIVATE_KEY" > ${CERT_FILENAME}.key

# Set permissions
chmod 644 ${CERT_FILENAME}.cert
chmod 600 ${CERT_FILENAME}.key
```

### Step 3: Deploy to Server

```bash
# Upload certificate files
scp -i $SSH_KEY_PATH ${CERT_FILENAME}.cert $SSH_USER@$SERVER_IP:/tmp/
scp -i $SSH_KEY_PATH ${CERT_FILENAME}.key $SSH_USER@$SERVER_IP:/tmp/

# Install on server (for Coolify)
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "
  sudo mkdir -p /data/coolify/proxy/certs
  sudo mv /tmp/${CERT_FILENAME}.cert /data/coolify/proxy/certs/
  sudo mv /tmp/${CERT_FILENAME}.key /data/coolify/proxy/certs/
  sudo chmod 644 /data/coolify/proxy/certs/${CERT_FILENAME}.cert
  sudo chmod 600 /data/coolify/proxy/certs/${CERT_FILENAME}.key
"
```

### Step 4: Configure Traefik (Coolify)

Create the dynamic configuration file for Traefik to load the certificate:

```bash
# Create dynamic config directory if it doesn't exist
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "sudo mkdir -p /data/coolify/proxy/dynamic"

# Create Traefik TLS configuration
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "sudo tee /data/coolify/proxy/dynamic/cloudflare-origin-certs.yaml > /dev/null << 'EOF'
tls:
  certificates:
    - certFile: /traefik/certs/${CERT_FILENAME}.cert
      keyFile: /traefik/certs/${CERT_FILENAME}.key
EOF"

# Set permissions
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "sudo chmod 644 /data/coolify/proxy/dynamic/cloudflare-origin-certs.yaml"

# Traefik auto-detects files in /data/coolify/proxy/dynamic/ - no restart needed
```

**Note**: Traefik watches the `/data/coolify/proxy/dynamic/` directory and automatically loads new configuration files.

### Step 5: Update Cloudflare SSL Settings

> **Note**: Zone settings can use either Global API Key OR an API token with `Zone:Settings:Edit` permission.

**Option A - Using Global API Key** (same as certificate generation):
```bash
# Set SSL mode to Full (Strict)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{"value":"strict"}'

# Enable Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/always_use_https" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'
```

**Option B - Using API Token** (if you have `Zone:Settings:Edit` permission):
```bash
# Set SSL mode to Full (Strict)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"strict"}'

# Enable Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/always_use_https" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'
```

**Option C - Manual via Dashboard** (if API fails):
1. Go to: **SSL/TLS → Overview**
2. Set SSL/TLS encryption mode to: **Full (strict)**
3. Go to: **SSL/TLS → Edge Certificates**
4. Enable: **Always Use HTTPS**

### Step 6: Configure Cloudflare Tunnel TLS Settings (if using tunnel)

> **IMPORTANT**: If using Cloudflare Tunnel with origin certificates, you MUST configure these settings in the tunnel's ingress rules.

**Via API** (when configuring tunnel ingress):
```bash
# Update tunnel configuration with TLS settings
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {
          "hostname": "*.'$BASE_DOMAIN'",
          "service": "https://localhost:443",
          "originRequest": {
            "noTLSVerify": true,
            "originServerName": "'$BASE_DOMAIN'"
          }
        },
        {"service": "http_status:404"}
      ]
    }
  }'
```

**Via Cloudflare Dashboard**:
1. Go to **Zero Trust → Networks → Tunnels**
2. Select your tunnel → **Edit**
3. Go to **Public Hostname** tab
4. Edit the route for `*.yourdomain.com`
5. Under **Additional application settings → TLS**:
   - Set **TLS Origin Server Name**: `yourdomain.com`
   - Enable **No TLS Verify**: `true`
6. Save

**Why these settings are required**:
- `originServerName`: Tells the tunnel which hostname to use for SNI (Server Name Indication) when connecting to origin
- `noTLSVerify`: Origin certificates are signed by Cloudflare CA, not a public CA. The tunnel must skip verification.

### Step 7: Verify

```bash
# Test HTTPS
curl -I https://$CERT_HOSTNAME
```

### Step 8: Optional - Optimize for HTTPS-Only

> **Optional but recommended**: Since you're using Origin Certificates, you no longer need HTTP routes or Let's Encrypt challenges.

#### 8.1 Remove HTTP Route from Cloudflare Tunnel

The tunnel no longer needs to route HTTP traffic. Update the tunnel configuration to HTTPS only:

```bash
# Update tunnel to HTTPS-only (removes http://localhost:80 route)
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
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

**Or via Cloudflare Dashboard**:
1. Go to **Zero Trust → Networks → Tunnels**
2. Select your tunnel → **Edit** → **Public Hostname**
3. Delete any route with `http://localhost:80`
4. Keep only the `https://localhost:443` route

#### 8.2 Update Coolify's Traefik Configuration

Update Traefik to remove unnecessary HTTP settings:

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "sudo tee /data/coolify/proxy/docker-compose.yml > /dev/null << 'COMPOSE_EOF'
networks:
  coolify:
    external: true

services:
  traefik:
    container_name: coolify-proxy
    image: 'traefik:v3.1'
    restart: unless-stopped
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    networks:
      - coolify
    ports:
      - '443:443'
    healthcheck:
      test: 'wget -qO- http://localhost:80/ping || exit 1'
      interval: 4s
      timeout: 2s
      retries: 5
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:ro'
      - '/data/coolify/proxy:/traefik'
    command:
      - '--ping=true'
      - '--ping.entrypoint=http'
      - '--entrypoints.http.address=:80'
      - '--entrypoints.https.address=:443'
      - '--entrypoints.http.http.encodequerysemicolons=true'
      - '--entryPoints.http.http2.maxConcurrentStreams=50'
      - '--entrypoints.https.http.encodequerysemicolons=true'
      - '--entryPoints.https.http2.maxConcurrentStreams=50'
      - '--entrypoints.https.http3'
      - '--providers.docker.exposedbydefault=false'
      - '--providers.file.directory=/traefik/dynamic/'
      - '--certificatesresolvers.letsencrypt.acme.httpchallenge=false'
      - '--providers.file.watch=true'
      - '--providers.docker=true'
    labels:
      - coolify.managed=true
      - coolify.proxy=true
COMPOSE_EOF"

# Restart Traefik to apply
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "cd /data/coolify/proxy && docker compose up -d --force-recreate"
```

**Key changes from default**:
- Removed port 80 exposure (only 443 exposed)
- Disabled Let's Encrypt HTTP challenge (`httpchallenge=false`)
- Enabled HTTP/3 on HTTPS entrypoint
- Port 80 still exists internally for health checks only

<details>
<summary><strong>Configuring app labels for HTTPS-only</strong></summary>

When deploying apps in Coolify with origin certificates, you may want custom labels:

1. Go to **Projects** → Select your project
2. Open **Configuration** → **General**
3. Check **Readonly labels** option
4. Replace labels with:

```yaml
traefik.enable=true
traefik.http.routers.myapp.entryPoints=https
traefik.http.routers.myapp.rule=Host(`myapp.yourdomain.com`) && PathPrefix(`/`)
traefik.http.routers.myapp.service=myapp
traefik.http.routers.myapp.tls=true
traefik.http.services.myapp.loadbalancer.server.port=80
```

Replace `myapp` with your application name and `myapp.yourdomain.com` with your domain.

</details>

---

## Method B: Manual Setup (Dashboard) - Recommended

> **This is the recommended method.** Simple, reliable, no API key exposure required.

### Step 1: Generate Certificate in Dashboard

1. Go to: https://dash.cloudflare.com → Select your domain
2. Navigate to: **SSL/TLS → Origin Server**
3. Click **Create Certificate**
4. Configure:
   - **Private key type**: RSA (2048)
   - **Hostnames**: Add your domain and `*.yourdomain.com` for wildcard
   - **Certificate validity**: 15 years (recommended)
5. Click **Create**
6. **IMPORTANT**: Copy both the certificate AND private key immediately - the private key is shown only once!

### Step 2: Save Certificate Files Locally

Create two files on your local machine:

**File 1**: `yourdomain_com.cert`
```
-----BEGIN CERTIFICATE-----
[Paste the certificate content here]
-----END CERTIFICATE-----
```

**File 2**: `yourdomain_com.key`
```
-----BEGIN PRIVATE KEY-----
[Paste the private key content here]
-----END PRIVATE KEY-----
```

### Step 3: Ask Agent to Deploy

Tell the agent:
"I have origin certificate files ready. Please help me deploy them to my Coolify server."

Provide:
- Path to `.cert` file
- Path to `.key` file
- Server IP and SSH credentials

The agent will then:
1. Upload files to server
2. Create Traefik dynamic configuration
3. Configure tunnel TLS settings (if applicable)
4. Verify deployment

### Step 4: Agent Deploys Certificates

```bash
# Agent runs these commands:

# Upload certificate files
scp -i $SSH_KEY_PATH yourdomain_com.cert $SSH_USER@$SERVER_IP:/tmp/
scp -i $SSH_KEY_PATH yourdomain_com.key $SSH_USER@$SERVER_IP:/tmp/

# Install on server
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "
  sudo mkdir -p /data/coolify/proxy/certs
  sudo mv /tmp/yourdomain_com.cert /data/coolify/proxy/certs/
  sudo mv /tmp/yourdomain_com.key /data/coolify/proxy/certs/
  sudo chmod 644 /data/coolify/proxy/certs/yourdomain_com.cert
  sudo chmod 600 /data/coolify/proxy/certs/yourdomain_com.key
"

# Create Traefik config
ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP "sudo tee /data/coolify/proxy/dynamic/cloudflare-origin-certs.yaml > /dev/null << 'EOF'
tls:
  certificates:
    - certFile: /traefik/certs/yourdomain_com.cert
      keyFile: /traefik/certs/yourdomain_com.key
EOF"
```

### Step 5: Configure SSL Mode in Dashboard

1. Go to: **SSL/TLS → Overview**
2. Set SSL/TLS encryption mode to: **Full (strict)**
3. Go to: **SSL/TLS → Edge Certificates**
4. Enable: **Always Use HTTPS**

### Step 6: Verify

```bash
curl -I https://yourdomain.com
```

---

## Service Configuration

<details>
<summary><strong>Coolify (recommended)</strong></summary>

The setup steps automatically configure Coolify by:

1. Deploying certificates to `/data/coolify/proxy/certs/`
2. Creating dynamic config at `/data/coolify/proxy/dynamic/cloudflare-origin-certs.yaml`

**Traefik automatically loads the configuration** - no manual steps or restarts needed.

**Manual verification** (if needed):
```bash
# Check certificate files exist
ssh user@server "ls -la /data/coolify/proxy/certs/"

# Check dynamic config exists
ssh user@server "cat /data/coolify/proxy/dynamic/cloudflare-origin-certs.yaml"

# Check Traefik loaded the certificate
ssh user@server "docker logs coolify-proxy 2>&1 | grep -i 'tls\|cert'"
```

</details>

<details>
<summary><strong>Nginx</strong></summary>

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/ssl/cloudflare/yourdomain_com.cert;
    ssl_certificate_key /etc/ssl/cloudflare/yourdomain_com.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:3000;
    }
}
```

</details>

<details>
<summary><strong>Apache</strong></summary>

```apache
<VirtualHost *:443>
    ServerName yourdomain.com

    SSLEngine on
    SSLCertificateFile /etc/ssl/cloudflare/yourdomain_com.cert
    SSLCertificateKeyFile /etc/ssl/cloudflare/yourdomain_com.key

    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
</VirtualHost>
```

</details>

<details>
<summary><strong>Traefik (standalone)</strong></summary>

```yaml
# traefik-dynamic.yml
tls:
  certificates:
    - certFile: /certs/yourdomain_com.cert
      keyFile: /certs/yourdomain_com.key

# In traefik.yml
providers:
  file:
    filename: /etc/traefik/traefik-dynamic.yml
```

</details>

---

## Cloudflare SSL Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Full (Strict)** | Validates certificate | ✅ Production |
| **Full** | Any certificate | Testing only |
| **Flexible** | HTTP to origin | ❌ Never |

The script automatically sets "Full (Strict)" mode.

---

## Troubleshooting

<details>
<summary><strong>Error 526: Invalid SSL Certificate</strong></summary>

**Cause**: Certificate not configured in Traefik/Nginx

**Fixes**:
1. Verify certificate files exist on server
2. Check Traefik dynamic configuration
3. Ensure certificate paths match
4. Restart proxy service

```bash
# Check certificate on server
ssh user@server "ls -la /data/coolify/proxy/certs/"

# Verify certificate content
ssh user@server "openssl x509 -in /data/coolify/proxy/certs/domain_com.cert -text -noout | head -20"
```

</details>

<details>
<summary><strong>OAuth callbacks still failing</strong></summary>

**Checklist**:
1. App sees HTTPS in requests (check logs)
2. Callback URL uses `https://`
3. App's base URL configured as HTTPS
4. "Always Use HTTPS" enabled in Cloudflare

```bash
# Test HTTPS
curl -I https://yourdomain.com

# Check headers app receives
curl -v https://yourdomain.com 2>&1 | grep -i "x-forwarded"
```

</details>

<details>
<summary><strong>Error 10001: Unable to authenticate request</strong></summary>

**Error message**:
```json
{"code": 10001, "message": "Unable to authenticate request"}
```

**Cause**: The Origin CA API requires **Global API Key** authentication, NOT a regular API token (Bearer token).

**Solution**: Use **Method B (Manual Dashboard)** instead - it's the recommended approach anyway.

**If you must use API**:
1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Scroll to **Global API Key** section
3. Click **View** and copy the key
4. Use with `X-Auth-Key` header (not `Authorization: Bearer`)

</details>

<details>
<summary><strong>Certificate generation failed (other errors)</strong></summary>

**Common causes**:
- Using API Token instead of Global API Key (see error 10001 above)
- Wrong zone ID
- Hostname not in zone

**Verify Global API Key works**:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY"
```

</details>

<details>
<summary><strong>Connection refused after setup</strong></summary>

**Cause**: Service not listening on HTTPS port

**Check**:
```bash
# Verify ports
ssh user@server "netstat -tlnp | grep -E '443|8443'"

# Check Traefik logs
ssh user@server "docker logs coolify-proxy 2>&1 | tail -50"
```

</details>

---

## Certificate Details

<details>
<summary><strong>Technical specifications</strong></summary>

| Property | Value |
|----------|-------|
| Validity | 15 years (5475 days) |
| Encryption | RSA 2048-bit |
| Format | PEM |
| Trust | Cloudflare only (not public CAs) |
| Cost | Free (all plans) |
| Wildcards | Supported |

</details>

---

## Security

<details>
<summary><strong>Best practices</strong></summary>

✅ **Always do**:
- Use "Full (Strict)" SSL mode
- Enable "Always Use HTTPS"
- Set key file permissions to 600
- Use wildcard certs for subdomains
- Set minimum TLS 1.2

❌ **Never do**:
- Commit certificates to git
- Use for non-Cloudflare traffic
- Share private keys
- Use "Flexible" SSL mode

</details>

---

## References

- [Cloudflare Origin CA](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)
- [Coolify Origin Cert Guide](https://coolify.io/docs/knowledge-base/cloudflare/origin-cert)
- [Traefik TLS Config](https://doc.traefik.io/traefik/https/tls/)
