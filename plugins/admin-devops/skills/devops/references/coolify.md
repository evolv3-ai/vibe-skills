# Coolify Deployment

_Consolidated from `skills/admin-devops (coolify)` on 2026-02-02_

## Skill Body

# Coolify - Self-Hosted PaaS

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Purpose**: Install and operate Coolify on a single server, then deploy apps via Nixpacks, Dockerfile, or Docker Compose.

## Step 0: Gather Required Information (MANDATORY)

**STOP. Before ANY installation commands, collect ALL parameters from the user.**

Copy this checklist and confirm each item:

```
Required Parameters:
- [ ] COOLIFY_SERVER_IP     - Target server IP address
- [ ] SSH_USER              - SSH username (default: ubuntu)
- [ ] SSH_KEY_PATH          - Path to SSH private key (default: ~/.ssh/id_rsa)
- [ ] COOLIFY_ROOT_USER_EMAIL    - Admin email address
- [ ] COOLIFY_ROOT_USER_PASSWORD - Admin password (see requirements below)
- [ ] COOLIFY_INSTANCE_DOMAIN    - Main Coolify URL (e.g., coolify.example.com)
- [ ] COOLIFY_WILDCARD_DOMAIN    - Base domain for apps (e.g., example.com)

Conditional Parameters (ask user):
- [ ] Using Cloudflare Tunnel for HTTPS? (Y/N)
      If Y: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
- [ ] Need OAuth callbacks or webhooks? (Y/N)
      If Y: Will configure origin certificates
- [ ] Additional SSH public keys to authorize? (optional)
```

### Password Requirements (Coolify enforced)

