# Device Profiles - v3.0

Device profiles provide **context-aware assistance** by tracking your installed tools, preferences, servers, and capabilities.

## Profile Discovery

All platforms use a **satellite .env** at `~/.admin/.env` to find the profile:

```
~/.admin/.env            ← Satellite (always at $HOME, per-device)
  # Bootstrap vars
  ADMIN_ROOT=<path>      ← Points to centralized data
  ADMIN_DEVICE=<name>    ← Device name (used for profile filename)
  ADMIN_PLATFORM=<os>    ← wsl/linux/macos/windows
    └─ resolves to → $ADMIN_ROOT/profiles/$ADMIN_DEVICE.json

  # Preference vars (per-device, no JSON parsing needed)
  ADMIN_PKG_MGR=apt          ← Linux-side package manager
  ADMIN_WIN_PKG_MGR=winget   ← Windows-side (WSL only, optional)
  ADMIN_PY_MGR=uv            ← Python manager
  ADMIN_NODE_MGR=npm         ← Node manager
  ADMIN_SHELL=zsh            ← Default shell
```

### Examples by Platform

| Platform | Satellite location | ADMIN_ROOT | Profile path |
|----------|-------------------|------------|-------------|
| Windows | `C:\Users\Owner\.admin\.env` | `C:\Users\Owner\.admin` | `...\profiles\WOPR3.json` |
| WSL | `/home/user/.admin/.env` | `/mnt/c/Users/Owner/.admin` | `.../profiles/WOPR3.json` |
| Linux/macOS | `~/.admin/.env` | `~/.admin` | `.../profiles/myhost.json` |
| Multi-device | `~/.admin/.env` | `/mnt/nas/.admin` | `.../profiles/myhost.json` |

On WSL, `~/.admin/` contains **only** the satellite `.env`. All data lives at `ADMIN_ROOT`.

### WSL Dual Package Managers

WSL devices have two package manager contexts:
- **Linux-side** (`ADMIN_PKG_MGR`): apt, dnf, pacman — manages Linux packages
- **Windows-side** (`ADMIN_WIN_PKG_MGR`): winget, scoop, choco — manages Windows packages

The profile JSON stores both under `preferences.packages` and `preferences.winPackages`.
The satellite `.env` stores both as flat vars for quick shell access without JSON parsing.

**Path translation**: Windows paths (e.g., `N:\Dropbox\08_Admin`) are automatically translated
to WSL paths (e.g., `/mnt/n/Dropbox/08_Admin`) during profile setup via `wslpath` or manual conversion.

## Schema Version

Current: **v3.0**

Schema file: `assets/profile-schema.json`

## Profile Structure

```json
{
  "schemaVersion": "3.0",
  "device": { },        // Hardware, OS, hostname
  "paths": { },         // Critical file locations
  "packageManagers": { }, // Available package managers
  "tools": { },         // Installed tools with full context
  "preferences": { },   // User choices - THE KEY INNOVATION
  "wsl": { },           // WSL config (Windows only)
  "docker": { },        // Docker setup
  "mcp": { },           // MCP server inventory
  "servers": [ ],       // Managed remote servers
  "deployments": { },   // .env.local file references
  "issues": { },        // Known problems
  "history": [ ],       // Action log
  "capabilities": { }   // Quick routing flags
}
```

## Key Sections

### preferences - Smart Adaptation

The `preferences` section enables the core value proposition: adapting instructions to your setup.

```json
"preferences": {
  "python": {
    "manager": "uv",
    "reason": "Fast, modern, replaces pip+venv+poetry"
  },
  "node": {
    "manager": "npm",
    "reason": "Default, bun for speed-critical scripts"
  },
  "packages": {
    "manager": "scoop",
    "reason": "Portable installs, good for dev tools"
  }
}
```

**Usage**: Before suggesting `pip install x`, check `profile.preferences.python.manager`. If it's `uv`, suggest `uv pip install x` instead.

### tools - Full Context

Each tool has rich metadata for AI guidance:

```json
"tools": {
  "uv": {
    "present": true,
    "version": "0.9.5",
    "installedVia": "cargo",
    "path": "C:/Users/Owner/.local/bin/uv.exe",
    "shimPath": null,
    "configPath": null,
    "lastChecked": "2025-12-14T00:00:00Z",
    "installStatus": "working",
    "notes": "PREFERRED Python package manager. Use instead of pip."
  }
}
```

**Key fields**:
- `path` / `shimPath`: Where to find the executable
- `installStatus`: `working`, `failed`, `pending`, `deprecated`
- `notes`: **AI guidance** - explicit instructions for this tool

### servers - Remote Management

```json
"servers": [
  {
    "id": "cool-two",
    "name": "COOL_TWO",
    "host": "85.239.242.228",
    "port": 22,
    "username": "root",
    "authMethod": "key",
    "keyPath": "C:/Users/Owner/.ssh/id_rsa_openssh",
    "provider": "contabo",
    "role": "coolify",
    "status": "active"
  }
]
```

**Usage**: Construct SSH commands from profile data instead of asking user every time.

### deployments - .env.local References

```json
"deployments": {
  "vibeskills-oci": {
    "envFile": "D:/vibeskills-demo/.env.local",
    "type": "coolify",
    "provider": "oci",
    "status": "active",
    "serverIds": ["cool-oci-1"]
  }
}
```

**Two-file architecture**: Profile stores device context, `.env.local` stores deployment secrets. Profile **references** env files to avoid duplication.

### capabilities - Quick Routing

```json
"capabilities": {
  "canRunPowershell": true,
  "canRunBash": true,
  "hasWsl": true,
  "hasDocker": true,
  "hasSsh": true,
  "mcpEnabled": true
}
```

**Usage**: Check capabilities before routing to specialist skills.

## Loading Profiles

### PowerShell

```powershell
. scripts/Load-Profile.ps1
Load-AdminProfile -Export
Show-AdminSummary

# Access data
$AdminProfile.preferences.python.manager  # "uv"
Get-AdminTool "docker"
Get-AdminServer -Role "coolify"
Get-AdminPreference "python"
Test-AdminCapability "hasWsl"
```

### Bash

```bash
source scripts/load-profile.sh
load_admin_profile
show_admin_summary

# Access data
get_preferred_manager python  # "uv"
get_admin_tool "docker"
get_admin_server role "coolify"
ssh_to_server "cool-two"
has_capability "hasWsl"
```

## Updating Profiles

After installing a tool:

```powershell
# PowerShell
$AdminProfile.tools["newtool"] = @{
    present = $true
    version = "1.0.0"
    installedVia = "scoop"
    path = "C:/Users/Owner/scoop/apps/newtool/current/newtool.exe"
    installStatus = "working"
    lastChecked = (Get-Date).ToString("o")
}
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

After encountering an issue:

```powershell
$AdminProfile.issues.current += @{
    id = "issue-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    tool = "python"
    issue = "Version conflict with system Python"
    priority = "high"
    status = "pending"
    created = (Get-Date).ToString("o")
}
```

## Migration

From older profile formats:

```powershell
# Preview
.\scripts\Migrate-Profile.ps1 -DryRun

# Execute
.\scripts\Migrate-Profile.ps1
```

## Best Practices

1. **Always load profile first** - Before any operation
2. **Check preferences** - Never assume pip/npm/etc.
3. **Use notes field** - Add AI guidance for tricky tools
4. **Track issues** - Avoid repeating failed approaches
5. **Keep history** - Log installations for debugging
6. **Reference env files** - Don't duplicate secrets in profile
