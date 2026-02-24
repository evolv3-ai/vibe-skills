---
name: server-status
description: Show server inventory status from device profile
allowed-tools:
  - Read
  - Bash
argument-hint: "[server-id | --all | --provider <name>]"
---

# /server-status Command

Display server inventory status from the device profile.

## Workflow

### Step 1: Load Profile

```bash
result=$("${CLAUDE_PLUGIN_ROOT}/../admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "No profile found. Run /setup-profile first."
    exit 1
fi

PROFILE_PATH=$(echo "$result" | jq -r '.path')
```

### Step 2: Display Based on Arguments

#### No arguments or `--all`: Show All Servers

```bash
jq -r '.servers[] | [.id, .name, .host, .provider, .role, .status] | @tsv' "$PROFILE_PATH" | \
  column -t -s $'\t' -N "ID,Name,Host,Provider,Role,Status"
```

Output:
```
ID         Name       Host          Provider      Role     Status
---------  ---------  ------------  -----------   -------  ------
cool-two   COOL_TWO   123.45.67.89  contabo       coolify  active
kasm-one   KASM_ONE   98.76.54.32   oci           kasm     active
dev-box    DEV_BOX    111.22.33.44  hetzner       dev      stopped
```

#### Specific server ID: Show Details

```bash
jq '.servers[] | select(.id == "cool-two")' "$PROFILE_PATH"
```

Output:
```
Server: cool-two
========================================
Name:          COOL_TWO
Host:          123.45.67.89
Port:          22
Username:      root
Auth Method:   key
SSH Key:       ~/.ssh/id_rsa
Provider:      contabo
Role:          coolify
Domain:        coolify.example.com
Status:        active
Added:         2026-01-15T10:30:00Z
Last Connect:  2026-02-04T08:15:00Z
Notes:         Production Coolify server

Deployments:
- coolify-production (active)

SSH Command:
  ssh -i ~/.ssh/id_rsa root@123.45.67.89
```

#### Filter by provider: `--provider <name>`

```bash
jq -r '.servers[] | select(.provider == "hetzner") | [.id, .name, .host, .role, .status] | @tsv' "$PROFILE_PATH"
```

### Step 3: Optional Connectivity Check

Ask: "Would you like to check server connectivity?"

If yes, attempt SSH connection to each server:

```bash
for server in $(jq -r '.servers[].id' "$PROFILE_PATH"); do
    HOST=$(jq -r --arg id "$server" '.servers[] | select(.id == $id) | .host' "$PROFILE_PATH")
    KEY=$(jq -r --arg id "$server" '.servers[] | select(.id == $id) | .keyPath' "$PROFILE_PATH")

    timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -i "$KEY" "root@$HOST" "echo connected" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "$server: ✅ Connected"
    else
        echo "$server: ❌ Unreachable"
    fi
done
```

## Output Formats

### Summary Table (Default)

```
Server Inventory (4 servers)
============================

ID         | Host          | Provider | Role    | Status
-----------|---------------|----------|---------|--------
cool-two   | 123.45.67.89  | contabo  | coolify | active
kasm-one   | 98.76.54.32   | oci      | kasm    | active
dev-box    | 111.22.33.44  | hetzner  | dev     | stopped
test-srv   | 55.66.77.88   | vultr    | test    | active

Summary:
- Active: 3
- Stopped: 1
- By Provider: contabo (1), oci (1), hetzner (1), vultr (1)
```

### Detailed View (Single Server)

```
Server: cool-two
================

Basic Info:
  Name:          COOL_TWO
  Host:          123.45.67.89
  Port:          22
  Provider:      contabo
  Role:          coolify
  Status:        active

Authentication:
  Username:      root
  Auth Method:   key
  SSH Key:       ~/.ssh/id_rsa

Domains:
  Primary:       coolify.example.com
  Wildcard:      *.example.com

Timeline:
  Added:         2026-01-15T10:30:00Z
  Last Connect:  2026-02-04T08:15:00Z

Deployments:
  - coolify-production (Coolify v4.x) - active

Quick Commands:
  SSH:           ssh root@123.45.67.89
  Ping:          ping 123.45.67.89
```

### Provider Summary

```
Servers by Provider
===================

Contabo (1):
  cool-two - 123.45.67.89 (coolify) [active]

OCI (1):
  kasm-one - 98.76.54.32 (kasm) [active]

Hetzner (1):
  dev-box - 111.22.33.44 (dev) [stopped]

Vultr (1):
  test-srv - 55.66.77.88 (test) [active]
```

## Related Commands

- `/provision` - Add new server
- `/deploy` - Deploy application to server
- `/troubleshoot` - Track server issues

## Tips

- Run with connectivity check periodically to verify server health
- Update server status in profile when manually stopping/starting
- Use `--provider` filter when managing multi-cloud infrastructure
