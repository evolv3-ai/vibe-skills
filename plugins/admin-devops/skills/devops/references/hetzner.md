# Hetzner Infrastructure

_Consolidated from `skills/admin-devops (hetzner)` on 2026-02-02_

## Skill Body

# Hetzner Cloud Infrastructure

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Status**: Production Ready | **Dependencies**: hcloud CLI, SSH key pair

---

## Navigation

- Operations, troubleshooting, config, and cost snapshot: `references/OPERATIONS.md`

---

## Step 0: Gather Required Information (MANDATORY)

**STOP. Before ANY deployment commands, collect ALL parameters from the user.**

Copy this checklist and confirm each item:

```
Required Parameters:
- [ ] SERVER_NAME          - Unique name for this server
- [ ] HETZNER_LOCATION     - Location (nbg1, fsn1, hel1, ash, hil)
- [ ] HETZNER_SERVER_TYPE  - Server type (see profiles below)
- [ ] SSH_KEY_NAME         - Name of SSH key in Hetzner
- [ ] SSH_KEY_PATH         - Path to local SSH private key (default: ~/.ssh/id_rsa)

Architecture Choice:
- [ ] ARM64 (CAX*) or x86 (CX*)?
      ARM64 → Only available in EU (nbg1, fsn1, hel1)
      x86   → Available in EU and US (ash, hil)

Deployment Purpose (determines recommended profile):
- [ ] Purpose: coolify / kasm / both / custom
      coolify → CAX11 ARM (~$4/mo) or CX22 x86 (~$5/mo)
      kasm    → CAX21 ARM (~$8/mo) or CX32 x86 (~$10/mo)
      both    → CAX31 ARM (~$16/mo) or CX42 x86 (~$20/mo)
```

**Recommended profiles by purpose:**

| Purpose | ARM (EU only) | x86 (EU+US) | vCPU | RAM | Monthly |
|---------|---------------|-------------|------|-----|---------|
| coolify | CAX11 | CX22 | 2 | 4GB | ~$4-5 |
| kasm | CAX21 | CX32 | 4 | 8GB | ~$8-10 |
| both | CAX31 | CX42 | 8 | 16GB | ~$16-20 |

**DO NOT proceed to Prerequisites until ALL parameters are confirmed.**

---

## Prerequisites

Before using this skill, verify the following:

### 1. Hetzner Cloud CLI Installed

```bash
hcloud version
```

**If missing**, install with:

```bash
# macOS
brew install hcloud

# Linux (download binary)
curl -sL https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar xz
sudo mv hcloud /usr/local/bin/

# Or via package manager (Arch)
pacman -S hcloud
```

### 2. Hetzner Account & API Token

**If you don't have a Hetzner account**:

Sign up at: https://hetzner.cloud/?ref=o3LvvIQgI5gs

> *Disclosure: This is a referral link. You'll receive €20 cloud credit, and the skill author receives a small credit. Using this link helps support the development of these skills.*

**Get API token**: https://console.hetzner.cloud/ → Project → Security → API Tokens

Create a **Read & Write** token.

### 3. hcloud CLI Configured

```bash
hcloud context list
```

**If empty**, configure with one of these methods:

**Method A: Non-interactive (recommended for automation)**:
```bash
# Write directly to hcloud config file
mkdir -p ~/.config/hcloud
cat > ~/.config/hcloud/cli.toml << EOF
active_context = "myproject"

[[contexts]]
name = "myproject"
token = "$HETZNER_API_TOKEN"
EOF
chmod 600 ~/.config/hcloud/cli.toml
```

**Method B: Environment variable (temporary, no config saved)**:
```bash
# Set for current session only - hcloud commands will work but context won't persist
export HCLOUD_TOKEN="$HETZNER_API_TOKEN"
hcloud server list  # Works without context
```

**Method C: Interactive (manual setup)**:
```bash
hcloud context create myproject
# Enter your API token when prompted
```

> **Note**: Method A is recommended for automation because `hcloud context create` requires interactive input and cannot be piped.

