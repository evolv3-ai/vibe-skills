# WSL Administration

_Consolidated from `skills/admin (wsl)` on 2026-02-02_

## Skill Body

# WSL Administration

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: WSL2 context, Ubuntu 24.04

---

## ⚠️ Profile Gate (MANDATORY - DO THIS FIRST)

**STOP. Before ANY operation, you MUST check for the profile. This is not optional.**

### Step 1: Check Profile Exists

```bash
# Use the helper script - it handles WSL path detection correctly
scripts/test-admin-profile.sh
```

Returns JSON: `{"exists":true,"path":"/mnt/c/Users/Owner/.admin/profiles/CASATEN.json",...}`

### Step 2: If Profile Missing → Run Setup

If `exists` is `false`:
```bash
scripts/setup-interview.sh
```

**DO NOT proceed with ANY task until profile exists.**

### Step 3: Load Profile

```bash
source scripts/load-profile.sh
load_admin_profile
```

### Step 4: After ANY Operation → Log It

```bash
source scripts/log-admin-event.sh
log_admin_event "Installed docker via apt" "OK"

# On failure, also create issue:
source scripts/new-admin-issue.sh
new_admin_issue "Docker installation failed" "install" "docker,apt"
```

## ⚠️ Critical: Profile Location

**The profile lives on the WINDOWS side, not in WSL home.**

A satellite `.env` at `~/.admin/.env` points to the real location:

```bash
# ~/.admin/.env contains:
#   ADMIN_ROOT=/mnt/c/Users/Owner/.admin
#   ADMIN_DEVICE=WOPR3
#   ADMIN_PLATFORM=wsl

# Read ADMIN_ROOT from satellite
source <(grep "^ADMIN_ROOT=" ~/.admin/.env)
PROFILE_PATH="$ADMIN_ROOT/profiles/$(hostname).json"
ls "$PROFILE_PATH"  # Found!
```

The satellite `.env` is created by `new-admin-profile.sh` during setup.
On WSL, `~/.admin/` contains **only** this `.env` file - all data lives at `ADMIN_ROOT`.

---

## Quick Start

The loader auto-detects WSL and uses the correct path:

```bash
source /path/to/admin/scripts/load-profile.sh
show_environment  # Verify detection
load_admin_profile
show_admin_summary
```

Output should show:
```
Type:        WSL (Windows Subsystem for Linux)
Win User:    {your-windows-username}
ADMIN_ROOT:  /mnt/c/Users/{username}/.admin
Profile:     /mnt/c/Users/{username}/.admin/profiles/{hostname}.json
Exists:      YES
```

---

## Critical Rules

### Always Do

- Keep profiles on the Windows side and access via `/mnt/c/Users/{WIN_USER}/.admin`
- Use Linux tools inside WSL (`apt`, `systemd`, `chmod`, `chown`)
- Convert Windows paths before use in WSL scripts
- Hand off `.wslconfig` changes to `admin (windows)`
- Restart WSL after `.wslconfig` changes (`wsl --shutdown` on Windows)

### Never Do

- Run `apt` from PowerShell
- Edit `.wslconfig` from inside WSL
- Use raw Windows paths in Linux scripts
- Edit Linux files with Windows tools that break line endings
- Assume PATH is shared between Windows and WSL

---

## Check WSL Config from Profile

```bash
# Profile has WSL section
jq '.wsl' "$PROFILE_PATH"

# Resource limits
jq '.wsl.resourceLimits' "$PROFILE_PATH"
# Returns: {"memory": "16GB", "processors": 8, "swap": "4GB"}

# WSL tools
jq '.wsl.distributions["Ubuntu-24.04"].tools' "$PROFILE_PATH"
```

---

## Package Installation (Profile-Aware)

### Python - Check Preference

```bash
PY_MGR=$(jq -r '.preferences.python.manager' "$PROFILE_PATH")
# Returns: "uv" or "pip" or "conda"

case "$PY_MGR" in
    uv)     uv pip install "$package" ;;
    pip)    pip install "$package" ;;
    conda)  conda install "$package" ;;
esac
```

### Node - Check Preference

```bash
NODE_MGR=$(jq -r '.preferences.node.manager' "$PROFILE_PATH")

case "$NODE_MGR" in
    npm)    npm install "$package" ;;
    pnpm)   pnpm add "$package" ;;
    yarn)   yarn add "$package" ;;
    bun)    bun add "$package" ;;
esac
```

### System Packages (apt)

```bash
sudo apt update
sudo apt install -y $package
```

---

## Docker Operations

### Check Docker from Profile

