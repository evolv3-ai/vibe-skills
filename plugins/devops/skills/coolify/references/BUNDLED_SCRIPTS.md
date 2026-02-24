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
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/vibeskills-demo/main/.claude/skills/coolify/scripts/coolify-enhanced-setup.sh | bash
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