### 4. SSH Key Pair

```bash
ls ~/.ssh/id_rsa.pub
```

**If missing**, generate with:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 5. SSH Key Uploaded to Hetzner

```bash
hcloud ssh-key list
```

**If empty**, upload with:

```bash
hcloud ssh-key create --name my-key --public-key-from-file ~/.ssh/id_rsa.pub
```

### 6. Test Authentication

```bash
hcloud server-type list
```

**If this fails**: Token may be invalid or expired. Create a new one.

---

## Server Profiles

| Profile | Server Type | vCPU | RAM | Storage | Monthly Cost |
|---------|-------------|------|-----|---------|--------------|
| `coolify` | CAX11 (ARM) | 2 | 4GB | 40GB | ~$4 |
| `kasm` | CAX21 (ARM) | 4 | 8GB | 80GB | ~$8 |
| `both` | CAX31 (ARM) | 8 | 16GB | 160GB | ~$16 |

<details>
<summary><strong>x86 Alternatives</strong></summary>

| Profile | Server Type | vCPU | RAM | Storage | Monthly Cost |
|---------|-------------|------|-----|---------|--------------|
| `coolify` | CX22 | 2 | 4GB | 40GB | ~$5 |
| `kasm` | CX32 | 4 | 8GB | 80GB | ~$10 |
| `both` | CX42 | 8 | 16GB | 160GB | ~$20 |

ARM (CAX) is recommended for better price/performance.

</details>

---

## Deployment Steps

### Step 1: Set Environment Variables

```bash
export HETZNER_LOCATION="nbg1"           # nbg1, fsn1, hel1, ash, hil
export HETZNER_SERVER_TYPE="cax21"       # See profiles above
export HETZNER_IMAGE="ubuntu-22.04"
export SERVER_NAME="my-server"
export SSH_KEY_NAME="my-key"
```

> **⚠️ ARM Server Location Compatibility**:
> ARM servers (CAX11, CAX21, CAX31, CAX41) are **only available in European locations**.
>
> | Location | ARM (CAX) | x86 (CX/CPX) |
> |----------|-----------|--------------|
> | nbg1 (Nuremberg) | ✅ Yes | ✅ Yes |
> | fsn1 (Falkenstein) | ✅ Yes | ✅ Yes |
> | hel1 (Helsinki) | ✅ Yes | ✅ Yes |
> | ash (Ashburn, US) | ❌ No | ✅ Yes |
> | hil (Hillsboro, US) | ❌ No | ✅ Yes |
>
> If you need US hosting, use x86 server types (CX22, CX32, CPX21, etc.).

<details>
<summary><strong>Location options</strong></summary>

| Code | Location | Region | ARM Available |
|------|----------|--------|---------------|
| `nbg1` | Nuremberg | Germany | ✅ Yes |
| `fsn1` | Falkenstein | Germany | ✅ Yes |
| `hel1` | Helsinki | Finland | ✅ Yes |
| `ash` | Ashburn | USA (Virginia) | ❌ No |
| `hil` | Hillsboro | USA (Oregon) | ❌ No |

</details>

### Step 2: Create Firewall

```bash
# Create firewall rules
hcloud firewall create --name my-firewall

# Allow SSH
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 22 --source-ips 0.0.0.0/0 --source-ips ::/0

# Allow HTTP/HTTPS
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 80 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 443 --source-ips 0.0.0.0/0 --source-ips ::/0

# Allow Coolify ports (if deploying Coolify)
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 8000 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 6001-6002 --source-ips 0.0.0.0/0 --source-ips ::/0

# Allow KASM ports (if deploying KASM)
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 8443 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 3389 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule my-firewall --direction in --protocol tcp --port 3000-4000 --source-ips 0.0.0.0/0 --source-ips ::/0
```

### Step 3: Validate and Create Server

