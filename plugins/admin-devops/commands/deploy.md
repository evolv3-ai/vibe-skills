---
name: deploy
description: Deploy an application (Coolify, KASM) to a server via TUI interview
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[app] [server-id]"
---

# /deploy Command

Deploy an application to a server through an interactive TUI interview.

## Prerequisites

- Device profile with servers defined
- Target server provisioned and accessible
- SSH key configured for server

## Workflow

### Step 1: Profile Gate

Verify profile exists and has servers:

```bash
result=$("${CLAUDE_PLUGIN_ROOT}/../admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "HALT: No profile. Run /setup-profile first."
    exit 1
fi

# Check for servers
SERVERS=$(jq '.servers | length' "$PROFILE_PATH")
if [[ "$SERVERS" -eq 0 ]]; then
    echo "No servers in profile. Run /provision first."
    exit 1
fi
```

### Step 2: Application Selection

If no app argument, use TUI to select:

Ask: "Which application would you like to deploy?"

| Option | Description | Skill |
|--------|-------------|-------|
| Coolify | Self-hosted PaaS (Heroku alternative) | coolify |
| KASM Workspaces | Browser-based VDI | kasm |

### Step 3: Server Selection

If no server-id argument, list available servers:

Ask: "Which server should we deploy to?"

Display servers from profile:
```
ID         | Name       | Host          | Provider | Role    | Status
-----------|------------|---------------|----------|---------|--------
cool-two   | COOL_TWO   | 123.45.67.89  | contabo  | coolify | active
kasm-one   | KASM_ONE   | 98.76.54.32   | oci      | kasm    | active
new-server | NEW_SERVER | 111.22.33.44  | hetzner  | empty   | active
```

### Step 4: Application-Specific Questions

#### For Coolify

Ask the following (from coolify Step 0):

1. **Admin Email**: Email for Coolify root user
2. **Admin Password**: Password (8+ chars, uppercase, lowercase, number, symbol)
3. **Instance Domain**: Main Coolify URL (e.g., `coolify.example.com`)
4. **Wildcard Domain**: Base domain for apps (e.g., `*.example.com`)
5. **Use Cloudflare Tunnel?**: Yes/No
   - If Yes: Request CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID

#### For KASM

Ask the following (from kasm Step 0):

1. **Admin Email**: Email for KASM admin
2. **Admin Password**: Password (12+ chars)
3. **Swap Size**: Swap file size in GB (default: 8GB)
4. **Use Cloudflare Tunnel?**: Yes/No
   - If Yes: Request tunnel hostname

### Step 5: Confirm and Deploy

Show summary:

```
Deployment Summary:
- Application: Coolify
- Server: cool-two (123.45.67.89)
- Admin: admin@example.com
- Domain: coolify.example.com
- Cloudflare Tunnel: Yes

This will:
1. SSH to server
2. Install Docker if needed
3. Run Coolify installer
4. Configure Cloudflare Tunnel

Proceed with deployment?
```

### Step 6: Execute Deployment

Load the appropriate application skill and execute.

Reference the app's SKILL.md for exact steps:
- Coolify: `skills/coolify/SKILL.md`
- KASM: `skills/kasm/SKILL.md`

### Step 7: Update Profile

After successful deployment, update server role and add deployment:

```powershell
# Update server role
$serverIdx = $AdminProfile.servers.FindIndex({ param($s) $s.id -eq "cool-two" })
$AdminProfile.servers[$serverIdx].role = "coolify"
$AdminProfile.servers[$serverIdx].lastConnected = (Get-Date).ToString("o")

# Add deployment
$AdminProfile.deployments["coolify-production"] = @{
    type = "coolify"
    serverId = "cool-two"
    domain = "coolify.example.com"
    status = "active"
    deployedAt = (Get-Date).ToString("o")
}

$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

### Step 8: Log and Report

Log the operation:
```bash
log_admin_event "Deployed Coolify to cool-two" "OK"
```

Report success with:
- Access URL
- Admin credentials reminder
- Verification steps
- Next actions (e.g., add first project)

## Verification Checklist

After deployment, verify:

### Coolify
- [ ] UI accessible at configured domain
- [ ] Login with admin credentials works
- [ ] Localhost server shows "Connected"
- [ ] Can create a test project

### KASM
- [ ] UI accessible at `https://SERVER_IP` or tunnel hostname
- [ ] Login with admin credentials works
- [ ] At least 8 KASM containers running
- [ ] Can launch a workspace

## Error Handling

- **SSH connection failed**: Verify server is running, check SSH key
- **Docker install failed**: Check OS compatibility, try manual install
- **Port already in use**: Another service running, need to stop it
- **Certificate error**: DNS not configured, Cloudflare tunnel issue
- **Memory insufficient**: Server needs more RAM for the application

## Tips

- Coolify requires SSH key configuration for localhost management
- KASM needs significant RAM (4GB base + 2-4GB per session)
- Always configure HTTPS before exposing to internet
- Use Cloudflare Tunnel for secure access without opening ports
