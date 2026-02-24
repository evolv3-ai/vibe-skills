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