**Validate ARM/location compatibility first**:
```bash
# Check if trying to use ARM server in US location
if [[ "$HETZNER_SERVER_TYPE" == cax* ]] && [[ "$HETZNER_LOCATION" == ash* || "$HETZNER_LOCATION" == hil* ]]; then
  echo "ERROR: ARM servers (CAX) are not available in US locations ($HETZNER_LOCATION)"
  echo ""
  echo "Options:"
  echo "  1. Switch to European location: nbg1, fsn1, or hel1"
  echo "  2. Switch to x86 server type: cx22, cx32, cpx21, cpx31"
  echo ""
  echo "Recommended fix:"
  echo "  export HETZNER_LOCATION=nbg1    # Switch to Europe"
  echo "  # OR"
  echo "  export HETZNER_SERVER_TYPE=cx22  # Switch to x86"
  exit 1
fi
echo "Server type $HETZNER_SERVER_TYPE is compatible with location $HETZNER_LOCATION"
```

**Create server**:
```bash
hcloud server create \
  --name "$SERVER_NAME" \
  --type "$HETZNER_SERVER_TYPE" \
  --image "$HETZNER_IMAGE" \
  --location "$HETZNER_LOCATION" \
  --ssh-key "$SSH_KEY_NAME" \
  --firewall my-firewall
```

### Step 4: Get Server IP

```bash
SERVER_IP=$(hcloud server ip "$SERVER_NAME")
echo "SERVER_IP=$SERVER_IP"
```

### Step 5: Wait for Server Ready

```bash
# Wait for SSH to be available (typically 30-60 seconds)
echo "Waiting for server to be ready..."
until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$SERVER_IP "echo connected" 2>/dev/null; do
  sleep 5
done
echo "Server is ready!"
```

### Step 6: Verify Connection

```bash
ssh root@$SERVER_IP "uname -a && free -h && df -h /"
```

### Step 7: Output for Downstream Skills

```bash
# Determine architecture for downstream skills (cloudflare-tunnel needs this)
if [[ "$HETZNER_SERVER_TYPE" == cax* ]]; then
  SERVER_ARCH="arm64"
else
  SERVER_ARCH="amd64"
fi

# Save to .env.local for downstream skills
echo "SERVER_IP=$SERVER_IP" >> .env.local
echo "SSH_USER=root" >> .env.local
echo "SSH_KEY_PATH=~/.ssh/id_rsa" >> .env.local
echo "SERVER_ARCH=$SERVER_ARCH" >> .env.local
echo "COOLIFY_SERVER_IP=$SERVER_IP" >> .env.local
echo "KASM_SERVER_IP=$SERVER_IP" >> .env.local

echo ""
echo "Server deployed successfully!"
echo "  IP: $SERVER_IP"
echo "  Arch: $SERVER_ARCH"
echo "  SSH: ssh root@$SERVER_IP"
```

---

## Verify Deployment

```bash
ssh root@$SERVER_IP "echo 'Hetzner server connected successfully'"
```

---

## Cleanup

**Warning**: This is destructive and cannot be undone.

```bash
# Delete server
hcloud server delete "$SERVER_NAME"

# Delete firewall
hcloud firewall delete my-firewall

# Optionally delete SSH key
# hcloud ssh-key delete my-key
```

---

## Operations

Troubleshooting, best practices, configuration variables, and cost snapshots are in `references/OPERATIONS.md`.

---

## Logging Integration

When performing infrastructure operations, log to the centralized system:

```bash
# After provisioning
log_admin "SUCCESS" "operation" "Provisioned Hetzner server" "id=$SERVER_ID provider=Hetzner"

# After destroying
log_admin "SUCCESS" "operation" "Deleted Hetzner server" "id=$SERVER_ID"

# On error
log_admin "ERROR" "operation" "Hetzner deployment failed" "error=$ERROR_MSG"
```

See `admin` skill's `references/logging.md` for full logging documentation.

---

## References

