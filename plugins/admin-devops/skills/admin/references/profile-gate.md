# Profile Gate Reference

The single source of truth for profile detection, creation, and troubleshooting.
All other files should point here rather than duplicating this content.

## Contents

- [How Profile Discovery Works](#how-profile-discovery-works)
- [Quick Test Commands](#quick-test-commands)
- [TUI Setup Interview](#tui-setup-interview)
- [Create Profile](#create-profile)
- [Load Profile](#load-profile)
- [Shared Admin Root (Windows + WSL)](#shared-admin-root-windows--wsl)
- [Scenarios](#scenarios)
- [Troubleshooting](#troubleshooting)

---

## How Profile Discovery Works

All scripts use a **satellite .env** pattern for profile discovery:

```
~/.admin/.env  (satellite - always at $HOME, contains 3 vars)
  └─ points to → $ADMIN_ROOT/profiles/$ADMIN_DEVICE.json
```

### Satellite .env Contents

```env
# Admin satellite config - points to centralized profile
# Do not store secrets here. See $ADMIN_ROOT/.env for credentials.
ADMIN_ROOT=/mnt/c/Users/Owner/.admin
ADMIN_DEVICE=WOPR3
ADMIN_PLATFORM=wsl

# Secrets Backend (v4.0+)
ADMIN_SECRETS_BACKEND=infisical
INFISICAL_ENVIRONMENT=prod
INFISICAL_AUTH_METHOD=cli-login
# Machine identity (headless/runtime environments):
INFISICAL_MACHINE_IDENTITY=wopr3-operator
```

For the full secrets configuration including multi-project support, see `references/secrets-architecture.md`.

### Resolution Order

1. `ADMIN_ROOT` env var (if already exported)
2. `~/.admin/.env` satellite file (primary mechanism)
3. Platform-based auto-detection (legacy fallback for pre-satellite setups)

### Why Satellite?

On WSL, the profile data lives on the Windows filesystem (e.g., `/mnt/c/Users/Owner/.admin`),
but agents check `$HOME` first. Without a satellite `.env` at `~/.admin/`, agents may:
- Assume no setup exists (no `~/.admin/` folder)
- Try to create a new profile in WSL's `$HOME`
- Override the skill's instructions

The satellite `.env` prevents this by making `~/.admin/` exist with a pointer to the real data.

---

## Quick Test Commands

**Bash (WSL/Linux/macOS):**
```bash
scripts/test-admin-profile.sh
```

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "scripts/Test-AdminProfile.ps1"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...","platform":"...",...}`

If `exists: false` — do not proceed with any task. Run the TUI interview below first.

---

## TUI Setup Interview

When profile does not exist, ask these questions using `AskUserQuestion` or equivalent.

### Q1: Storage Location (Required)

Ask: **"Will you use Admin on a single device or multiple devices?"**

| Option | Description |
|--------|-------------|
| Single device (Recommended) | Local storage at `~/.admin`. Simple, no sync needed. |
| Multiple devices | Cloud-synced folder (Dropbox, OneDrive, NAS). Profiles shared across machines. |

If "Multiple devices" selected, follow up: **"Enter the path to your cloud-synced folder"**
- Examples: `C:\Users\You\Dropbox\.admin`, `~/Dropbox/.admin`, `N:\Shared\.admin`

### Q2: Tool Preferences (Optional)

Ask: **"Set tool preferences now, or use defaults?"**

If yes, ask each (platform-aware):
- **Package manager (Linux-side):** apt (default on WSL/Linux) / brew (default on macOS) / dnf / pacman
- **Windows package manager (WSL only):** winget (default) / scoop / choco / none
- **Package manager (Windows native):** winget (default) / scoop / choco
- **Python manager:** uv (default) / pip / conda / poetry
- **Node manager:** npm (default) / pnpm / yarn / bun
- **Default shell:** pwsh (default on Windows) / bash (default on Linux) / zsh (default on macOS) / fish

### Q3: Inventory Scan (Optional)

Ask: **"Run a quick inventory scan to detect installed tools?"**
- Yes: Scans for git, node, python, docker, ssh, etc. and records versions
- No: Creates minimal profile, tools detected on first use

---

## Create Profile

Pass the user's answers to the setup script.

**Bash:**
```bash
scripts/new-admin-profile.sh \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "brew" \
  --py-mgr "uv" \
  --node-mgr "npm" \
  --shell-default "zsh" \
  --run-inventory
```

**PowerShell:**
```powershell
pwsh -NoProfile -File "scripts/New-AdminProfile.ps1" `
  -AdminRoot "C:/Users/You/.admin" `
  -PkgMgr "winget" `
  -PyMgr "uv" `
  -NodeMgr "npm" `
  -ShellDefault "pwsh" `
  -RunInventory
```

**Bash (WSL with Windows path + dual package managers):**
```bash
scripts/new-admin-profile.sh \
  --admin-root "N:\Dropbox\08_Admin" \
  --multi-device \
  --pkg-mgr "apt" \
  --win-pkg-mgr "winget" \
  --run-inventory
```

Add `-MultiDevice` (PowerShell) or `--multi-device` (Bash) if user selected multi-device setup.

### After Profile Created

1. Verify: Re-run `test-admin-profile.sh` or `Test-AdminProfile.ps1` → should return `exists: true`
2. Load profile (see next section)
3. **Now** proceed with the user's original task

---

## Load Profile

**Bash:**
```bash
source scripts/load-profile.sh
load_admin_profile
```

**PowerShell:**
```powershell
. "scripts/Load-Profile.ps1"
Load-AdminProfile -Export
```

---

## Shared Admin Root (Windows + WSL)

On machines with both Windows and WSL, the `.admin` folder is **shared** on the Windows filesystem. Both environments read/write to the same location.

| Environment | ADMIN_ROOT Path | Physical Location |
|-------------|-----------------|-------------------|
| Windows | `C:/Users/<USERNAME>/.admin` | `C:/Users/<USERNAME>/.admin` |
| WSL | `/mnt/c/Users/<USERNAME>/.admin` | `C:/Users/<USERNAME>/.admin` |
| Linux (standalone) | `~/.admin` | `/home/user/.admin` |
| macOS | `~/.admin` | `/Users/user/.admin` |

This ensures one device profile (not duplicated), unified logs, and a single source of truth.

---

## Scenarios

| Setup | Satellite .env location | ADMIN_ROOT points to |
|-------|------------------------|---------------------|
| Single device, native Linux | `~/.admin/.env` | `~/.admin` (same dir) |
| Single device, WSL | `~/.admin/.env` | `/mnt/c/Users/Owner/.admin` |
| Multi-device, any platform | `~/.admin/.env` | Network/cloud path |

---

## Troubleshooting

### Config Not Loading

**Bash:**
```bash
# Check config locations
ls -la "${ADMIN_ROOT:-$HOME/.admin}/.env"
ls -la .env.local

# Verify syntax
bash -n "${ADMIN_ROOT:-$HOME/.admin}/.env"
```

**PowerShell:**
```powershell
# Check config locations
Test-Path "$env:USERPROFILE\.admin\.env"
Test-Path ".env.local"

# View config content
Get-Content "$env:USERPROFILE\.admin\.env"
```

### Permission Issues

**Bash:**
```bash
# Fix ownership
chown -R $(whoami) "${ADMIN_ROOT:-$HOME/.admin}"

# Fix permissions
chmod 700 "${ADMIN_ROOT:-$HOME/.admin}"
chmod 600 "${ADMIN_ROOT:-$HOME/.admin}/.env"
chmod 755 "${ADMIN_LOG_PATH:-${ADMIN_ROOT:-$HOME/.admin}/logs}" \
          "${ADMIN_PROFILE_PATH:-${ADMIN_ROOT:-$HOME/.admin}/profiles}"
```

**PowerShell:**
```powershell
# Check access
$adminPath = "$env:USERPROFILE\.admin"
Get-Acl $adminPath | Format-List

# Grant full control to current user (if needed)
$acl = Get-Acl $adminPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $adminPath $acl
```

### Reset Configuration

**Bash:**
```bash
# Backup and reset
mv "${ADMIN_ROOT:-$HOME/.admin}" "${ADMIN_ROOT:-$HOME/.admin}.backup.$(date +%Y%m%d)"
# Re-run setup — admin skill will detect missing config
```

**PowerShell:**
```powershell
# Backup and reset
$backupName = ".admin.backup.$(Get-Date -Format 'yyyyMMdd')"
Move-Item "$env:USERPROFILE\.admin" "$env:USERPROFILE\$backupName"
# Re-run setup — admin skill will detect missing config
```

### Windows-Specific Issues

**PowerShell Version Too Old:**
```powershell
# Check version (need 7.x, not 5.1)
$PSVersionTable.PSVersion

# If 5.1, install PowerShell 7
winget install Microsoft.PowerShell

# Then run from pwsh.exe, not powershell.exe
```

**Execution Policy:**
```powershell
# Check policy
Get-ExecutionPolicy

# If Restricted, allow local scripts
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
