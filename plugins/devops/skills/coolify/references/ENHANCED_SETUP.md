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
