# Profile Gate (Supplementary Reference)

> **Note**: The critical profile gate instructions are in `SKILL.md`. This file provides
> supplementary details and load commands.

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
```

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

---

## Create Profile (TUI-First Approach)

If profile doesn't exist, use the TUI interview defined in `SKILL.md`:
1. Agent asks storage location (single/multi-device)
2. Agent asks tool preferences (optional)
3. Agent asks about inventory scan (optional)
4. Agent calls the setup script with answers:

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
  -AdminRoot "$HOME/.admin" `
  -PkgMgr "winget" `
  -PyMgr "uv" `
  -NodeMgr "npm" `
  -ShellDefault "pwsh" `
  -RunInventory
```

Add `--multi-device` (Bash) or `-MultiDevice` (PowerShell) for cloud-synced storage.

**After setup completes**, the script writes:
- Profile JSON at `$ADMIN_ROOT/profiles/<hostname>.json`
- Satellite `.env` at `~/.admin/.env` (always in current user's `$HOME`)

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

## Scenarios

| Setup | Satellite .env location | ADMIN_ROOT points to |
|-------|------------------------|---------------------|
| Single device, native Linux | `~/.admin/.env` | `~/.admin` (same dir) |
| Single device, WSL | `~/.admin/.env` | `/mnt/c/Users/Owner/.admin` |
| Multi-device, any platform | `~/.admin/.env` | Network/cloud path |
