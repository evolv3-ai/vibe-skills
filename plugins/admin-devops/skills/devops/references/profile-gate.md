# Profile Gate (Supplementary Reference)

> **Note**: The critical profile gate instructions are in `SKILL.md`. This file provides
> supplementary details and load commands.

> **Path resolution**: These scripts live in the admin skill's `scripts/` directory.
> From commands/agents, use `${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/`.
> From SKILL.md contexts, derive the admin skill path from this file's location
> (sibling skill at `../../admin/scripts/`).

---

## Quick Test Commands

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/Test-AdminProfile.ps1"
```

**Bash (WSL/Linux/macOS):**
```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...",...}`

---

## Create Profile (TUI-First Approach)

If profile doesn't exist, use the TUI interview defined in `SKILL.md`:
1. Agent asks storage location (single/multi-device)
2. Agent asks tool preferences (optional)
3. Agent asks about inventory scan (optional)
4. Agent calls the setup script with answers:

**PowerShell:**
```powershell
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/New-AdminProfile.ps1" `
  -AdminRoot "$HOME/.admin" `
  -PkgMgr "winget" `
  -PyMgr "uv" `
  -NodeMgr "npm" `
  -ShellDefault "pwsh" `
  -RunInventory
```

**Bash:**
```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/new-admin-profile.sh" \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "brew" \
  --py-mgr "uv" \
  --node-mgr "npm" \
  --shell-default "zsh" \
  --run-inventory
```

Add `-MultiDevice` / `--multi-device` for cloud-synced storage.

---

## Load Profile

**PowerShell:**
```powershell
. "${CLAUDE_PLUGIN_ROOT}\skills\admin\scripts\Load-Profile.ps1"
Load-AdminProfile -Export
```

**Bash:**
```bash
source "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/load-profile.sh"
load_admin_profile
```

---

## WSL Note (Critical)

When running in WSL, the profile data lives on the Windows filesystem. A **satellite `.env`** at
`~/.admin/.env` points scripts to the correct location automatically:

```env
# ~/.admin/.env (created during setup)
ADMIN_ROOT=/mnt/c/Users/Owner/.admin
ADMIN_DEVICE=WOPR3
ADMIN_PLATFORM=wsl
```

All helper scripts read the satellite `.env` first - no `cmd.exe` calls needed.