```bash
DOCKER_PRESENT=$(jq -r '.docker.present' "$PROFILE_PATH")
DOCKER_BACKEND=$(jq -r '.docker.backend' "$PROFILE_PATH")

if [[ "$DOCKER_PRESENT" == "true" && "$DOCKER_BACKEND" == "WSL2" ]]; then
    # Docker Desktop with WSL2 integration
    docker ps
fi
```

### Common Commands

```bash
docker ps                    # List running
docker images               # List images
docker logs <container>     # View logs
docker exec -it <c> bash    # Shell into container
docker-compose up -d        # Start compose stack
```

---

## Path Conversions

Windows paths in profile need conversion:

```bash
# Profile path: "C:/Users/Owner/.ssh"
# WSL path:     "/mnt/c/Users/Owner/.ssh"

win_to_wsl() {
    local win_path="$1"
    local drive=$(echo "$win_path" | cut -c1 | tr '[:upper:]' '[:lower:]')
    local rest=$(echo "$win_path" | cut -c3- | sed 's|\\|/|g')
    echo "/mnt/$drive$rest"
}

# Usage
SSH_PATH=$(jq -r '.paths.sshKeys' "$PROFILE_PATH")
WSL_SSH_PATH=$(win_to_wsl "$SSH_PATH")
```

---

## SSH to Servers

Use profile server data:

```bash
# Get server info
SERVER=$(jq '.servers[] | select(.id == "cool-two")' "$PROFILE_PATH")
HOST=$(echo "$SERVER" | jq -r '.host')
USER=$(echo "$SERVER" | jq -r '.username')
KEY=$(echo "$SERVER" | jq -r '.keyPath')

# Convert Windows key path
WSL_KEY=$(win_to_wsl "$KEY")

# Connect
ssh -i "$WSL_KEY" "$USER@$HOST"
```

Or use the loader helper:

```bash
source load-profile.sh
load_admin_profile
ssh_to_server "cool-two"  # Auto-converts paths
```

---

## Update Profile from WSL

After installing a tool in WSL:

```bash
# Read profile
PROFILE=$(cat "$PROFILE_PATH")

# Update WSL tools section
PROFILE=$(echo "$PROFILE" | jq --arg ver "$(node --version)" \
    '.wsl.distributions["Ubuntu-24.04"].tools.node.version = $ver')

# Save
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Resource Limits

Controlled by `.wslconfig` (Windows side). Profile tracks current settings:

```bash
jq '.wsl.resourceLimits' "$PROFILE_PATH"
```

To change, hand off to `admin (windows)`:

```bash
# Log handoff
echo "[$(date -Iseconds)] HANDOFF: Need .wslconfig change - increase memory to 24GB" \
    >> "$ADMIN_ROOT/logs/handoffs.log"
```

---

## Capabilities Check

```bash
# From profile
HAS_DOCKER=$(jq -r '.capabilities.hasDocker' "$PROFILE_PATH")
HAS_GIT=$(jq -r '.capabilities.hasGit' "$PROFILE_PATH")

if [[ "$HAS_DOCKER" == "true" ]]; then
    docker info
fi
```

---

## Issues Tracking

Check known issues before troubleshooting:

```bash
jq '.issues.current[]' "$PROFILE_PATH"
```

Add new issue:

```bash
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq '.issues.current += [{
    "id": "wsl-docker-'"$(date +%s)"'",
    "tool": "docker",
    "issue": "Docker socket not found",
    "priority": "high",
    "status": "pending",
    "created": "'"$(date -Iseconds)"'"
}]')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Common Tasks

### Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Python Package (Profile-Aware)

```bash
PY_MGR=$(get_preferred_manager python)
case "$PY_MGR" in
    uv)  uv pip install requests ;;
    *)   pip install requests ;;
esac
```

### Create Python Venv

```bash
PY_MGR=$(get_preferred_manager python)
if [[ "$PY_MGR" == "uv" ]]; then
    uv venv .venv
    source .venv/bin/activate
    uv pip install -r requirements.txt
else
    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
fi
```

---

## Scope Boundaries

| Task | Handle Here | Hand Off To |
|------|-------------|-------------|
| apt packages | ✅ | - |
| Docker containers | ✅ | - |
| Python/Node in WSL | ✅ | - |
| .bashrc/.zshrc | ✅ | - |
| systemd services | ✅ | - |
| .wslconfig | ❌ | admin (windows) |
| Windows packages | ❌ | admin (windows) |
| MCP servers | ❌ | admin (mcp) |
| Native Linux (non-WSL) | ❌ | admin (unix) |

---

## References

