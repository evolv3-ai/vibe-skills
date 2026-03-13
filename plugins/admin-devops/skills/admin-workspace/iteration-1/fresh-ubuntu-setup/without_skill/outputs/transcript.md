# Fresh Ubuntu Admin Setup Transcript (Without Skill)

**Date:** 2026-03-13
**Scenario:** Setting up a local machine administration / device profile system on a fresh Ubuntu machine
**Preferences:** uv for Python, pnpm for Node
**Mode:** Transcript only -- no commands were actually executed

---

## Phase 1: System Baseline

### 1.1 Update the system

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Install essential build tools

```bash
sudo apt install -y build-essential curl wget git jq unzip software-properties-common
```

**Rationale:** `jq` is needed for JSON profile manipulation, `curl`/`wget` for downloading installers, `git` for version control, `build-essential` for any native compilation needs.

---

## Phase 2: Python Environment (uv)

### 2.1 Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2.2 Verify installation and add to PATH

```bash
source $HOME/.local/bin/env  # or restart shell
uv --version
```

### 2.3 Install a default Python version via uv

```bash
uv python install 3.12
```

**Rationale:** uv manages Python versions and virtual environments without requiring pyenv or system python. It is fast, handles dependency resolution, and replaces pip, pip-tools, and virtualenv in one tool.

---

## Phase 3: Node Environment (pnpm)

### 3.1 Install Node.js via NodeSource (LTS)

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3.2 Install pnpm

```bash
corepack enable
corepack prepare pnpm@latest --activate
```

Or alternatively via standalone installer:

```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

### 3.3 Verify

```bash
node --version
pnpm --version
```

**Rationale:** `corepack` is the recommended way to manage Node package managers since Node 16.9+. If the system Node is too old or corepack is unavailable, the standalone installer is the fallback.

---

## Phase 4: Admin Directory Structure

### 4.1 Create the admin root

```bash
mkdir -p $HOME/.admin/{profiles,devices,logs/central,issues,scripts}
```

Resulting structure:

```
~/.admin/
  profiles/         # Device profile JSON files
  devices/          # Per-device logs and state
    <hostname>/
      logs.txt
  logs/
    central/
      operations.log
  issues/           # Issue tracking files
  scripts/          # Shared admin scripts