- Minimum 8 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one number (0-9)
- At least one symbol (!@#$%^&*)

**DO NOT proceed to Step 1 until ALL required parameters are confirmed.**

---

## Step 1: Determine Installation Path

Based on user answers, follow the appropriate workflow:

### Path A: Full Automation (Recommended)
**Use when**: New server, Cloudflare Tunnel for HTTPS, standard setup.

1. Read `references/ENHANCED_SETUP.md`
2. Export all parameters collected in Step 0
3. Run enhanced setup script

### Path B: Manual Installation
**Use when**: Existing server, custom requirements, or debugging.

1. Read `references/INSTALLATION.md`
2. Follow step-by-step SSH commands
3. Configure SSH keys for localhost management (critical step)

---

## Step 2: Secure HTTPS Access

**Determine access method based on Step 0 answers:**

| Scenario | Action |
|----------|--------|
| Cloudflare Tunnel = Yes | Read `references/cloudflare-tunnel.md` |
| OAuth/webhooks = Yes | Also read `references/cloudflare-origin-certificates.md` |
| Direct IP only (dev) | Skip tunnel, access via `http://SERVER_IP:8000` |

---

## Step 3: Verify Installation

Run this verification checklist:

```
Verification:
- [ ] Coolify UI accessible at configured domain or IP:8000
- [ ] Login with COOLIFY_ROOT_USER_EMAIL and password works
- [ ] Servers → localhost shows "Connected" (green)
- [ ] If tunnel: HTTPS working at COOLIFY_INSTANCE_DOMAIN
```

**If localhost not connected**: The SSH key configuration failed. See `references/INSTALLATION.md` section "Configure Coolify SSH Access".

---

## Navigation

Detailed references (one level deep):
- Manual SSH installation: `references/INSTALLATION.md`
- Fully automated setup: `references/ENHANCED_SETUP.md`
- Bundled scripts: `references/BUNDLED_SCRIPTS.md`
- Cloudflare Tunnel (wildcard): `references/cloudflare-tunnel.md`
- Origin certificates (OAuth/webhooks): `references/cloudflare-origin-certificates.md`
- Error 1033 troubleshooting: `references/TROUBLESHOOTING_CF1033.md`

## Critical Rules

- Always install Docker CE with Compose plugin before Coolify.
- Do not expose port 8000 publicly without HTTPS (tunnel or reverse proxy).
- Keep `/data/coolify` intact; treat it as state.
- Always configure Coolify's SSH key for localhost management.

## Logging Integration

Log major operations using centralized logging from `admin`:

```bash
log_admin "SUCCESS" "installation" "Installed Coolify" "version=4.x server=$SERVER_ID"
log_admin "SUCCESS" "system-change" "Configured Coolify" "domain=$DOMAIN"
log_admin "SUCCESS" "operation" "Deployed app via Coolify" "app=$APP_NAME"
```

## Related Skills

- `devops` for inventory and provisioning.
- Provider skills (oci, hetzner, contabo, etc.) for provider-specific VM setup.
- `admin (wsl)` for local Docker/CLI support when coordinating from WSL.

## References

- Coolify docs: https://coolify.io/docs
- Coolify GitHub: https://github.com/coollabsio/coolify

## Reference Appendices

### coolify: references/BUNDLED_SCRIPTS.md

# Coolify Bundled Scripts Documentation

**Last Updated**: 2025-11-15
**Skill**: coolify
**Version**: 1.0.0

This document provides comprehensive documentation for all bundled scripts in the Coolify skill.

---

## Table of Contents

1. [coolify-enhanced-setup.sh](#coolify-enhanced-setupsh) ⭐ **NEW**
2. [coolify-installation.sh](#coolify-installationsh)
3. [oci-coolify-infrastructure-setup.sh](#oci-coolify-infrastructure-setupsh)
4. [coolify-cloudflare-tunnel-setup.sh](#coolify-cloudflare-tunnel-setupsh)
5. [coolify-fix-dns.sh](#coolify-fix-dnssh)
6. [validate-env.sh](#validate-envsh)
7. [preflight-check.sh](#preflight-checksh)

---

## coolify-enhanced-setup.sh ⭐

**Status**: Production Ready
**Type**: Local Installation Script
**Purpose**: Fully automated Coolify setup with credential generation and domain configuration

### Overview

The **Enhanced Setup Script** provides a completely automated Coolify installation experience with:

- 🔐 Automatic secure password generation
- 🌐 Pre-configured domain and wildcard support
- 📝 Auto-generated setup documentation
- 🔒 Firewall and DNS pre-configuration
- ⚡ Zero manual intervention required

### Features

| Feature | Description |
|---------|-------------|
| **Password Generation** | Cryptographically secure 25-character passwords using OpenSSL |
| **Domain Config** | Wildcard domain support for automatic app subdomains |
| **Firewall Setup** | UFW automatically configured with required ports |
| **DNS Configuration** | Cloudflare and Google DNS pre-configured |
| **Credential Storage** | Secure file at `/opt/coolify-credentials.txt` (600 permissions) |
| **Setup Guide** | Auto-generated guide at `/opt/coolify-setup-complete.txt` |
| **Docker Install** | Automatic Docker installation if not present |
| **Service Verification** | Post-install health checks |

### Usage

#### Basic Usage (Local Machine)

```bash
# Set your domain and email
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"

# Run enhanced setup
./scripts/coolify-enhanced-setup.sh
```

#### Custom Configuration

```bash
# Full configuration
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export WILDCARD_DOMAIN="*.yourdomain.com"
export ADMIN_USERNAME="admin"
export ADMIN_EMAIL="admin@yourdomain.com"

# Optional: Provide your own password (leave blank for auto-generation)
export ROOT_USER_PASSWORD=""

./scripts/coolify-enhanced-setup.sh
```

#### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/vibeskills-demo/main/.claude/skills/devops/scripts/coolify-enhanced-setup.sh | bash
```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COOLIFY_DOMAIN` | No | `coolify.yourdomain.com` | Main Coolify access domain |
| `WILDCARD_DOMAIN` | No | `*.yourdomain.com` | Wildcard for deployed apps |
| `ADMIN_USERNAME` | No | `admin` | Admin username |
| `ADMIN_EMAIL` | No | `admin@yourdomain.com` | Admin email address |
| `ROOT_USER_PASSWORD` | No | Auto-generated | Admin password (leave blank for auto-gen) |

### Output Files

| File | Location | Permissions | Description |
|------|----------|-------------|-------------|
| Credentials | `/opt/coolify-credentials.txt` | 600 (root only) | Admin login credentials |
| Setup Guide | `/opt/coolify-setup-complete.txt` | 600 (root only) | Complete setup instructions |
| DNS Backup | `/etc/resolv.conf.backup` | 644 | Backup of original DNS config |

### Post-Installation

**View Credentials:**
```bash
sudo cat /opt/coolify-credentials.txt
```

**View Setup Guide:**
```bash
sudo cat /opt/coolify-setup-complete.txt
```

**Access Coolify:**
```
http://YOUR_SERVER_IP:8000
```

### Example Output

```
🎉 Coolify Enhanced Installation Complete!
==========================================

📋 Installation Summary:
   ✅ Docker installed and running
   ✅ Coolify installed and running
   ✅ Admin credentials generated
   ✅ Firewall configured
   ✅ DNS configured

🌐 Access Information:
   Local URL: http://localhost:8000
   Public URL: http://123.456.789.0:8000
   Domain: https://coolify.yourdomain.com (after DNS setup)

🔑 Credentials Location:
   /opt/coolify-credentials.txt
```

### Time Savings

- **Standard Install**: 30-45 minutes (manual steps)
- **Enhanced Install**: 5-10 minutes (fully automated)
- **Time Saved**: ~35 minutes per installation

---

## coolify-installation.sh

**Status**: Production Ready
**Type**: Remote Installation Script
**Purpose**: Install Coolify on remote servers via SSH

### Overview

Standard installation script for deploying Coolify on remote servers (especially OCI ARM64 instances).

### Features

- Remote installation via SSH
- ARM64 architecture support
- Docker installation
- Firewall configuration
- Service verification
- Access file generation

### Usage

```bash
# Set environment variables
export COOLIFY_SERVER_IP="123.456.789.0"
export SSH_USER="ubuntu"
export SSH_KEY_PATH="~/.ssh/id_rsa"
export ROOT_USERNAME="admin"
export ROOT_USER_EMAIL="admin@yourdomain.com"
export ROOT_USER_PASSWORD="YourSecurePassword123"

# Run installation
./scripts/coolify-installation.sh
```

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `COOLIFY_SERVER_IP` | Target server IP address |
| `SSH_USER` | SSH username (usually 'ubuntu') |
| `SSH_KEY_PATH` | Path to SSH private key |
| `COOLIFY_PORT` | Coolify web interface port (default: 8000) |
| `ROOT_USERNAME` | Admin username |
| `ROOT_USER_EMAIL` | Admin email |
| `ROOT_USER_PASSWORD` | Admin password |

### Installation Steps

1. System verification and updates
2. Docker installation
3. Additional dependencies
4. Coolify installation
5. Service verification
6. Firewall configuration
7. Credential retrieval
8. Final verification

---

## oci-coolify-infrastructure-setup.sh

**Status**: Production Ready
**Type**: Infrastructure Provisioning
**Purpose**: Complete OCI infrastructure setup with Coolify installation

### Overview

End-to-end infrastructure provisioning script that:
1. Creates OCI compute instance
2. Configures networking and security
3. Installs Coolify via enhanced setup
4. Sets up Cloudflare tunnel (optional)

### Features

- Terraform-based infrastructure
- Automated instance creation
- Network configuration
- Security list setup
- Enhanced Coolify installation
- Optional Cloudflare Tunnel integration

### Usage

```bash
# Set OCI credentials
export OCI_TENANCY_OCID="ocid1.tenancy..."
export OCI_USER_OCID="ocid1.user..."
export OCI_FINGERPRINT="aa:bb:cc..."
export OCI_PRIVATE_KEY_PATH="~/.oci/key.pem"
export OCI_REGION="us-ashburn-1"

# Set project configuration
export PROJECT_NAME="coolify"
export COOLIFY_DOMAIN="coolify.yourdomain.com"

# Run setup
./scripts/oci-coolify-infrastructure-setup.sh
```

### What It Creates

- OCI compute instance (ARM64)
- Virtual network (VCN)
- Subnet with proper routing
- Security lists (firewall rules)
- Public IP address
- SSH key pair
- Coolify installation
- Optional: Cloudflare Tunnel

---

## coolify-cloudflare-tunnel-setup.sh

**Status**: Production Ready (Fixed)
**Type**: Tunnel Configuration
**Purpose**: Set up Cloudflare Tunnel for secure HTTPS access

### Overview

Configures Cloudflare Tunnel to provide:
- Secure HTTPS access without port forwarding
- Wildcard subdomain support
- Automatic SSL certificates
- Protection from direct IP access

### Features

- Wildcard DNS support
- Automatic tunnel creation
- Ingress rules configuration
- Service deployment
- SSL termination at edge

### Usage

```bash
# Set Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
export TUNNEL_NAME="coolify-tunnel"
export TUNNEL_HOSTNAME="coolify.yourdomain.com"

# Run tunnel setup
./scripts/coolify-cloudflare-tunnel-setup.sh
```

### Recent Fixes

✅ **Wildcard DNS** - Now creates `*` CNAME instead of specific subdomain
✅ **Wildcard Ingress** - Routes all subdomains through tunnel
✅ **Timeout Values** - Fixed integer parsing for API

See `issues/tunnel-fixes-applied.md` for details.

---

## coolify-fix-dns.sh

**Status**: Production Ready
**Type**: Troubleshooting Utility
**Purpose**: Fix DNS resolution issues

### Overview

Diagnostic and fix script for DNS resolution problems.

### Features

- DNS configuration diagnosis
- Automatic fix application
- Cloudflare/Google DNS setup
- Resolution testing
- Backup of original config

### Usage

```bash
./scripts/coolify-fix-dns.sh
```

### What It Fixes

- Missing or incorrect nameservers
- Slow DNS resolution
- Failed package installations
- Network connectivity issues

---

## validate-env.sh

**Status**: Production Ready
**Type**: Validation Utility
**Purpose**: Validate environment variables before installation

### Overview

Pre-flight validation to ensure all required environment variables are set.

### Features

- Required variable checking
- Format validation
- SSH key verification
- IP address validation

### Usage

```bash
# Run before other scripts
./scripts/validate-env.sh

# Or source it in your script
source ./scripts/validate-env.sh
```

---

## preflight-check.sh

**Status**: Production Ready
**Type**: System Check Utility
**Purpose**: Verify system requirements before installation

### Overview

Checks system compatibility and prerequisites.

### Features

- OS version check
- Architecture verification
- Docker availability
- Memory requirements
- Disk space check
- Network connectivity

### Usage

```bash
./scripts/preflight-check.sh
```

---

## Script Dependencies

```
┌─────────────────────────────────────────┐
│  oci-coolify-infrastructure-setup.sh    │
│  (Main orchestration)                   │
└────────────┬────────────────────────────┘
             │
             ├──> validate-env.sh
             ├──> preflight-check.sh
             │
             ├──> Terraform (creates instance)
             │
             ├──> coolify-enhanced-setup.sh ⭐
             │    ├──> DNS configuration
             │    ├──> Docker installation
             │    ├──> Coolify installation
             │    ├──> Credential generation
             │    └──> Firewall setup
             │
             └──> coolify-cloudflare-tunnel-setup.sh
                  ├──> Tunnel creation
                  ├──> DNS configuration
                  └──> Service deployment
```

---

## Quick Reference

### Installation Scenarios

| Scenario | Script to Use | Duration |
|----------|--------------|----------|
| **New local install** | `coolify-enhanced-setup.sh` ⭐ | 5-10 min |
| **Remote server** | `coolify-installation.sh` | 15-20 min |
| **Full OCI deployment** | `oci-coolify-infrastructure-setup.sh` | 20-30 min |
| **Add Cloudflare Tunnel** | `coolify-cloudflare-tunnel-setup.sh` | 5 min |
| **Fix DNS issues** | `coolify-fix-dns.sh` | 1-2 min |

### Recommended Workflow

1. **Initial Setup**:
   ```bash
   # Create .env from template
   cp templates/env-enhanced.example .env

   # Edit configuration
   nano .env

   # Run preflight check
   ./scripts/preflight-check.sh

   # Run enhanced setup
   ./scripts/coolify-enhanced-setup.sh
   ```

2. **Add Cloudflare Tunnel** (Optional):
   ```bash
   ./scripts/coolify-cloudflare-tunnel-setup.sh
   ```

3. **Troubleshooting**:
   ```bash
   # If DNS issues
   ./scripts/coolify-fix-dns.sh

   # View logs
   docker logs coolify
   ```

---

## Common Issues and Solutions

### Issue: Script Permission Denied

```bash
chmod +x scripts/*.sh
```

### Issue: Missing Environment Variables

```bash
./scripts/validate-env.sh
```

### Issue: DNS Resolution Failures

```bash
./scripts/coolify-fix-dns.sh
```

### Issue: Forgot Credentials

```bash
sudo cat /opt/coolify-credentials.txt
```

---

## Environment Variable Templates

See:
- `templates/env-enhanced.example` - Full environment configuration
- `.env.example` - Standard configuration
- `ENHANCED_SETUP.md` - Detailed documentation

---

## Additional Resources

**Documentation:**
- `ENHANCED_SETUP.md` - Enhanced setup guide
- `SKILL.md` - Coolify skill documentation
- `templates/enhanced-quick-start.md` - Quick start guide

**Issue Tracking:**
- `issues/tunnel-fixes-applied.md` - Cloudflare Tunnel fixes
- `issues/cloudflare-tunnel-timeout-parsing-error.md` - Timeout issues

**External Links:**
- [Coolify Documentation](https://coolify.io/docs)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Documentation](https://docs.docker.com/)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-15 | Initial release with enhanced setup script |
| 0.9.0 | 2025-11-13 | Cloudflare Tunnel wildcard fixes |
| 0.8.0 | 2025-11-10 | OCI infrastructure automation |
| 0.7.0 | 2025-11-05 | Initial script collection |

---

**Last Updated**: 2025-11-15
**Maintained By**: Infrastructure Skills Team
**License**: MIT

### coolify: references/ENHANCED_SETUP.md

# Enhanced Coolify Setup

**Status**: Production Ready
**Version**: 1.0.0
**Last Updated**: 2025-11-15

## Contents
- Overview
- Quick Start
- Features
- Installation Modes
- Environment Variables
- Post-Installation
- File Locations
- Troubleshooting
- Comparison: Standard vs Enhanced Setup
- Security Considerations
- Integration with Existing Scripts
- Advanced Usage
- Future Enhancements
- Support

---

## Overview

The Enhanced Coolify Setup provides a fully automated installation experience with:

- 🔐 **Automated Credential Generation** - Cryptographically secure passwords
- 🌐 **Domain Configuration** - Wildcard domain support out of the box
- ⚡ **Zero Manual Setup** - Skip the setup wizard entirely
- 📝 **Complete Documentation** - Auto-generated setup guides
- 🔒 **Production-Ready Security** - Firewall and DNS pre-configured

## Quick Start

### One-Line Installation

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Then run the enhanced setup:

```bash
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"
./scripts/coolify-enhanced-setup.sh
```

### What Gets Automated

**Before Enhanced Setup:**
1. ❌ Manual credential creation
2. ❌ Manual domain configuration
3. ❌ Manual firewall setup
4. ❌ Manual DNS instructions
5. ❌ Setup wizard navigation
6. ⏱️ **Total time: 30-45 minutes**

**With Enhanced Setup:**
1. ✅ Secure password auto-generated
2. ✅ Domain configuration automated
3. ✅ Firewall configured automatically
4. ✅ DNS instructions provided
5. ✅ Setup wizard pre-filled
6. ⚡ **Total time: 5-10 minutes**

## Features

### 1. Secure Password Generation

```bash
# Automatically generates cryptographically secure passwords
openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
```

**Benefits:**
- 25-character passwords (very strong)
- Cryptographically random
- No special characters (avoids shell escaping issues)
- Automatically saved to secure file

### 2. Domain Configuration

**Supports:**
- Main Coolify domain (e.g., `coolify.yourdomain.com`)
- Wildcard domains for apps (e.g., `*.yourdomain.com`)
- Automatic DNS instructions
- SSL certificate guidance

**Example:**
```bash
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export WILDCARD_DOMAIN="*.yourdomain.com"
```

Apps automatically get domains like:
- `myapp.yourdomain.com`
- `blog.yourdomain.com`
- `api.yourdomain.com`

### 3. Credential Management

**Credentials are saved to:**
```
/opt/coolify-credentials.txt
```

**Security:**
- File permissions: `600` (owner read/write only)
- Owned by root
- Includes access instructions
- Auto-generated backup

**View credentials:**
```bash
sudo cat /opt/coolify-credentials.txt
```

### 4. Automated Firewall Setup

**Ports automatically configured:**
- `22` - SSH (required)
- `8000` - Coolify Web Interface
- `80` - HTTP (Traefik Proxy)
- `443` - HTTPS (Traefik Proxy)
- `6001` - Coolify Proxy HTTP
- `6002` - Coolify Proxy HTTPS

**UFW configuration:**
```bash
sudo ufw status numbered
```

### 5. DNS Resolution

**Automatically configures:**
- Cloudflare DNS (1.1.1.1, 1.0.0.1)
- Google DNS (8.8.8.8, 8.8.4.4)
- Backup of existing config

**Benefits:**
- Reliable resolution
- Fast response times
- Fallback options

## Installation Modes

### Mode 1: Local Installation

Install Coolify on the current machine:

```bash
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"
./scripts/coolify-enhanced-setup.sh
```

### Mode 2: Remote Installation via SSH

Install Coolify on a remote server:

```bash
export COOLIFY_SERVER_IP="123.456.789.0"
export SSH_USER="ubuntu"
export SSH_KEY_PATH="~/.ssh/id_rsa"
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"
./scripts/oci-coolify-infrastructure-setup.sh
```

### Mode 3: Custom Credentials

Provide your own password:

```bash
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"
export ROOT_USER_PASSWORD="YourSecurePassword123"
./scripts/coolify-enhanced-setup.sh
```

## Environment Variables

### Required

```bash
COOLIFY_DOMAIN="coolify.yourdomain.com"    # Main domain
ADMIN_EMAIL="admin@yourdomain.com"          # Admin email
```

### Optional

```bash
WILDCARD_DOMAIN="*.yourdomain.com"         # Wildcard domain
ADMIN_USERNAME="admin"                      # Admin username (default: admin)
ROOT_USER_PASSWORD=""                       # Leave blank for auto-generation
```

### Remote Installation

```bash
COOLIFY_SERVER_IP="123.456.789.0"          # Remote server IP
SSH_USER="ubuntu"                           # SSH user
SSH_KEY_PATH="~/.ssh/id_rsa"               # SSH private key
```

## Post-Installation

### 1. View Credentials

```bash
sudo cat /opt/coolify-credentials.txt
```

### 2. View Setup Guide

```bash
sudo cat /opt/coolify-setup-complete.txt
```

### 3. Configure DNS

**A Record for Coolify:**
```
Type: A
Name: coolify
Value: YOUR_SERVER_IP
TTL: 300
```

**Wildcard for Apps:**
```
Type: A
Name: *
Value: YOUR_SERVER_IP
TTL: 300
```

### 4. Access Coolify

```
http://YOUR_SERVER_IP:8000
```

### 5. Set Up SSL

1. Access Coolify web interface
2. Go to Settings → SSL
3. Enable Let's Encrypt
4. Configure wildcard certificate

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Credentials | `/opt/coolify-credentials.txt` | Admin login info |
| Setup Guide | `/opt/coolify-setup-complete.txt` | Complete setup instructions |
| DNS Config | `/etc/resolv.conf` | DNS resolver configuration |
| DNS Backup | `/etc/resolv.conf.backup` | Original DNS config |

## Troubleshooting

### Issue: Can't access Coolify

**Check containers:**
```bash
docker ps | grep coolify
```

**Check logs:**
```bash
docker logs coolify
```

**Restart services:**
```bash
docker restart coolify
```

### Issue: Forgot password

**View credentials:**
```bash
sudo cat /opt/coolify-credentials.txt
```

**Reset password:**
```bash
docker exec coolify php artisan tinker
# In tinker:
$user = User::where('email', 'admin@yourdomain.com')->first();
$user->password = Hash::make('NewPassword123');
$user->save();
exit
```

### Issue: DNS not working

**Check DNS config:**
```bash
cat /etc/resolv.conf
```

**Test resolution:**
```bash
nslookup google.com
```

**Restore DNS:**
```bash
sudo cp /etc/resolv.conf.backup /etc/resolv.conf
```

## Comparison: Standard vs Enhanced Setup

| Feature | Standard Setup | Enhanced Setup |
|---------|---------------|----------------|
| Password Generation | Manual | ✅ Automatic |
| Domain Config | Manual | ✅ Automatic |
| Firewall Setup | Manual | ✅ Automatic |
| DNS Instructions | None | ✅ Provided |
| Credentials Storage | None | ✅ Secure file |
| Setup Time | 30-45 min | ⚡ 5-10 min |
| Documentation | Manual | ✅ Auto-generated |

## Security Considerations

### Credentials File

**Location:** `/opt/coolify-credentials.txt`

**Security:**
- ✅ File permissions: `600` (owner only)
- ✅ Root ownership
- ✅ Not in home directory
- ⚠️  Remember to backup before destroying instance
- ⚠️  Never commit to version control

### Password Strength

**Generated passwords:**
- Length: 25 characters
- Character set: Base64 (alphanumeric + some symbols)
- Entropy: ~150 bits
- Method: OpenSSL cryptographic random

**Strength:**
- ✅ Resistant to brute force
- ✅ Resistant to dictionary attacks
- ✅ Meets enterprise password requirements

### Firewall

**Default policy:** Deny all incoming

**Allowed ports:**
- ✅ Only essential ports open
- ✅ SSH always allowed
- ✅ Web ports for proxy
- ⚠️  Consider restricting SSH by IP

## Integration with Existing Scripts

The enhanced setup integrates with:

1. **`coolify-installation.sh`** - Standard installation script
2. **`oci-coolify-infrastructure-setup.sh`** - OCI deployment
3. **`coolify-cloudflare-tunnel-setup.sh`** - Cloudflare Tunnel
4. **`coolify-fix-dns.sh`** - DNS troubleshooting

**Flow:**
```
oci-infrastructure-setup.sh
  → Creates OCI instance
  → coolify-enhanced-setup.sh
    → Installs Docker
    → Installs Coolify
    → Generates credentials
    → Configures firewall
  → coolify-cloudflare-tunnel-setup.sh
    → Sets up tunnel
    → Configures DNS
    → Enables HTTPS
```

## Advanced Usage

### Custom Password Policy

```bash
# Generate 32-character password
generate_password() {
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-32
}

export ROOT_USER_PASSWORD=$(generate_password)
```

### Multiple Coolify Instances

```bash
# Instance 1
export COOLIFY_DOMAIN="coolify1.yourdomain.com"
export ADMIN_EMAIL="admin1@yourdomain.com"
./scripts/coolify-enhanced-setup.sh

# Instance 2
export COOLIFY_DOMAIN="coolify2.yourdomain.com"
export ADMIN_EMAIL="admin2@yourdomain.com"
./scripts/coolify-enhanced-setup.sh
```

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Deploy Coolify
  env:
    COOLIFY_DOMAIN: ${{ secrets.COOLIFY_DOMAIN }}
    ADMIN_EMAIL: ${{ secrets.ADMIN_EMAIL }}
  run: |
    ./scripts/coolify-enhanced-setup.sh
    sudo cat /opt/coolify-credentials.txt >> $GITHUB_OUTPUT
```

## Future Enhancements

**Planned features:**
- [ ] Automatic SSL certificate setup
- [ ] Cloudflare integration during install
- [ ] Multi-server support
- [ ] Backup configuration
- [ ] Email notification setup
- [ ] OIDC/SSO integration
- [ ] Monitoring integration

## Support

**Documentation:**
- See `templates/enhanced-quick-start.md` for quick start guide
- See `templates/env-enhanced.example` for environment variables
- See `SKILL.md` for Coolify skill documentation

**Troubleshooting:**
- Check `/var/log/syslog` for system logs
- Run `docker logs coolify` for Coolify logs
- View setup guide at `/opt/coolify-setup-complete.txt`

**Community:**
- Coolify Discord: https://discord.gg/coolify
- Coolify Docs: https://coolify.io/docs

### coolify: references/INSTALLATION.md

# Coolify Installation

Manual, repeatable installation for a single Coolify host. Use when you want explicit SSH‑driven setup rather than the enhanced automation script.

## Contents
- Prerequisites
- Installation Steps
- Configure Coolify SSH Access
- Configure Domain Settings (Turnkey)
- Verify and Access
- Required Environment Variables
- What Coolify Creates

---

## Prerequisites

Verify before installing:

1. **Server access**
   ```bash
   ssh ubuntu@<SERVER_IP> "echo connected"
   ```
   If this fails, check SSH key and server IP in `.env.local`.

2. **Minimum resources**
   ```bash
   ssh ubuntu@<SERVER_IP> "free -h | grep Mem"
   ```
   Required: 4GB+ RAM (2GB Coolify + 2GB for apps).

3. **Docker installed (or will be installed)**
   ```bash
   ssh ubuntu@<SERVER_IP> "docker --version"
   ```

4. **Required ports available**
   ```bash
   ssh ubuntu@<SERVER_IP> "sudo netstat -tlnp | grep -E ':(8000|80|443)'"
   ```
   Ports:
   - 8000: Coolify Web UI
   - 80/443: Traefik proxy (HTTP/HTTPS)
   - 6001/6002: Coolify internal

## Installation Steps

### Step 1: System update

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  sudo apt-get update && sudo apt-get upgrade -y
"
```

### Step 2: Install Docker

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl start docker && sudo systemctl enable docker
  sudo usermod -aG docker \$USER

  docker --version && docker compose version
"
```

### Step 3: Install dependencies

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  sudo apt-get install -y curl wget git unzip jq openssh-server
  sudo systemctl enable --now ssh
"
```

### Step 4: Install Coolify

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  export ROOT_USERNAME='$COOLIFY_ROOT_USERNAME'
  export ROOT_USER_EMAIL='$COOLIFY_ROOT_USER_EMAIL'
  export ROOT_USER_PASSWORD='$COOLIFY_ROOT_USER_PASSWORD'
  curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
"

sleep 30
```

Note: The installer expects `ROOT_USERNAME`, `ROOT_USER_EMAIL`, `ROOT_USER_PASSWORD`. This skill uses `COOLIFY_`‑prefixed vars in `.env.local` for clarity.

### Step 5: Configure firewall

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  sudo ufw --force enable
  sudo ufw allow 22/tcp
  sudo ufw allow 8000/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 6001/tcp
  sudo ufw allow 6002/tcp
  sudo ufw status
"
```

### Step 6: Verify installation

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  docker ps | grep coolify
  curl -s -o /dev/null -w '%{http_code}' http://localhost:8000
"
```

Expected: Coolify containers running; HTTP 200 or 302.

## Configure Coolify SSH Access

Coolify generates its own SSH key during installation. Add its public key to `authorized_keys` so Coolify can manage Docker containers on localhost.

Wait for key generation:

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  until docker exec coolify find /var/www/html/storage/app/ssh/keys/ -name 'ssh_key*' 2>/dev/null | grep -q .; do
    echo 'Waiting for Coolify SSH key generation...'
    sleep 10
  done
  echo 'SSH key found'
"
```

Extract and install the key:

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  KEY_FILE=\$(docker exec coolify find /var/www/html/storage/app/ssh/keys/ -type f -name 'ssh_key*' | head -1)
  echo \"Found key file: \$KEY_FILE\"

  COOLIFY_KEY=\$(docker exec coolify ssh-keygen -y -f \"\$KEY_FILE\")
  echo \"Coolify's public key: \$COOLIFY_KEY\"

  sudo mkdir -p /root/.ssh

  if sudo grep -q 'Please login as the user' /root/.ssh/authorized_keys 2>/dev/null; then
    echo 'OCI detected - replacing restrictive authorized_keys'
    echo \"\$COOLIFY_KEY coolify\" | sudo tee /root/.ssh/authorized_keys > /dev/null
  else
    echo 'Adding key to existing authorized_keys'
    echo \"\$COOLIFY_KEY\" | sudo tee -a /root/.ssh/authorized_keys > /dev/null
  fi

  sudo chmod 700 /root/.ssh
  sudo chmod 600 /root/.ssh/authorized_keys

  sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  sudo systemctl restart sshd

  echo \"\$COOLIFY_KEY\" >> ~/.ssh/authorized_keys
  echo 'SSH key added to authorized_keys'
"
```

Verify root SSH to localhost:

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  sudo ssh -o StrictHostKeyChecking=no -o BatchMode=yes root@localhost 'echo SSH connection successful'
"
```

## Configure Domain Settings (Turnkey)

Optional: auto‑configure Coolify’s instance FQDN and wildcard domain in Postgres.

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  until docker exec coolify-db pg_isready -U coolify -d coolify 2>/dev/null; do
    echo 'Waiting for Coolify database...'
    sleep 5
  done
  echo 'Database ready'
"

ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  docker exec coolify-db psql -U coolify -d coolify -c \
    \"UPDATE instance_settings SET fqdn = 'https://${COOLIFY_INSTANCE_DOMAIN}', updated_at = CURRENT_TIMESTAMP WHERE id = 0;\"
"

ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  docker exec coolify-db psql -U coolify -d coolify -c \
    \"UPDATE server_settings SET wildcard_domain = 'https://${COOLIFY_WILDCARD_DOMAIN}', updated_at = CURRENT_TIMESTAMP WHERE server_id = 0;\"
"

ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "docker restart coolify"
sleep 15
```

Verify:

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$COOLIFY_SERVER_IP "
  docker exec coolify-db psql -U coolify -d coolify -c \
    \"SELECT 'Instance FQDN' as setting, fqdn as value FROM instance_settings WHERE id = 0
     UNION ALL
     SELECT 'Wildcard Domain', wildcard_domain FROM server_settings WHERE server_id = 0;\"
"
```

## Verify and Access

Open: `http://$COOLIFY_SERVER_IP:8000` and log in with the configured admin credentials.

Verify localhost server is connected:
1. Go to **Servers**.
2. Select **localhost**.
3. Ensure status is “Connected”; otherwise click “Validate Server”.

For secure HTTPS access, set up Cloudflare Tunnel: `references/cloudflare-tunnel.md`.  
For OAuth/webhook origin certs, see `references/cloudflare-origin-certificates.md`.

## Required Environment Variables

```bash
COOLIFY_SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa

COOLIFY_ROOT_USERNAME=admin
COOLIFY_ROOT_USER_EMAIL=admin@yourdomain.com
COOLIFY_ROOT_USER_PASSWORD=your-secure-password

COOLIFY_INSTANCE_DOMAIN=coolify.yourdomain.com
COOLIFY_WILDCARD_DOMAIN=yourdomain.com
```

## What Coolify Creates

| Service | Port | Purpose |
|---------|------|---------|
| Coolify Web UI | 8000 | Management interface |
| Traefik Proxy | 80/443 | HTTP/HTTPS routing |
| PostgreSQL | Internal | Coolify database |
| Redis | Internal | Caching |

### coolify: references/TROUBLESHOOTING_CF1033.md

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

### coolify: references/cloudflare-origin-certificates.md

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

### coolify: references/cloudflare-tunnel.md

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
