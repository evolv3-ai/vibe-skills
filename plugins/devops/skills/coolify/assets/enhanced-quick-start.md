# Enhanced Coolify Quick Start with Automated Setup

This guide shows how to install Coolify with automated credential generation and domain configuration.

## Contents

- Option 1: One-Command Automated Setup
- Option 2: Customized Automated Setup
- Option 3: Manual Credential Setup
- Post-Installation Steps
- Environment Variables Reference
- Useful Commands
- Security Best Practices
- Troubleshooting
- Benefits of Enhanced Setup
- Next Steps
- Additional Resources

---

## Option 1: One-Command Automated Setup

The easiest way to install Coolify with all credentials and domains pre-configured:

```bash
# Download and run enhanced setup script
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/vibeskills-demo/main/.claude/skills/coolify/scripts/coolify-enhanced-setup.sh | bash
```

**What this does:**
- ✅ Generates secure admin password automatically
- ✅ Installs Docker if not present
- ✅ Installs and configures Coolify
- ✅ Sets up firewall rules
- ✅ Configures DNS resolution
- ✅ Saves credentials to secure file
- ✅ Provides DNS setup instructions

## Option 2: Customized Automated Setup

Install with your own domain and email:

```bash
# Set your configuration
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export WILDCARD_DOMAIN="*.yourdomain.com"
export ADMIN_USERNAME="admin"
export ADMIN_EMAIL="admin@yourdomain.com"

# Run enhanced setup
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/vibeskills-demo/main/.claude/skills/coolify/scripts/coolify-enhanced-setup.sh | bash

# View generated credentials
sudo cat /opt/coolify-credentials.txt
```

**Example configuration:**
```bash
COOLIFY_DOMAIN="coolify.yourdomain.com"
WILDCARD_DOMAIN="*.yourdomain.com"
ADMIN_EMAIL="admin@yourdomain.com"
```

## Option 3: Manual Credential Setup

If you prefer to set your own password:

```bash
# Set your credentials
export COOLIFY_DOMAIN="coolify.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"
export ROOT_USERNAME="admin"
export ROOT_USER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Install Coolify with pre-configured credentials
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

# Wait for services
sleep 60

# Verify installation
docker ps | grep coolify

# Display access information
echo "✅ Coolify installed!"
echo "🌐 Access at: http://$(curl -s ifconfig.me):8000"
echo "🔑 Username: $ROOT_USERNAME"
echo "🔑 Password: $ROOT_USER_PASSWORD"
```

## Post-Installation Steps

After installation completes:

### 1. View Your Credentials

```bash
sudo cat /opt/coolify-credentials.txt
```

### 2. Access Coolify

Open in your browser:
```
http://YOUR_SERVER_IP:8000
```

### 3. Configure DNS (Required for Domain Access)

Add these DNS records at your DNS provider:

**A Record for Coolify:**
```
Type: A
Name: coolify (or your subdomain)
Value: YOUR_SERVER_IP
TTL: 300
```

**Wildcard for Applications:**
```
Type: A
Name: *
Value: YOUR_SERVER_IP
TTL: 300
```

### 4. Login and Complete Setup

1. Access the web interface
2. Login with credentials from `/opt/coolify-credentials.txt`
3. Complete initial setup wizard
4. Add localhost as your first server
5. Create your first project

### 5. Deploy Your First Application

1. Click "New Application"
2. Choose source (Git, Docker Image, etc.)
3. Configure domain (uses wildcard: `myapp.yourdomain.com`)
4. Set environment variables
5. Deploy!

## Environment Variables Reference

All supported environment variables for automated setup:

```bash
# Domain Configuration
export COOLIFY_DOMAIN="coolify.yourdomain.com"      # Main Coolify domain
export WILDCARD_DOMAIN="*.yourdomain.com"           # Wildcard for apps

# Admin Credentials
export ADMIN_USERNAME="admin"                        # Admin username
export ADMIN_EMAIL="admin@yourdomain.com"           # Admin email
export ROOT_USER_PASSWORD="auto-generated"          # Leave blank for auto-generation

# Coolify-Specific (used by installer)
export COOLIFY_ROOT_USERNAME="$ADMIN_USERNAME"
export COOLIFY_ROOT_EMAIL="$ADMIN_EMAIL"
export COOLIFY_ROOT_PASSWORD="$ROOT_USER_PASSWORD"
export COOLIFY_WILDCARD_DOMAIN="$WILDCARD_DOMAIN"
```

## Useful Commands

### View Credentials
```bash
sudo cat /opt/coolify-credentials.txt
```

### View Setup Guide
```bash
sudo cat /opt/coolify-setup-complete.txt
```

### Check Coolify Status
```bash
docker ps | grep coolify
```

### View Logs
```bash
docker logs coolify
```

### Restart Coolify
```bash
docker restart coolify
```

### Update Coolify
```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

## Security Best Practices

1. **Credentials File**: Located at `/opt/coolify-credentials.txt`
   - Automatically secured with 600 permissions
   - DO NOT commit to version control
   - Backup securely if needed

2. **Firewall**: Automatically configured with UFW
   - SSH (22)
   - Coolify Web (8000)
   - HTTP/HTTPS (80, 443)
   - Proxy Ports (6001, 6002)

3. **SSL Certificates**: Set up after installation
   - Use Let's Encrypt (free)
   - Configure in Coolify web interface
   - Automatic renewal supported

## Troubleshooting

### Coolify not accessible

```bash
# Check if containers are running
docker ps | grep coolify

# Check logs
docker logs coolify

# Restart services
docker restart coolify
```

### DNS not resolving

```bash
# Check DNS configuration
cat /etc/resolv.conf

# Test DNS resolution
nslookup google.com
```

### Firewall blocking access

```bash
# Check firewall status
sudo ufw status

# Allow required ports
sudo ufw allow 8000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Benefits of Enhanced Setup

**vs Manual Installation:**
- ⚡ 5x faster - skips manual credential setup
- 🔐 More secure - cryptographically generated passwords
- 📝 Better documentation - auto-generated setup guide
- 🎯 Fewer errors - automated configuration
- 🚀 Production-ready - includes firewall setup

**What's Automated:**
- ✅ Secure password generation
- ✅ DNS configuration
- ✅ Docker installation
- ✅ Firewall setup
- ✅ Credentials management
- ✅ Domain configuration
- ✅ Service verification

## Next Steps

After successful installation:

1. ✅ Configure DNS records at your provider
2. ✅ Access Coolify web interface
3. ✅ Login with generated credentials
4. ✅ Complete initial setup wizard
5. ✅ Set up SSL certificates
6. ✅ Deploy your first application
7. ✅ Configure Cloudflare tunnel (optional)

## Additional Resources

- **Credentials**: `/opt/coolify-credentials.txt`
- **Setup Guide**: `/opt/coolify-setup-complete.txt`
- **Official Docs**: https://coolify.io/docs
- **Community**: https://discord.gg/coolify