- [Hetzner Cloud Console](https://console.hetzner.cloud/)
- [hcloud CLI Documentation](https://github.com/hetznercloud/cli)
- [Server Types & Pricing](https://www.hetzner.com/cloud)
- [API Documentation](https://docs.hetzner.cloud/)

## Reference Appendices

### hetzner: references/OPERATIONS.md

# Hetzner Operations Reference

Troubleshooting, best practices, configuration variables, and cost snapshots for Hetzner Cloud.

## Contents
- Troubleshooting
- Best Practices
- Configuration Reference
- Cost Comparison

---

## Troubleshooting

<details>
<summary><strong>Server creation fails</strong></summary>

**Common causes**:
1. Invalid server type for location (check `hcloud server-type list --location $HETZNER_LOCATION`)
2. SSH key not found (check `hcloud ssh-key list`)
3. API token permissions (needs Read & Write)

**Fix**: Verify each component separately:
```bash
hcloud server-type list --location "$HETZNER_LOCATION"
hcloud ssh-key list
hcloud context active
```

</details>

<details>
<summary><strong>Cannot SSH to server</strong></summary>

**Checklist**:
1. Server is running: `hcloud server list`
2. Firewall allows port 22: `hcloud firewall describe my-firewall`
3. Correct SSH key used
4. Wait 30-60 seconds after creation

**Debug**:
```bash
# Check server status
hcloud server describe "$SERVER_NAME"

# Verify firewall
hcloud firewall describe my-firewall

# Try with verbose SSH
ssh -v root@$SERVER_IP
```

</details>

<details>
<summary><strong>Server type not available</strong></summary>

Some server types aren't available in all locations.

**Check availability**:
```bash
hcloud server-type list --location "$HETZNER_LOCATION"
```

**ARM servers (CAX)** are available in: nbg1, fsn1, hel1 (not US locations)

For US locations, use x86 types: CX22, CX32, etc.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

- Use ARM servers (CAX) for best price/performance
- Create dedicated firewall rules (don't use default)
- Use SSH keys (not password auth)
- Choose location closest to your users
- Use meaningful server names

</details>

<details>
<summary><strong>Never do</strong></summary>

- Share API tokens across projects
- Leave all ports open (use firewall)
- Use password authentication
- Delete resources without confirming

</details>

---

## Configuration Reference

<details>
<summary><strong>Environment variables</strong></summary>

```bash
# Required
HETZNER_API_TOKEN=...           # API token from console

# Deployment configuration
HETZNER_LOCATION=nbg1           # nbg1, fsn1, hel1, ash, hil
HETZNER_SERVER_TYPE=cax21       # Server type
HETZNER_IMAGE=ubuntu-22.04      # OS image
SERVER_NAME=my-server   # Server name
SSH_KEY_NAME=my-key      # SSH key name in Hetzner

# Outputs (set after deployment)
SERVER_IP=...                   # Public IP
SSH_USER=root                   # SSH username
SSH_KEY_PATH=~/.ssh/id_rsa      # Local private key path
```

</details>

<details>
<summary><strong>Server type reference</strong></summary>

**ARM (Ampere) - Best value**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| cax11 | 2 | 4GB | 40GB | ~$4 |
| cax21 | 4 | 8GB | 80GB | ~$8 |
| cax31 | 8 | 16GB | 160GB | ~$16 |
| cax41 | 16 | 32GB | 320GB | ~$30 |

**x86 (Intel/AMD)**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| cx22 | 2 | 4GB | 40GB | ~$5 |
| cx32 | 4 | 8GB | 80GB | ~$10 |
| cx42 | 8 | 16GB | 160GB | ~$20 |
| cx52 | 16 | 32GB | 320GB | ~$40 |

</details>

---

## Cost Comparison

_Prices below are snapshots and may change; verify in the Hetzner console._

| Provider | 4 vCPU ARM, 8GB | Monthly |
|----------|-----------------|---------|
| **Hetzner CAX21** | 4 vCPU ARM, 8GB | **~$8** |
| OCI Always Free | 4 OCPU ARM, 24GB | $0 |
| DigitalOcean | 4 vCPU, 8GB | $48 |
| AWS t4g.medium | 2 vCPU ARM, 4GB | ~$25 |

Hetzner offers the best paid option when OCI capacity is unavailable.
