# Unix Administration

_Consolidated from `skills/admin (unix)` on 2026-02-02_

## Skill Body

# Unix Administration (macOS + Linux)

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: macOS or native Linux (NOT WSL)

---

## ⚠️ Profile Gate (MANDATORY - DO THIS FIRST)

**STOP. Before ANY operation, you MUST check for the profile. This is not optional.**

### Step 1: Check Profile Exists

```bash
scripts/test-admin-profile.sh
```

Returns JSON: `{"exists":true,"path":"~/.admin/profiles/hostname.json",...}`

### Step 2: If Profile Missing → Run Setup

```bash
scripts/setup-interview.sh
```

**DO NOT proceed with ANY task until profile exists.**

### Step 3: Load Profile

```bash
source scripts/load-profile.sh
load_admin_profile
show_admin_summary
```

---

## Platform Detection

```bash
OS=$(uname -s)
case "$OS" in
    Darwin) echo "macOS" ;;
    Linux)  
        if grep -qi microsoft /proc/version 2>/dev/null; then
            echo "WSL - use admin (wsl) instead"
        else
            echo "Native Linux"
        fi
        ;;
esac
```

---

## Package Management (Profile-Aware)

### Check Preference

```bash
PKG_MGR=$(jq -r '.preferences.packages.manager' "$PROFILE_PATH")
```

### macOS (Homebrew)

```bash
# Install
brew install $package

# Update
brew upgrade $package

# List
brew list

# Search
brew search $package
```

### Linux (apt)

```bash
# Update index
sudo apt update

# Install
sudo apt install -y $package

# Upgrade all
sudo apt upgrade -y

# Search
apt search $package
```

---

## Python Commands (Profile-Aware)

```bash
PY_MGR=$(get_preferred_manager python)

case "$PY_MGR" in
    uv)     uv pip install "$package" ;;
    pip)    pip3 install "$package" ;;
    conda)  conda install "$package" ;;
esac
```

---

## Node Commands (Profile-Aware)

```bash
NODE_MGR=$(get_preferred_manager node)

case "$NODE_MGR" in
    npm)    npm install "$package" ;;
    pnpm)   pnpm add "$package" ;;
    yarn)   yarn add "$package" ;;
    bun)    bun add "$package" ;;
esac
```

---

## Services

### Linux (systemd)

```bash
# Status
sudo systemctl status $service

# Start/Stop/Restart
sudo systemctl start $service
sudo systemctl stop $service
sudo systemctl restart $service

# Enable/Disable on boot
sudo systemctl enable $service
sudo systemctl disable $service

# View logs
journalctl -u $service -f
```

### macOS (Homebrew services)

```bash
# List
brew services list

# Start/Stop
brew services start $service
brew services stop $service
brew services restart $service
```

---

## SSH to Servers

Use profile server data:

```bash
ssh_to_server "cool-two"  # Helper from load-profile.sh
```

Or manually:

```bash
SERVER=$(jq '.servers[] | select(.id == "cool-two")' "$PROFILE_PATH")
HOST=$(echo "$SERVER" | jq -r '.host')
USER=$(echo "$SERVER" | jq -r '.username')
KEY=$(echo "$SERVER" | jq -r '.keyPath')

ssh -i "$KEY" "$USER@$HOST"
```

---

## Update Profile

After installing a tool:

```bash
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq --arg ver "$(python3 --version | cut -d' ' -f2)" \
    '.tools.python.version = $ver | .tools.python.present = true')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Capabilities Check

```bash
has_capability "hasDocker" && docker info
has_capability "hasGit" && git --version
```

---

## Scope Boundaries

| Task | Handle Here | Route To |
|------|-------------|----------|
| Homebrew (macOS) | ✅ | - |
| apt (Linux) | ✅ | - |
| systemd services | ✅ | - |
| Python/Node | ✅ | - |
| WSL operations | ❌ | admin (wsl) |
| Windows operations | ❌ | admin (windows) |
| Server provisioning | ❌ | devops |

---

## References

- `references/OPERATIONS.md` - Common operations, troubleshooting

## Reference Appendices

### unix: references/OPERATIONS.md

# Unix Operations Reference

Extended operations for macOS and Linux administration (outside of WSL). This file is expanded in later phases; keep `SKILL.md` as the overview.

## Contents

- Platform Detection
- Logging (Centralized)
- Linux (apt): Standard Workflow
- Linux (apt): Common Errors + Fixes
- Linux (systemd): Common Operations
- macOS (Homebrew): Standard Workflow
- macOS (Homebrew): PATH Notes (Apple Silicon)
- macOS (Homebrew): Services
- macOS (Homebrew): Common Errors + Fixes
- Troubleshooting Checklist

---

## Platform Detection

```bash
uname -s
# Darwin → macOS
# Linux  → Linux (native). If in WSL, use admin (wsl).
```

WSL detection:

```bash
grep -qi microsoft /proc/version 2>/dev/null && echo "wsl"
```

If this returns `wsl`, use `admin (wsl)` instead of `admin (unix)`.

---

## Logging (Centralized)

Prefer the `admin` logging functions:

- `admin/references/logging.md`

Quick examples:

```bash
log_admin "SUCCESS" "installation" "Installed package" "pkg=<PKG>"
log_admin "SUCCESS" "operation" "Updated system" "method=apt"
log_admin "ERROR" "operation" "Command failed" "cmd=<CMD> exit=<CODE>"
```

---

## Linux (apt): Standard Workflow

Use these steps for Debian/Ubuntu systems.

### 0. Identify distro and version (for correct packages)

```bash
cat /etc/os-release
uname -a
```

### 1. Update package lists and upgrade

```bash
sudo apt update
sudo apt upgrade -y
```

If you changed sources recently:

```bash
sudo apt update --allow-releaseinfo-change
```

Log:

```bash
log_admin "SUCCESS" "operation" "Updated system packages" "method=apt"
```

### 2. Install packages

```bash
sudo apt install -y <PKG>
```

Verify install:

```bash
dpkg -l | rg -n "^ii\\s+<PKG>\\b" || true
apt-cache policy <PKG>
command -v <CMD> || true
<CMD> --version || true
```

Log:

```bash
log_admin "SUCCESS" "installation" "Installed package" "pkg=<PKG> method=apt"
```

### 3. Remove packages

```bash
sudo apt remove -y <PKG>
sudo apt autoremove -y
```

For config purge:

```bash
sudo apt purge -y <PKG>
```

Log:

```bash
log_admin "SUCCESS" "installation" "Removed package" "pkg=<PKG> method=apt"
```

### 4. Search packages

```bash
apt-cache search <TERM>
apt-cache show <PKG> | sed -n '1,120p'
```

### 5. Hold/unhold packages (pin versions)

```bash
sudo apt-mark hold <PKG>
apt-mark showhold
sudo apt-mark unhold <PKG>
```

### 6. Cleanup

```bash
sudo apt autoremove -y
sudo apt clean
```

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y <PKG>
sudo apt remove -y <PKG>
apt-cache policy <PKG>
```

---

## Linux (apt): Common Errors + Fixes

### Error: Could not get lock (another apt/dpkg process)

Symptoms:
- `Could not get lock /var/lib/dpkg/lock-frontend`
- `Unable to acquire the dpkg frontend lock`

Steps:

```bash
ps aux | rg -n \"apt|dpkg\" || true
sudo lsof /var/lib/dpkg/lock-frontend 2>/dev/null || true
sudo lsof /var/lib/dpkg/lock 2>/dev/null || true
```

If you confirm it’s a stuck process (not actively running upgrades), stop it carefully and retry:

```bash
sudo apt update
```

Log failures:

```bash
log_admin "ERROR" "operation" "apt lock prevented update" "path=/var/lib/dpkg/lock-frontend"
```

### Error: dpkg was interrupted

Symptoms:
- `dpkg was interrupted, you must manually run 'sudo dpkg --configure -a'`

Fix:

```bash
sudo dpkg --configure -a
sudo apt -f install
sudo apt update
sudo apt upgrade -y
```

### Error: Unmet dependencies / held broken packages

```bash
sudo apt --fix-broken install
sudo apt -f install
apt-mark showhold
```

If a package is held:

```bash
sudo apt-mark unhold <PKG>
sudo apt install -y <PKG>
```

### Error: Temporary failure resolving (DNS)

```bash
cat /etc/resolv.conf
ping -c 1 1.1.1.1 || true
ping -c 1 deb.debian.org || true
```

Log:

```bash
log_admin "ERROR" "operation" "DNS resolution failed" "host=deb.debian.org"
```

### Error: Release file changed / repository metadata changed

```bash
sudo apt update --allow-releaseinfo-change
```

### Error: Hash Sum mismatch

```bash
sudo rm -rf /var/lib/apt/lists/*
sudo apt clean
sudo apt update
```

---

## Linux (systemd): Common Operations

```bash
# Status and logs
sudo systemctl status <SERVICE>
sudo journalctl -u <SERVICE> --no-pager -n 200
sudo journalctl -u <SERVICE> -f

# Start/stop/restart
sudo systemctl start <SERVICE>
sudo systemctl stop <SERVICE>
sudo systemctl restart <SERVICE>

# Enable/disable at boot
sudo systemctl enable <SERVICE>
sudo systemctl disable <SERVICE>

# After editing unit files
sudo systemctl daemon-reload
sudo systemctl restart <SERVICE>

# Discover services
systemctl list-units --type=service --state=running
```

---

## macOS (Homebrew): Standard Workflow

```bash
# Verify platform
uname -s
# Darwin → macOS

# Verify brew
brew --version
command -v brew
brew config
```

### Install Homebrew (if missing)

Use the official installer. This requires network access.

```bash
/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
```

Log:

```bash
log_admin "SUCCESS" "installation" "Installed Homebrew" "method=brew-install"
```

### Update and upgrade

```bash
brew update
brew upgrade
brew cleanup
```

Log:

```bash
log_admin "SUCCESS" "operation" "Updated brew packages" "method=brew"
```

### Install and uninstall formulae

```bash
brew install <FORMULA>
brew uninstall <FORMULA>
brew list --formula
brew info <FORMULA>
```

Verify installed formula and binary:

```bash
brew --prefix <FORMULA>
command -v <CMD> || true
<CMD> --version || true
```

Log:

```bash
log_admin "SUCCESS" "installation" "Installed formula" "formula=<FORMULA> method=brew"
```

### Pin / unpin (freeze versions)

```bash
brew pin <FORMULA>
brew unpin <FORMULA>
brew list --pinned
```

---

## macOS (Homebrew): PATH Notes (Apple Silicon)

If `brew` is installed but not found, you almost always have a PATH issue.

Common locations:

- Apple Silicon: `/opt/homebrew/bin/brew`
- Intel: `/usr/local/bin/brew`

Check:

```bash
ls -la /opt/homebrew/bin/brew /usr/local/bin/brew 2>/dev/null || true
```

Recommended shell setup:

```bash
# Apple Silicon default
echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile
eval \"$(/opt/homebrew/bin/brew shellenv)\"
```

If your shell is bash:

```bash
echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.bash_profile
eval \"$(/opt/homebrew/bin/brew shellenv)\"
```

Re-check:

```bash
brew --version
```

---

## macOS (Homebrew): Services

Some formulae provide background services via `brew services`:

```bash
brew services list
brew services start <FORMULA>
brew services restart <FORMULA>
brew services stop <FORMULA>
```

Log:

```bash
log_admin "SUCCESS" "system-change" "Updated brew service" "service=<FORMULA> action=start"
```

---

## macOS (Homebrew): Common Errors + Fixes

### Error: `brew` not found

Use the PATH guidance above and re-check:

```bash
command -v brew || true
```

### Error: `brew doctor` reports issues

Run:

```bash
brew doctor
```

Then apply the minimal changes it recommends (avoid random permission changes).

### Error: Xcode Command Line Tools missing

Symptoms:
- compilers missing, `git` missing, build errors

Fix:

```bash
xcode-select --install
```

### Error: Update/upgrade fails intermittently

```bash
brew update
brew doctor
brew config
```

Log failures:

```bash
log_admin "ERROR" "operation" "brew update failed" "check=brew-doctor"
```

---

## Troubleshooting Checklist

- Confirm platform (`uname -s`) and avoid WSL-only paths unless you are in WSL.
- If you detect WSL (`grep -qi microsoft /proc/version`), use `admin (wsl)`.
- Confirm tool path:
  - `command -v <CMD>`
  - `which <CMD>`
- For permissions issues:
  - `ls -la <PATH>`
  - `stat <PATH>`
- For services:
  - Linux: `systemctl status`, `journalctl -u`
  - macOS: `brew services list`