```

### 4.2 Create the satellite .env file

```bash
cat > $HOME/.admin/.env << 'EOF'
ADMIN_ROOT=$HOME/.admin
ADMIN_DEVICE=$(hostname)
ADMIN_PLATFORM=linux
EOF
```

This file serves as the entry point for any admin tooling to discover the admin root directory and the current device identity.

---

## Phase 5: Device Profile

### 5.1 Gather system information

```bash
DEVICE_NAME=$(hostname)
CPU_MODEL=$(lscpu | grep 'Model name' | sed 's/.*: *//')
CPU_CORES=$(nproc)
RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
ARCH=$(uname -m)
OS_VERSION=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
```

### 5.2 Create the device profile JSON

```bash
cat > $HOME/.admin/profiles/$DEVICE_NAME.json << ENDJSON
{
  "device": "$DEVICE_NAME",
  "platform": "linux",
  "os": "$OS_VERSION",
  "architecture": "$ARCH",
  "cpu": {
    "model": "$CPU_MODEL",
    "cores": $CPU_CORES
  },
  "ram_mb": $RAM_MB,
  "shell": "bash",
  "adminRoot": "$HOME/.admin",
  "preferences": {
    "packageManager": "apt",
    "pythonManager": "uv",
    "nodeManager": "pnpm",
    "defaultShell": "bash"
  },
  "capabilities": {
    "hasDocker": false,
    "hasSsh": false,
    "hasSystemd": true
  },
  "vault": {
    "enabled": false
  },
  "servers": [],
  "agents": [],
  "deployments": {},
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
ENDJSON
```

### 5.3 Create per-device log directory

```bash
mkdir -p $HOME/.admin/devices/$DEVICE_NAME
touch $HOME/.admin/devices/$DEVICE_NAME/logs.txt
```

---

## Phase 6: Admin Scripts

### 6.1 Profile loader script (`load-profile.sh`)

I would create `$HOME/.admin/scripts/load-profile.sh`:

```bash
#!/usr/bin/env bash
# load-profile.sh -- Load device profile into environment
# Usage: source load-profile.sh

# Priority 1: Environment variables
if [[ -n "$ADMIN_ROOT" && -n "$ADMIN_DEVICE" ]]; then
  : # Already set
# Priority 2: Satellite .env
elif [[ -f "$HOME/.admin/.env" ]]; then
  source "$HOME/.admin/.env"
  export ADMIN_ROOT ADMIN_DEVICE ADMIN_PLATFORM
# Priority 3: Defaults
else
  export ADMIN_ROOT="$HOME/.admin"
  export ADMIN_DEVICE="$(hostname)"
  export ADMIN_PLATFORM="linux"
fi

export ADMIN_PROFILE="$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json"

if [[ ! -f "$ADMIN_PROFILE" ]]; then
  echo "ERROR: Profile not found at $ADMIN_PROFILE" >&2
  return 1
fi

echo "Profile loaded: $ADMIN_DEVICE ($ADMIN_ROOT)"
```

### 6.2 Profile test script (`test-admin-profile.sh`)

I would create `$HOME/.admin/scripts/test-admin-profile.sh`:

```bash
#!/usr/bin/env bash
# test-admin-profile.sh -- Check if device profile exists and is valid

source "$(dirname "$0")/load-profile.sh" 2>/dev/null

if [[ -f "$ADMIN_PROFILE" ]]; then
  DEVICE=$(jq -r '.device' "$ADMIN_PROFILE")
  echo "{\"exists\":true,\"device\":\"$DEVICE\",\"adminRoot\":\"$ADMIN_ROOT\",\"platform\":\"$ADMIN_PLATFORM\"}"
else
  echo "{\"exists\":false,\"device\":\"$(hostname)\",\"adminRoot\":\"$ADMIN_ROOT\",\"platform\":\"linux\"}"
fi
```

```bash
chmod +x $HOME/.admin/scripts/*.sh
```

### 6.3 Logging script (`log-admin-event.sh`)

I would create `$HOME/.admin/scripts/log-admin-event.sh`:

```bash
#!/usr/bin/env bash
# log-admin-event.sh -- Log an admin operation
# Usage: source log-admin-event.sh; log_admin_event "message" "LEVEL"

log_admin_event() {
  local message="$1"
  local level="${2:-INFO}"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local device="${ADMIN_DEVICE:-$(hostname)}"
  local root="${ADMIN_ROOT:-$HOME/.admin}"
  local entry="[$timestamp] [$level] [$device] $message"

  # Central log
  echo "$entry" >> "$root/logs/central/operations.log"

  # Device log
  mkdir -p "$root/devices/$device"
  echo "$entry" >> "$root/devices/$device/logs.txt"
}
```

---

## Phase 7: Capability Detection and Profile Update

### 7.1 Detect and record capabilities

```bash
PROFILE="$HOME/.admin/profiles/$(hostname).json"

# Docker
if command -v docker &>/dev/null; then
  jq '.capabilities.hasDocker = true' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
fi

# SSH
if [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$HOME/.ssh/id_rsa" ]]; then
  jq '.capabilities.hasSsh = true' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
fi

# Systemd
if pidof systemd &>/dev/null; then
  jq '.capabilities.hasSystemd = true' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
fi
```

---

## Phase 8: Optional Extras

### 8.1 Docker (if needed later)

```bash
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
# Log out and back in for group to take effect
```

### 8.2 SSH key generation (if not present)

```bash
ssh-keygen -t ed25519 -C "$(hostname)@admin" -f $HOME/.ssh/id_ed25519 -N ""
```

### 8.3 Age encryption for vault (if secrets management is needed)

```bash
sudo apt install -y age
mkdir -p $HOME/.age
age-keygen -o $HOME/.age/key.txt
chmod 600 $HOME/.age/key.txt
```

---

## Phase 9: Shell Integration

### 9.1 Add admin loader to .bashrc

```bash
cat >> $HOME/.bashrc << 'EOF'

# Admin workspace
if [[ -f "$HOME/.admin/.env" ]]; then
  source "$HOME/.admin/.env"
  export ADMIN_ROOT ADMIN_DEVICE ADMIN_PLATFORM
fi
EOF
```

---

## Phase 10: Verification

### 10.1 Test the profile system

```bash
$HOME/.admin/scripts/test-admin-profile.sh
```

Expected output:

```json
{"exists":true,"device":"<hostname>","adminRoot":"/home/<user>/.admin","platform":"linux"}
```

### 10.2 Test logging

```bash
source $HOME/.admin/scripts/log-admin-event.sh
log_admin_event "Admin workspace initialized with uv (Python) and pnpm (Node)" "OK"
cat $HOME/.admin/logs/central/operations.log
```

### 10.3 Test tool managers

```bash
uv --version
pnpm --version
node --version
```

---

## Summary

| Step | What | Status |
|---|---|---|
| System update | `apt update && upgrade` | Would run |
| Build tools | `build-essential`, `curl`, `jq`, etc. | Would install |
| Python (uv) | Installed via official script | Would install |
| Node + pnpm | Node 22 LTS + corepack pnpm | Would install |
| Admin root | `~/.admin/` directory tree | Would create |
| Device profile | JSON at `~/.admin/profiles/<hostname>.json` | Would create |
| Admin scripts | `load-profile.sh`, `test-admin-profile.sh`, `log-admin-event.sh` | Would create |
| Capability detection | Docker, SSH, systemd checks | Would run |
| Shell integration | `.bashrc` sourcing of admin env | Would configure |
| Verification | Profile test, log test, tool version checks | Would verify |

**Total estimated time:** 3-5 minutes on a reasonably fast connection.