- `references/wslconfig-reference.md` - Full .wslconfig template
- `references/resource-recommendations.md` - Memory/CPU/swap sizing table
- `references/wsl-commands.md` - Distribution management commands
- `references/path-conversion.md` - Windows↔WSL path mapping
- `references/line-endings.md` - CRLF/LF handling
- `references/known-issues.md` - Common pitfalls and prevention
- `references/OPERATIONS.md` - Troubleshooting and diagnostics

## Reference Appendices

### wsl: references/OPERATIONS.md

# WSL Operations Reference

Extended operations for WSL administration: troubleshooting, Git setup, known issues prevention, setup checklist, and version snapshots.

## Contents
- Troubleshooting
- Git Configuration
- Known Issues Prevention
- Complete Setup Checklist
- Official Documentation
- Package Versions (Snapshot)

---

## Troubleshooting

### WSL Running Slow

```bash
# Check resources
free -h
df -h
top

# If resource constrained, request via handoff:
log_admin "HANDOFF" "handoff" "WSL slow - consider .wslconfig memory increase"
```

### Docker Not Working

```bash
# Check Docker Desktop is running (Windows side)
docker info

# If socket missing
ls -la /var/run/docker.sock
```

### Package Install Fails

```bash
# Update first
sudo apt update

# Check disk space
df -h

# Clear apt cache
sudo apt clean
sudo apt autoclean
```

### uv Not Found

```bash
# Check PATH
echo $PATH | grep ".local/bin"

# Add to .zshrc if missing
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## Git Configuration

Git should be configured with your credentials. Verify with:

```bash
git config --list              # View config
git config user.name           # Check username
git config user.email          # Check email
```

**Note:** If using WSL with Windows Git Credential Manager, the credential helper should be configured automatically.

---

## Known Issues Prevention

| Issue | Cause | Prevention |
|-------|-------|------------|
| `Get-Content not found` | Using PowerShell syntax | Use `cat` |
| Line ending corruption | CRLF/LF mismatch | Use `dos2unix` |
| Docker socket missing | Docker Desktop not running | Start from Windows |
| WSL slow/OOM | Resource limits | Request via admin (windows) |
| Permission denied | Wrong ownership | Use `chown`/`chmod` |

---

## Complete Setup Checklist

- [ ] WSL2 with Ubuntu 24.04 installed
- [ ] Shell configured (zsh or bash)
- [ ] uv installed at `~/.local/bin/uv`
- [ ] Docker Desktop integration working
- [ ] Git configured with credentials
- [ ] `$ADMIN_ROOT` directory structure created
- [ ] Environment variables configured in `.env`
- [ ] Central logs accessible via `$ADMIN_ROOT` mount

---

## Official Documentation

- **Ubuntu**: https://ubuntu.com/wsl
- **Docker WSL2**: https://docs.docker.com/desktop/wsl/
- **uv**: https://docs.astral.sh/uv/

---

## Package Versions (Snapshot, Verified 2025-12-08)

```json
{
  "wsl": "2.4.x",
  "ubuntu": "24.04.2 LTS",
  "node": "18.19.x",
  "uv": "0.9.x",
  "docker": "Docker Desktop WSL2"
}
```

### wsl: references/known-issues.md

# Known Issues Prevention (WSL)

## Issue 1: Editing .wslconfig from WSL
- Error: Changes don't take effect
- Prevention: Edit from Windows, then run `wsl --shutdown`

## Issue 2: Running apt from PowerShell
- Error: Command not found
- Prevention: Run inside WSL or use `wsl -e apt install ...`

## Issue 3: Windows paths in Linux scripts
- Error: Path not found
- Prevention: Convert paths with `wslpath`

## Issue 4: Line ending corruption
- Error: Scripts show `^M`
- Prevention: Use `dos2unix` or set Git `core.autocrlf` to input

## Issue 5: Memory not reclaimed
- Error: WSL VM keeps growing
- Prevention: Enable `autoMemoryReclaim=gradual` in `.wslconfig`

### wsl: references/line-endings.md

# Line Endings (CRLF/LF)

## Symptoms
- Scripts show `^M` characters
- Bash scripts fail with `bad interpreter` errors

## Prevention

### Configure Git

```bash
# Use LF in WSL
git config --global core.autocrlf input

# Optional: disable automatic conversion
git config --global core.autocrlf false
```

### Convert Existing Files

```bash
# Convert file to LF
dos2unix script.sh
```

### wsl: references/path-conversion.md

# Path Conversion (Windows <-> WSL)

## Windows to WSL (PowerShell)

```powershell
function Convert-ToWslPath {
    param([string]$WindowsPath)
    $path = $WindowsPath -replace '\\', '/'
    $path = $path -replace '^([A-Za-z]):', '/mnt/$1'.ToLower()
    $path
}

