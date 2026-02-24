# Cloudflare Error 1033 - Troubleshooting Guide

**Issue Date**: 2025-11-15 (example)
**Server IP**: <SERVER_IP>
**Domain**: <COOLIFY_DOMAIN>
**Error**: Cloudflare Error 1033 (Argo Tunnel Error)

## Contents
- Problem Summary
- Root Cause Analysis
- Solutions
- Recommended Action Plan
- Diagnostic Commands
- Current Status
- Quick Reference
- Next Steps
- Related Documentation

---

## Problem Summary

When accessing Coolify via domain name `<COOLIFY_DOMAIN>`, users encounter **Cloudflare Error 1033**. However, direct IP access (http://<SERVER_IP>:8000) works correctly.

## Root Cause Analysis

### What We Found

1. **Domain Configuration**
   - Domain `<COOLIFY_DOMAIN>` is configured in Coolify
   - Traefik logs show ACME certificate requests for this domain
   - Coolify redirects to this domain when accessed

2. **Cloudflare Status**
   - Domain DNS likely proxied through Cloudflare (orange cloud)
   - DNS points to Cloudflare's edge network
   - **NO Cloudflare Tunnel configured on the server**

3. **Server Status**
   - ✅ Coolify running normally (all 6 containers healthy)
   - ✅ Direct IP access works (HTTP 302 → /login)
   - ✅ OCI firewall allows ports 8000, 80, 443
   - ❌ No cloudflared process running
   - ❌ No tunnel connecting Cloudflare to origin server

### Error 1033 Explanation

**Cloudflare Error 1033** occurs when:
- A domain is proxied through Cloudflare (DNS orange cloud)
- The domain is configured to use an Argo Tunnel
- But the tunnel is not active or cannot connect to the origin

In this case:
```
User → Cloudflare Edge → [TUNNEL MISSING] ← Origin Server (<SERVER_IP>)
```

Cloudflare cannot reach the origin because there's no tunnel configured.

---

## Solutions

### Solution 1: Access via IP Address (Quick Fix)

**Recommended for initial setup and testing**

**URL**: http://<SERVER_IP>:8000

**Pros**:
- Works immediately
- No additional configuration needed
- Good for testing and initial setup

**Cons**:
- No HTTPS (insecure for production)
- Exposes public IP
- No custom domain

**Status**: ✅ WORKING

---

### Solution 2: Configure Cloudflare Tunnel (Recommended for Production)

**Setup Cloudflare Tunnel to connect Cloudflare → Your Server**

#### Prerequisites
- Cloudflare account with domain access
- Cloudflare API token (from user's selection: `y^48ZTz3ZJ8J`)

#### Installation Steps

**Step 1: Install cloudflared on the server**

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP>

# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb

# Verify installation
cloudflared --version
```

**Step 2: Authenticate with Cloudflare**

```bash
# Login to Cloudflare (opens browser)
cloudflared tunnel login
```

**Step 3: Create and configure tunnel**

```bash
# Create tunnel
cloudflared tunnel create coolify-tunnel

# Note the Tunnel ID from output

# Create config file
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: <TUNNEL-ID>
credentials-file: /home/ubuntu/.cloudflared/<TUNNEL-ID>.json

ingress:
  - hostname: <COOLIFY_DOMAIN>
    service: http://localhost:8000
  - service: http_status:404
EOF
```

**Step 4: Configure DNS**

```bash
# Route DNS to tunnel
cloudflared tunnel route dns coolify-tunnel <COOLIFY_DOMAIN>
```

**Step 5: Start tunnel as service**

```bash
# Install as system service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

**Verification**:
- Access https://<COOLIFY_DOMAIN>
- Should now work without Error 1033

---

### Solution 3: Use Direct DNS (No Cloudflare Proxy)

**Point DNS directly to server IP (bypass Cloudflare)**

#### Steps

1. **In Cloudflare DNS Settings**:
   - Change DNS record for `<COOLIFY_DOMAIN>`
   - Type: A
   - Name: coolify
   - Content: <SERVER_IP>
   - **Proxy status: DNS only (grey cloud)** ← This is the key change

2. **Wait for DNS propagation** (5-10 minutes)

3. **Access**: http://<COOLIFY_DOMAIN>:8000

**Pros**:
- Simple configuration
- No tunnel needed
- Direct connection

**Cons**:
- Exposes server IP publicly
- No Cloudflare protection (DDoS, WAF)
- Still needs HTTPS setup (Let's Encrypt)

---

### Solution 4: Remove Domain from Coolify (Use IP Only)

**Reconfigure Coolify to use IP instead of domain**

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP>

# Update Coolify configuration
sudo sed -i 's|APP_URL=.*|APP_URL=http://<SERVER_IP>:8000|' /data/coolify/source/.env

# Restart Coolify
cd /data/coolify/source
sudo docker compose restart
```

**Pros**:
- Removes domain dependency
- Works immediately

**Cons**:
- No custom domain
- IP-based access only

---

## Recommended Action Plan

### For Development/Testing:
1. ✅ Use **Solution 1** (IP access) for now
2. Complete initial Coolify setup
3. Deploy first application

### For Production:
1. ✅ Use **Solution 2** (Cloudflare Tunnel)
2. Provides HTTPS + custom domain + Cloudflare protection
3. Most secure and feature-complete option

---

## Diagnostic Commands

**Check if Coolify is accessible via IP**:
```bash
curl -I http://<SERVER_IP>:8000
# Should return: HTTP/1.1 302 Found
```

**Check Coolify container status**:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP> 'sudo docker ps --filter "name=coolify"'
```

**Check for cloudflared**:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP> 'systemctl status cloudflared'
```

**Check Traefik logs**:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP> 'sudo docker logs coolify-proxy --tail 50'
```

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Coolify Containers | ✅ Running | All 6 containers healthy |
| Direct IP Access | ✅ Working | http://<SERVER_IP>:8000 |
| Domain Access | ❌ Error 1033 | <COOLIFY_DOMAIN> |
| Cloudflare Tunnel | ❌ Not Configured | No cloudflared installed |
| OCI Firewall | ✅ Configured | Ports 22, 80, 443, 8000, 6001, 6002 |
| UFW Firewall | ⚠️ Inactive | Consider enabling for additional security |

---

## Quick Reference

**Working Access URL**: http://<SERVER_IP>:8000

**SSH Access**:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP>
```

**Cloudflare API Token** (from user selection):
```
y^48ZTz3ZJ8J
```

---

## Next Steps

1. ✅ **Immediate**: Access Coolify via http://<SERVER_IP>:8000
2. ⏳ **Short-term**: Complete initial setup using IP access
3. 🔄 **Long-term**: Implement Solution 2 (Cloudflare Tunnel) for production

---

## Related Documentation

- [Cloudflare Tunnel Setup Script](.claude/skills/coolify/scripts/coolify-cloudflare-tunnel-setup.sh)
- [Coolify Installation Guide](.claude/skills/coolify/SKILL.md)
- [OCI Infrastructure Details](.claude/skills/oci/scripts/.env)

---

**Document Created**: 2025-11-15
**Last Updated**: 2025-11-15
**Issue Status**: ✅ DIAGNOSED - Solutions provided
