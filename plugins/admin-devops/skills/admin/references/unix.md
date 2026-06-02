# Unix Administration

_Consolidated from `skills/admin (unix)` on 2026-02-02_

## Contents

- [Profile Gate](#profile-gate)
- [Platform Detection](#platform-detection)
- [Package Management (Profile-Aware)](#package-management-profile-aware)
- [Python Commands (Profile-Aware)](#python-commands-profile-aware)
- [Node Commands (Profile-Aware)](#node-commands-profile-aware)
- [Services](#services)
- [SSH to Servers](#ssh-to-servers)
- [Update Profile](#update-profile)
- [Capabilities Check](#capabilities-check)
- [Scope Boundaries](#scope-boundaries)
- [References](#references)
- [Logging (Centralized)](#logging-centralized)
- [Linux (apt): Standard Workflow](#linux-apt-standard-workflow)
- [Linux (apt): Common Errors + Fixes](#linux-apt-common-errors--fixes)
- [Linux (systemd): Common Operations](#linux-systemd-common-operations)
- [macOS (Homebrew): Standard Workflow](#macos-homebrew-standard-workflow)
- [macOS (Homebrew): PATH Notes (Apple Silicon)](#macos-homebrew-path-notes-apple-silicon)
- [macOS (Homebrew): Services](#macos-homebrew-services)
- [macOS (Homebrew): Common Errors + Fixes](#macos-homebrew-common-errors--fixes)
- [Troubleshooting Checklist](#troubleshooting-checklist)

**Requires**: macOS or native Linux (NOT WSL)

---

## Profile Gate

Run the profile check before any operation. See `references/profile-gate.md` for full details.

```bash
scripts/test-admin-profile.sh
```

If `exists: false`, run the TUI setup interview (see profile-gate.md) before proceeding.

---

## Platform Detection

```bash
OS=$(uname -s)
case "$OS" in
    Darwin) echo "macOS" ;;
    Linux)  
        if grep -qi microsoft /proc/version 2>/dev/null; then
            echo "WSL - use references/wsl.md instead"
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
| WSL operations | ❌ | references/wsl.md |
| Windows operations | ❌ | references/windows.md |
| Server provisioning | ❌ | devops skill |

---

## Extended Operations (macOS / Linux)

---

## Logging (Centralized)

Prefer the `admin` logging functions:

- `admin/references/logging.md`

Quick examples:

```bash
log_admin_event "Installed package (pkg=<PKG>)" "OK" "installations.log"
log_admin_event "Updated system (method=apt)" "OK"
log_admin_event "Command failed (cmd=<CMD> exit=<CODE>)" "ERROR"
```

---

## Linux (apt): Standard Workflow

Standard apt commands (`update`, `install`, `remove`, `search`, `apt-mark hold`, `autoremove`/`clean`) work as expected. Two project-specific points:

**Identify distro/version first** (picks correct packages):

```bash
cat /etc/os-release
```

**Verify after install, then log** (one representative example):

```bash
sudo apt install -y <PKG>
apt-cache policy <PKG>
command -v <CMD> && <CMD> --version
log_admin_event "Installed package (pkg=<PKG> method=apt)" "OK" "installations.log"
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
log_admin_event "apt lock prevented update (path=/var/lib/dpkg/lock-frontend)" "ERROR"
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
log_admin_event "DNS resolution failed (host=deb.debian.org)" "ERROR"
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

Standard `systemctl` verbs (`status`/`start`/`stop`/`restart`/`enable`/`disable`) and `journalctl -u <SERVICE>` apply. The non-obvious one: **after editing a unit file, reload before restarting**, or your changes are ignored.

```bash
sudo systemctl daemon-reload
sudo systemctl restart <SERVICE>
```

---

## macOS (Homebrew): Standard Workflow

Standard `brew` verbs (`install`/`uninstall`/`upgrade`/`cleanup`/`pin`/`unpin`/`info`/`list`) work as documented. Two project-specific points:

**Install Homebrew if missing** (official installer, needs network):

```bash
/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
log_admin_event "Installed Homebrew (method=brew-install)" "OK" "installations.log"
```

**Verify after install, then log** (one representative example):

```bash
brew install <FORMULA>
brew --prefix <FORMULA>
command -v <CMD> && <CMD> --version
log_admin_event "Installed formula (formula=<FORMULA> method=brew)" "OK" "installations.log"
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

Some formulae provide background services via `brew services` (`list`/`start`/`stop`/`restart`). Log changes:

```bash
brew services start <FORMULA>
log_admin_event "Updated brew service (service=<FORMULA> action=start)" "OK" "system-changes.log"
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
log_admin_event "brew update failed (check=brew-doctor)" "ERROR"
```

---

## Troubleshooting Checklist

- Confirm platform (`uname -s`) and avoid WSL-only paths unless you are in WSL.
- If you detect WSL (`grep -qi microsoft /proc/version`), use `references/wsl.md`.
- Confirm tool path:
  - `command -v <CMD>`
  - `which <CMD>`
- For permissions issues:
  - `ls -la <PATH>`
  - `stat <PATH>`
- For services:
  - Linux: `systemctl status`, `journalctl -u`
  - macOS: `brew services list`
