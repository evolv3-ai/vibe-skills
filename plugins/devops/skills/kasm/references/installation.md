# KASM Workspaces Installation

## Pre-Installation Checklist

Collect these parameters before starting:

```
Required:
- [ ] Server IP address
- [ ] SSH user (default: ubuntu)
- [ ] SSH key path
- [ ] Admin password (minimum 12 characters)
- [ ] Admin email (default: admin@kasm.local)

Resources:
- [ ] Server RAM >= 8GB (4GB KASM + 4GB per concurrent session)
- [ ] Swap file size (recommended: 8GB)
- [ ] Disk space >= 75GB SSD

Networking:
- [ ] Using Cloudflare Tunnel? If yes: API token, account ID, tunnel hostname
- [ ] Custom port? (default: 443 after install, 8443 during install)
```

---

## Step 1: Prepare the Server

### Install Docker CE + Compose Plugin

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify
docker --version    # Must be >= 25.0.5
docker compose version  # Must be >= 2.40.2
```

### Configure Swap (Critical)

KASM can be unstable without swap even with sufficient RAM.

```bash
# Create 8GB swap file
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h  # Should show swap
```

---

## Step 2: Install KASM

### Download and Run Installer

Check https://kasmweb.com/downloads for the latest version URL.

```bash
# Download (replace URL with latest version)
cd /tmp
wget https://kasm-static-content.s3.amazonaws.com/kasm_release_<VERSION>.tar.gz

# Extract
tar -xf kasm_release_<VERSION>.tar.gz

# Run installer
sudo bash kasm_release/install.sh --accept-eula
```

The installer will:
- Create `/opt/kasm/` directory
- Pull Docker images for all components
- Generate admin credentials
- Start all services
- Listen on port 443 (HTTPS with self-signed cert)

### Get Admin Credentials

```bash
# Extract from install log
grep "admin@kasm.local" /opt/kasm/current/install_log.txt
```

Save these credentials securely. You can change the password after first login.

---

## Step 3: Verify Installation

```bash
# Check all KASM containers are running
sudo docker ps | grep kasm

# Expected containers (at minimum):
# kasm_api, kasm_agent, kasm_manager, kasm_proxy, kasm_db, kasm_redis

# Check service health
sudo docker logs --tail 20 kasm_api
sudo docker logs --tail 20 kasm_agent
```

### Access the UI

1. Open `https://<SERVER_IP>` in a browser
2. Accept the self-signed certificate warning
3. Log in with admin credentials from install log
4. Navigate to Workspaces to see available desktop images

### If Login Fails

```bash
# Re-extract credentials
grep -A2 "admin" /opt/kasm/current/install_log.txt

# Check API is responding
sudo docker logs --tail 50 kasm_api | grep -i error

# Restart services if needed
sudo /opt/kasm/current/bin/stop
sudo /opt/kasm/current/bin/start
```

---

## Step 4: Post-Installation Setup

### Create Profile Storage Directory

```bash
sudo mkdir -p /mnt/kasm_profiles
sudo chown -R 1000:1000 /mnt/kasm_profiles
```

### Configure Persistent Profiles

In the KASM Admin UI:
1. Go to Workspaces > select a workspace > Edit
2. Set **Persistent Profile Path**: `/mnt/kasm_profiles/{username}/{image_id}`
3. Go to Access Management > Groups > select group
4. Enable **Allow Persistent Profile**

See `workspace-configuration.md` for detailed configuration.

### Set Up HTTPS Access

For Cloudflare Tunnel, see `networking.md`.
For direct access, the self-signed cert works for development.

---

## Upgrade Path

### Check Current Version

```bash
sudo docker exec kasm_api cat /usr/local/lib/python3.12/site-packages/api_server/VERSION
# Or check the admin UI footer
```

### Upgrade Steps

1. Back up database first: See `backup-recovery.md`
2. Download new version installer
3. Run with upgrade flag:

```bash
sudo bash kasm_release/install.sh --upgrade --accept-eula
```

4. Verify all services start correctly
5. Test workspace creation

### Version Compatibility Notes

- 1.17.0 -> 1.18.x: Adds bulk user/server import (CSV)
- Always backup before upgrading
- Check release notes for breaking changes: https://docs.kasm.com/docs/release_notes/
