---
name: provision
description: Provision a new server via cloud provider using TUI interview
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[provider]"
---

# /provision Command

Provision a new server on a cloud provider through an interactive TUI interview.

## Prerequisites

- Device profile must exist (run `/setup-profile` if missing)
- Provider CLI must be installed and configured
- SSH key pair must exist

## Workflow

### Step 1: Profile Gate

Verify profile exists and load it:

```bash
result=$("${CLAUDE_PLUGIN_ROOT}/../admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "HALT: No profile. Run /setup-profile first."
    exit 1
fi
```

### Step 2: Provider Selection

If no provider argument, use TUI to select:

Ask: "Which cloud provider would you like to use?"

| Option | Description | Skill |
|--------|-------------|-------|
| OCI (Oracle Cloud) | Free ARM64 tier available | oci |
| Hetzner | Best price/performance | hetzner |
| Contabo | Budget VPS, great value | contabo |
| DigitalOcean | Simple, reliable | digital-ocean |
| Vultr | Global data centers | vultr |
| Linode (Akamai) | Kubernetes focus | linode |

### Step 3: Deployment Purpose

Ask: "What will this server be used for?"

| Option | Recommended Specs |
|--------|-------------------|
| Coolify (PaaS) | 2-4 vCPU, 4-8GB RAM |
| KASM (VDI) | 4+ vCPU, 16-24GB RAM |
| Both Coolify + KASM | 4+ vCPU, 24GB RAM |
| General purpose | User specifies |
| Development/Testing | Smallest available |

### Step 4: Server Configuration

Based on provider and purpose, ask relevant questions:

#### Common Questions
- **Server name**: Unique identifier for this server
- **Region**: Data center location
- **SSH key**: Which key to use (list from profile)

#### Provider-Specific Questions
- **OCI**: Availability domain, compartment, OCPU count, memory
- **Hetzner**: Server type (CAX/CX), location
- **Contabo**: Product ID, region
- **DigitalOcean**: Droplet size, VPC
- **Vultr**: Plan, firewall group
- **Linode**: Type, firewall

### Step 5: Confirm and Provision

Show summary and ask for confirmation:

```
Server Configuration Summary:
- Provider: Hetzner
- Name: cool-three
- Type: CAX21 (4 vCPU, 8GB RAM)
- Location: nbg1 (Nuremberg)
- Purpose: Coolify
- SSH Key: my-key
- Estimated Cost: ~$8/month

Proceed with provisioning?
```

### Step 6: Execute Provisioning

Load the appropriate provider skill and execute.

Reference the provider's SKILL.md for exact commands:
- OCI: `skills/oci/SKILL.md`
- Hetzner: `skills/hetzner/SKILL.md`
- etc.

### Step 7: Update Profile

After successful provisioning, add server to profile:

```powershell
$AdminProfile.servers += @{
    id = "cool-three"
    name = "COOL_THREE"
    host = "192.168.1.100"
    port = 22
    username = "root"
    authMethod = "key"
    keyPath = "~/.ssh/id_rsa"
    provider = "hetzner"
    role = "coolify"
    status = "active"
    addedAt = (Get-Date).ToString("o")
}
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

### Step 8: Log and Report

Log the operation:
```bash
log_admin_event "Provisioned Hetzner server cool-three" "OK"
```

Report success with:
- Server IP address
- SSH connection command
- Next steps (deploy Coolify/KASM via `/deploy`)

## Provider CLI Requirements

| Provider | CLI | Install Check |
|----------|-----|---------------|
| OCI | oci | `oci --version` |
| Hetzner | hcloud | `hcloud version` |
| Contabo | cntb | `cntb --version` |
| DigitalOcean | doctl | `doctl version` |
| Vultr | vultr-cli | `vultr-cli version` |
| Linode | linode-cli | `linode-cli --version` |

If CLI not installed, offer to install it first.

## Error Handling

- **CLI not installed**: Offer to install via preferred package manager
- **Not authenticated**: Guide user through authentication
- **Capacity error (OCI)**: Suggest alternative region or wait
- **Quota exceeded**: Inform user of limits
- **Network error**: Suggest retry

## Tips

- OCI has a generous Always Free tier (4 OCPU, 24GB RAM ARM64)
- Hetzner CAX (ARM) offers better value than CX (x86)
- Contabo is cheapest but slower provisioning
- Always use SSH key authentication, never passwords