# Usage
Convert-ToWslPath "D:\projects\myapp"
# Returns: /mnt/d/projects/myapp
```

## WSL to Windows (Bash)

```bash
# WSL to Windows path
wslpath -w /home/username/file.txt
# Returns: \\wsl$\Ubuntu-24.04\home\username\file.txt

# Windows to WSL path
wslpath -u 'C:\Users\Owner\Documents'
# Returns: /mnt/c/Users/Owner/Documents
```

## Path Mapping Table

| Windows Path | WSL Path |
|--------------|----------|
| `C:\Users\Owner` | `/mnt/c/Users/Owner` |
| `D:\projects` | `/mnt/d/projects` |
| `N:\Dropbox` | `/mnt/n/Dropbox` |
| `\\wsl$\Ubuntu\home\user` | `/home/user` |

### wsl: references/resource-recommendations.md

# Resource Recommendations (WSL)

| System RAM | WSL Memory | Processors | Swap |
|------------|------------|------------|------|
| 16GB | 8GB | 4 | 2GB |
| 32GB | 16GB | 8 | 4GB |
| 64GB | 24GB | 12 | 8GB |
| 128GB | 48GB | 16 | 16GB |

### wsl: references/wsl-commands.md

# WSL Commands Reference

## Distribution Management

```powershell
# List all distributions
wsl --list --verbose
wsl -l -v

# Set default distribution
wsl --set-default Ubuntu-24.04

# Run specific distribution
wsl -d Ubuntu-24.04

# Run as specific user
wsl -d Ubuntu-24.04 -u root

# Terminate specific distribution
wsl --terminate Ubuntu-24.04

# Shutdown all WSL
wsl --shutdown

# Unregister (delete) distribution
wsl --unregister Ubuntu-24.04
```

## Installation and Updates

```powershell
# Install WSL (first time)
wsl --install

# Install specific distribution
wsl --install -d Ubuntu-24.04

# Update WSL
wsl --update

# Check WSL version
wsl --version

# List available distributions
wsl --list --online
```

## Import/Export

```powershell
# Export distribution to tar
wsl --export Ubuntu-24.04 D:\backups\ubuntu-backup.tar

# Import distribution from tar
wsl --import Ubuntu-Custom D:\wsl\ubuntu-custom D:\backups\ubuntu-backup.tar

# Set imported distribution version to WSL2
wsl --set-version Ubuntu-Custom 2
```

## Run Commands

```powershell
# Run single command in WSL
wsl -d Ubuntu-24.04 -e bash -c "echo Hello from WSL"

# Run command and return to Windows
wsl -d Ubuntu-24.04 -- ls -la /home

# Run with specific working directory
wsl -d Ubuntu-24.04 --cd /home/user -- pwd
```

### wsl: references/wslconfig-reference.md

# .wslconfig Reference

## File Location

```
C:\Users\{USERNAME}\.wslconfig
```

PowerShell:
```powershell
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
```

## Complete Template

```ini
# Settings apply to all WSL 2 distributions

[wsl2]
# Memory - How much memory to assign to the WSL 2 VM
# Default: 50% of total memory on Windows or 8GB, whichever is less
memory=16GB

# Processors - How many processors to assign to the WSL 2 VM
# Default: Same number as Windows
processors=8

# Swap - How much swap space to add to the WSL 2 VM
# Default: 25% of available memory
swap=4GB

# Swap file path - Custom swap VHD path
# swapFile=C:\\temp\\wsl-swap.vhdx

# Page reporting - Enable/disable page reporting (memory release)
# Default: true
pageReporting=true

# Localhost forwarding - Enable localhost access from Windows to WSL
# Default: true
localhostForwarding=true

# Nested virtualization - Enable nested virtualization
# Default: true
nestedVirtualization=true

# Debug console - Enable output console for debug messages
# debugConsole=false

# GUI applications - Enable WSLg GUI support
# Default: true
guiApplications=true

# GPU support - Enable GPU compute support
# Default: true
# gpuSupport=true

# Firewall - Apply Windows Firewall rules to WSL
# Default: true
# firewall=true

# DNS tunneling - Enable DNS tunneling
# Default: true
# dnsTunneling=true

# Auto proxy - Use Windows HTTP proxy settings
# Default: true
# autoProxy=true

[experimental]
# Sparse VHD - Enable automatic compaction of WSL virtual hard disk
sparseVhd=true

# Auto memory reclaim - Reclaim cached memory
# Options: disabled, dropcache, gradual
autoMemoryReclaim=gradual

# Network mode - mirrored mirrors Windows networking
# networkingMode=mirrored
```
