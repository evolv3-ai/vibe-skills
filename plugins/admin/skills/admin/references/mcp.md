# MCP Management

_Consolidated from `skills/admin (mcp)` on 2026-02-02_

## Skill Body

# MCP Server Management

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: Node.js 18+ (for most servers). MCP clients are optional.

---

## ⚠️ Profile Gate (MANDATORY - DO THIS FIRST)

**STOP. Before ANY operation, you MUST check for the profile. This is not optional.**

### Step 1: Check Profile Exists

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "scripts/Test-AdminProfile.ps1"
```

**Bash (WSL/Linux/macOS):**
```bash
scripts/test-admin-profile.sh
```

Returns JSON: `{"exists":true,"path":"...","device":"...",...}`

### Step 2: If Profile Missing → Run Setup

**PowerShell:**
```powershell
pwsh -NoProfile -File "scripts/Setup-Interview.ps1"
```

**Bash:**
```bash
scripts/setup-interview.sh
```

**DO NOT proceed with ANY MCP operation until profile exists.**

### Step 3: Load Profile & Log Operations

After ANY MCP operation (install, remove, scan), log it:

**PowerShell:**
```powershell
. "scripts/Log-AdminEvent.ps1"
Log-AdminEvent -Message "Installed MCP server: filesystem" -Level OK
```

**Bash:**
```bash
source scripts/log-admin-event.sh
log_admin_event "Installed MCP server: filesystem" "OK"
```

---

## Registry-First Approach

All MCP clients and servers are tracked in a central registry:

```
$ADMIN_ROOT/registries/mcp-registry.json
```

Use the scanner to detect clients and normalize configs:

```powershell
.\scripts\scan-mcp-clients.ps1
```

---

## Quick Start

1) Scan for MCP clients and build/update the registry:
```powershell
.\scripts\scan-mcp-clients.ps1
```

2) Inspect the registry:
```powershell
$registryPath = Join-Path $env:ADMIN_ROOT "registries\\mcp-registry.json"
Get-Content $registryPath | ConvertFrom-Json | Select-Object -ExpandProperty clients
```

3) Install a server for a specific client (Claude Desktop example):
```powershell
.\scripts\install-mcp-server.ps1 -Name "filesystem" -Command "npx" -Args @("-y","@modelcontextprotocol/server-filesystem","C:/Users/Owner/Documents")
```

---

## Scan MCP Clients

```powershell
# Detect known clients and normalize configs into the registry
.\scripts\scan-mcp-clients.ps1
```

If no clients are detected, the registry is still created and left empty until you install a client.

---

## Remove MCP Server

```powershell
.\scripts\remove-mcp-server.ps1 -Name "filesystem"
```

---

## Critical Rules

### Always Do

- Backup client configs before editing
- Use absolute paths for commands and args
- Restart the client after config changes
- Update the MCP registry after installs/removals

### Never Do

- Edit configs while the client is running
- Use relative paths in MCP server configs
- Mix npx and global installs for the same server
- Store live credentials inside any skill folder

## Profile-First Approach

MCP config and servers tracked in profile:

```powershell
# Config file location
$AdminProfile.mcp.configFile
# "C:/Users/Owner/AppData/Roaming/Claude/claude_desktop_config.json"

# Installed servers
$AdminProfile.mcp.servers | Format-Table
```

```bash
jq '.mcp' "$ADMIN_PROFILE_PATH"
```

---

## List MCP Servers

```powershell
$AdminProfile.mcp.servers.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Package = $_.Value.package
        Status = $_.Value.status
        Tools = $_.Value.toolCount
    }
}
```

Example output:
```
Name      Package                     Status   Tools
----      -------                     ------   -----
win-cli   D:/mcp/win-cli-mcp-server   working  12
coolify   @pashvc/mcp-server-coolify  working  50
```

---

## Config File Location

From profile:

```powershell
$configPath = $AdminProfile.mcp.configFile
# Or
$configPath = $AdminProfile.paths.claudeConfig

# Read current config
$config = Get-Content $configPath | ConvertFrom-Json
$config.mcpServers
```

---

## Install New MCP Server

### Step 1: Backup Config

```powershell
$configPath = $AdminProfile.mcp.configFile
$backup = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $configPath $backup
```

### Step 2: Add Server Entry

```powershell
$config = Get-Content $configPath | ConvertFrom-Json

# NPX pattern (most common)
$config.mcpServers | Add-Member -NotePropertyName "new-server" -NotePropertyValue @{
    command = "npx"
    args = @("-y", "@some/mcp-server")
}

# Save
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
```

### Step 3: Update Profile

```powershell
$AdminProfile.mcp.servers["new-server"] = @{
    name = "new-server"
    package = "@some/mcp-server"
    version = "1.0.0"
    command = "npx -y @some/mcp-server"
    configFile = $null
    environment = @{}
    status = "pending"
    toolCount = 0
    notes = "Just installed"
}

$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

### Step 4: Restart Claude Desktop

Close and reopen Claude Desktop, then verify tools appear.

### Step 5: Update Status

```powershell
$AdminProfile.mcp.servers["new-server"].status = "working"
$AdminProfile.mcp.servers["new-server"].toolCount = 15  # Count from Claude
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

---

## Installation Patterns

### NPX (Recommended)

```json
{
  "command": "npx",
  "args": ["-y", "@package/mcp-server"]
}
```

### Global npm

```json
{
  "command": "mcp-server-name"
}
```
Requires: `npm install -g @package/mcp-server`

### Local Clone

```json
{
  "command": "node",
  "args": ["D:/mcp/server-name/dist/index.js"]
}
```

### With Environment Variables

```json
{
  "command": "npx",
  "args": ["-y", "@package/mcp-server"],
  "env": {
    "API_KEY": "your-key",
    "BASE_URL": "https://api.example.com"
  }
}
```

---

## Troubleshooting

### Check Profile for Issues

```powershell
# Known MCP issues
$AdminProfile.issues.current | Where-Object { $_.tool -like "*mcp*" }
```

### Common Problems

| Error | Cause | Fix |
|-------|-------|-----|
| `spawn ENOENT` | Command not found | Check path, install globally |
| `Server not starting` | Config syntax | Validate JSON |
| `Tools not appearing` | Didn't restart | Close/reopen Claude |
| `Permission denied` | Path issue | Use absolute Windows paths |

### Diagnostics

```powershell
# Check Node
node --version

# Check npm global
npm list -g --depth=0

# Validate config JSON
$configPath = $AdminProfile.mcp.configFile
try {
    Get-Content $configPath | ConvertFrom-Json | Out-Null
    Write-Host "Config JSON valid"
} catch {
    Write-Host "Config JSON invalid: $_"
}
```

---

## Track MCP Issue

```powershell
$AdminProfile.issues.current += @{
    id = "mcp-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    tool = "mcp-server-name"
    issue = "Server fails to start - spawn ENOENT"
    priority = "high"
    status = "pending"
    created = (Get-Date).ToString("o")
}

$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

---

## Remove MCP Server

### From Claude Config

```powershell
$config = Get-Content $AdminProfile.mcp.configFile | ConvertFrom-Json
$config.mcpServers.PSObject.Properties.Remove("server-to-remove")
$config | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.mcp.configFile
```

### From Profile

```powershell
$AdminProfile.mcp.servers.PSObject.Properties.Remove("server-to-remove")
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

---

## References

- `references/registry-schema.md` - Registry structure and fields
- `references/client-configs.md` - Per-client config formats
- `references/installation-patterns.md` - npx vs global vs clone trade-offs
- `references/common-servers.md` - Popular MCP servers
- `references/diagnostics.md` - Troubleshooting and diagnostics
- `references/known-issues.md` - Common pitfalls and prevention
- `references/INSTALLATION.md` - Legacy install patterns (Claude Desktop)
- `references/CONFIGURATION.md` - Legacy config structure (Claude Desktop)
- `references/TROUBLESHOOTING.md` - Legacy fixes

## Reference Appendices

### mcp: references/CLI_TOOLS.md

# MCP CLI Tools on Windows

## Contents
- Desktop Commander
- Win-CLI
- Claude Code MCP
- Tool selection guide

---

## Desktop Commander (Primary for Local Work)

**Package**: `@anthropic-ai/desktop-commander`  
**Best for**: File operations, code editing, persistent sessions.

Example entry:

```json
{
  "mcpServers": {
    "desktop-commander": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/desktop-commander"]
    }
  }
}
```

Key features:
- Persistent process sessions
- Diff‑based code editing
- Interactive REPL support

---

## Win-CLI (SSH and Multi‑Shell)

**Best for**: SSH operations, remote servers, multiple shell types.

Example entry:

```json
{
  "mcpServers": {
    "win-cli": {
      "command": "node",
      "args": [
        "<MCP_ROOT>/win-cli-mcp-server/dist/index.js",
        "--config",
        "<MCP_ROOT>/win-cli-mcp-server/config.json"
      ]
    }
  }
}
```

Example `config.json`:

```json
{
  "shells": {
    "powershell": {
      "enabled": true,
      "command": "C:/Program Files/PowerShell/7/pwsh.exe",
      "args": ["-Command"]
    },
    "cmd": {
      "enabled": true,
      "command": "cmd.exe",
      "args": ["/c"]
    }
  },
  "ssh": {
    "connections": [
      {
        "id": "server-1",
        "host": "<server-ip>",
        "username": "<username>",
        "privateKeyPath": "C:/Users/<YourUsername>/.ssh/id_rsa"
      }
    ]
  }
}
```

Key features:
- Multiple shell support (PowerShell, CMD, Git Bash)
- Pre‑configured SSH connections
- Isolated shell sessions

---

## Claude Code MCP (Complex Multi‑File Tasks)

**Package**: `@anthropic-ai/claude-code-mcp`  
**Best for**: Complex refactoring, git workflows, multi‑file edits.

Example entry:

```json
{
  "mcpServers": {
    "claude-code-mcp": {
      "command": "node",
      "args": ["<MCP_ROOT>/claude-code-mcp/dist/index.js"],
      "env": {
        "CLAUDE_CLI_PATH": "C:/Users/<YourUsername>/AppData/Roaming/npm/claude.cmd"
      }
    }
  }
}
```

---

## Tool Selection Guide

| Task | Recommended Tool | Reason |
|------|-----------------|--------|
| Read/write files | Desktop Commander | Native file tools |
| Edit code blocks | Desktop Commander | Diff‑based edits |
| Run local commands | Desktop Commander | Better PATH handling |
| SSH to remote server | Win‑CLI | SSH support |
| Use specific shell | Win‑CLI | Multi‑shell support |
| Complex refactoring | Claude Code MCP | Multi‑file awareness |
| Git operations | Claude Code MCP | Git workflow support |

### mcp: references/CONFIGURATION.md

# Claude Desktop Configuration for MCP

## Contents
- Config locations
- Config structure
- Field reference
- Safe editing rules
- Minimal example
- Validation checks

---

## Config Locations

```
Windows: %APPDATA%/Claude/claude_desktop_config.json
macOS:   ~/Library/Application Support/Claude/claude_desktop_config.json
Linux:   ~/.config/Claude/claude_desktop_config.json
WSL:     /mnt/c/Users/<USERNAME>/AppData/Roaming/Claude/claude_desktop_config.json
```

PowerShell:
```powershell
$configPath = "$env:APPDATA/Claude/claude_desktop_config.json"
```

WSL/Bash:
```bash
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
CONFIG_PATH="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/claude_desktop_config.json"
```

---

## Config Structure

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": {
        "ENV_VAR": "value"
      },
      "disabled": false
    }
  }
}
```

---

## Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | Executable to run (node, npx, python, etc.) |
| `args` | Yes | Array of arguments passed to command |
| `env` | No | Environment variables for the server |
| `disabled` | No | Set `true` to disable without removing |

---

## Safe Editing Rules

- Close Claude Desktop before editing the config.
- Always create a timestamped backup first.
- Use absolute paths everywhere.
- From WSL, edit the Windows file but keep Windows paths (`C:/...`) inside JSON.
- Restart Claude Desktop after any change.

---

## Minimal Example

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:/Users/<YourUsername>/Documents"]
    }
  }
}
```

---

## Validation Checks

PowerShell:
```powershell
$config = Get-Content $configPath | ConvertFrom-Json
$config.mcpServers.Keys
```

WSL/Bash:
```bash
cat "$CONFIG_PATH" | jq '.mcpServers | keys'
```

If JSON parsing fails, restore the last backup.

### mcp: references/INSTALLATION.md

# MCP Server Installation

## Contents
- Prerequisites
- Recommended NPX install
- Global npm install
- Local clone install
- Python MCP servers
- Step‑by‑step workflow (PowerShell)
- Step‑by‑step workflow (WSL/Bash)
- WSL path conversion
- Common MCP servers

---

## Prerequisites

- Node.js 18+ in PATH (`node --version`)
- npm in PATH (`npm --version`)
- Claude Desktop installed and closed before edits
- WSL users: `jq` installed for JSON edits (`sudo apt install jq`)

---

## Recommended NPX Install (Default)

Use NPX when you want the latest version with minimal setup.

Example server entry:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "C:/Users/<YourUsername>/Documents"
      ]
    }
  }
}
```

Pros: no global install, auto‑updates.  
Cons: first run requires internet and can be slower.

---

## Global npm Install

Use global installs for faster startup or offline operation.

Install:

```powershell
npm install -g @modelcontextprotocol/server-filesystem
```

Config example:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": [
        "C:/Users/<YourUsername>/AppData/Roaming/npm/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js",
        "C:/Users/<YourUsername>/Documents"
      ]
    }
  }
}
```

Pros: faster startup, works offline.  
Cons: manual updates.

---

## Local Clone Install (Development/Customization)

Use this when you need to edit server source or pin a fork.

```powershell
cd $env:MCP_ROOT  # e.g., D:/mcp or C:/mcp
git clone https://github.com/org/mcp-server.git
cd mcp-server
npm install
npm run build
```

Config example:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["<MCP_ROOT>/mcp-server/dist/index.js"]
    }
  }
}
```

Pros: full control.  
Cons: manual updates and build steps required.

---

## Python MCP Servers

Example entry:

```json
{
  "mcpServers": {
    "python-server": {
      "command": "python",
      "args": ["-m", "mcp_server_package"],
      "env": {
        "PYTHONPATH": "<path/to/server>"
      }
    }
  }
}
```

---

## MCP Installation Workflow (PowerShell)

Copy this checklist and follow in order:

1. Check registry (optional): `Get-Content $env:MCP_REGISTRY | ConvertFrom-Json`
2. Backup config:
   ```powershell
   $configPath = "$env:APPDATA/Claude/claude_desktop_config.json"
   Copy-Item $configPath "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   ```
3. Install server (default NPX, use one method):
   ```powershell
   # Default: NPX
   # Alternative: npm install -g @org/mcp-server-name
   # Alternative: local clone in $env:MCP_ROOT
   ```
4. Add server to config (example for local clone):
   ```powershell
   $config = Get-Content $configPath | ConvertFrom-Json
   $config.mcpServers | Add-Member -NotePropertyName "server-name" -NotePropertyValue @{
       command = "node"
       args = @("$env:MCP_ROOT/mcp-server/dist/index.js")
   }
   $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
   ```
5. Log install using `log_admin` (from `admin`).
6. Restart Claude Desktop.
7. Verify tools appear in Claude.

---

## MCP Installation Workflow (WSL/Bash)

1. Get Windows config path:
   ```bash
   WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
   CONFIG_PATH="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/claude_desktop_config.json"
   ```
2. Backup config:
   ```bash
   cp "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
   ```
3. Install server (default NPX, use one method):
   ```bash
   # Default: NPX
   # Alternative: npm install -g @org/mcp-server-name
   # Alternative: local clone on Windows FS:
   MCP_ROOT="/mnt/c/mcp"
   cd "$MCP_ROOT" && git clone https://github.com/org/mcp-server.git
   ```
4. Add server to config with Windows paths:
   ```bash
   jq '.mcpServers["server-name"] = {
     "command": "node",
     "args": ["C:/mcp/mcp-server/dist/index.js"]
   }' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
   ```
5. Log install using `log_admin`.
6. Restart Claude Desktop:
   ```bash
   powershell.exe -Command "Stop-Process -Name 'Claude' -ErrorAction SilentlyContinue; Start-Process 'C:/Users/$WIN_USER/AppData/Local/Programs/Claude/Claude.exe'"
   ```
7. Verify tools appear in Claude.

---

## WSL Path Conversion

Claude Desktop runs on Windows, so all config paths must be Windows paths:

| WSL Path | Windows Path (for config) |
|----------|---------------------------|
| `/mnt/c/Users/user/...` | `C:/Users/user/...` |
| `/mnt/d/mcp/...` | `D:/mcp/...` |
| `$HOME/.ssh/id_rsa` | N/A (use Windows path) |

---

## Common MCP Servers

### Official servers

| Server | Package | Purpose |
|--------|---------|---------|
| Filesystem | `@modelcontextprotocol/server-filesystem` | File system access |
| GitHub | `@modelcontextprotocol/server-github` | GitHub API integration |
| GitLab | `@modelcontextprotocol/server-gitlab` | GitLab integration |
| Slack | `@modelcontextprotocol/server-slack` | Slack integration |
| Google Drive | `@modelcontextprotocol/server-gdrive` | Drive access |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | Database queries |
| SQLite | `@modelcontextprotocol/server-sqlite` | SQLite database |
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | Browser automation |
| Brave Search | `@modelcontextprotocol/server-brave-search` | Web search |
| Fetch | `@modelcontextprotocol/server-fetch` | HTTP requests |
| Memory | `@modelcontextprotocol/server-memory` | Persistent memory |
| Sequential Thinking | `@modelcontextprotocol/server-sequential-thinking` | Step‑by‑step reasoning |

### Community servers

| Server | Package/Repo | Purpose |
|--------|--------------|---------|
| Desktop Commander | `@anthropic-ai/desktop-commander` | File ops + terminals |
| Context7 | `context7-mcp` | Library documentation |
| SimpleMem | Self-hosted (HTTP) | Persistent semantic memory |
| Obsidian | Various | Notes integration |
| Notion | Various | Notion integration |

### mcp: references/REGISTRY.md

# MCP Registry Pattern

## Contents
- Why a registry
- Registry schema
- Update script (PowerShell)

---

## Why a Registry

Maintain a central JSON registry of installed MCP servers so you can:
- see what’s installed on a device
- track install method/version
- coordinate upgrades across Windows/WSL

---

## Registry Schema

```json
{
  "lastUpdated": "YYYY-MM-DDTHH:MM:SSZ",
  "mcpServers": {
    "desktop-commander": {
      "installed": true,
      "installDate": "YYYY-MM-DD",
      "installMethod": "npx",
      "version": "latest",
      "purpose": "File operations and persistent sessions",
      "configPath": null,
      "notes": "Primary tool for local file operations"
    }
  }
}
```

Template: `templates/mcp-registry.json`.

---

## Registry Update Script (PowerShell)

```powershell
function Update-McpRegistry {
    param(
        [string]$ServerName,
        [string]$InstallMethod,
        [string]$Version,
        [string]$Purpose,
        [string]$ConfigPath,
        [string]$Notes
    )

    $registryPath = $env:MCP_REGISTRY
    $registry = Get-Content $registryPath | ConvertFrom-Json

    $entry = @{
        installed = $true
        installDate = (Get-Date -Format "yyyy-MM-dd")
        installMethod = $InstallMethod
        version = $Version
        purpose = $Purpose
        configPath = $ConfigPath
        notes = $Notes
    }

    if ($registry.mcpServers.PSObject.Properties.Name -contains $ServerName) {
        $registry.mcpServers.$ServerName = $entry
    } else {
        $registry.mcpServers | Add-Member -NotePropertyName $ServerName -NotePropertyValue $entry
    }

    $registry.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath

    Write-Host "Updated registry: $ServerName" -ForegroundColor Green
}
```

### mcp: references/TROUBLESHOOTING.md

# MCP Diagnostics and Troubleshooting

## Contents
- Run diagnostics script
- Manual information collection
- Common problems and fixes
- Known issues prevention
- Setup checklist

---

## Run Diagnostics Script (Preferred)

Use the bundled script to collect full context:

```powershell
# Full system diagnostic
./scripts/diagnose-mcp.ps1

# Diagnose specific server
./scripts/diagnose-mcp.ps1 -ServerName "server-name"

# Save report
./scripts/diagnose-mcp.ps1 -OutputFile "mcp-report.md"

# JSON report
./scripts/diagnose-mcp.ps1 -Json -OutputFile "mcp-report.json"
```

Include the report in bug tickets.

---

## Manual Information Collection

### 1. System Environment

PowerShell:
```powershell
$PSVersionTable | Format-List
node --version
(Get-Command node).Source
npm --version
npm root -g
```

WSL/Bash:
```bash
echo "Shell: $SHELL"
echo "Bash version: $BASH_VERSION"
node --version
which node
npm --version
npm root -g
```

### 2. Config Validity

PowerShell:
```powershell
$configPath = "$env:APPDATA/Claude/claude_desktop_config.json"
Test-Path $configPath
Get-Content $configPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

WSL/Bash:
```bash
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
CONFIG_PATH="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/claude_desktop_config.json"
cat "$CONFIG_PATH" | jq .
```

### 3. PATH Analysis

PowerShell:
```powershell
$env:PATH -split ';' | Where-Object { $_ -like "*npm*" -or $_ -like "*node*" }
```

WSL/Bash:
```bash
echo "$PATH" | tr ':' '\n' | grep -E 'npm|node'
cmd.exe /c "echo %PATH%" 2>/dev/null | tr ';' '\n' | grep -iE 'npm|node'
```

### 4. Test a Server Manually

PowerShell:
```powershell
npx.cmd -y @modelcontextprotocol/server-filesystem --help
node "<MCP_ROOT>/server-name/dist/index.js" --help
```

WSL/Bash:
```bash
npx -y @modelcontextprotocol/server-filesystem --help
node "/mnt/c/mcp/server-name/dist/index.js" --help
```

### 5. Check Claude Logs

PowerShell:
```powershell
Get-ChildItem "$env:APPDATA/Claude/logs" -Recurse
Get-Content "$env:APPDATA/Claude/logs/main.log" -Tail 50
Select-String -Path "$env:APPDATA/Claude/logs/*.log" -Pattern "mcp|MCP|error|ENOENT"
```

WSL/Bash:
```bash
LOG_DIR="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/logs"
tail -50 "$LOG_DIR/main.log"
grep -iE 'mcp|error|ENOENT' "$LOG_DIR"/*.log
```

---

## Common Problems and Fixes

### MCP Server Not Starting

Symptoms: tools missing or server disabled.

PowerShell checklist:
```powershell
$config = Get-Content "$env:APPDATA/Claude/claude_desktop_config.json" | ConvertFrom-Json
$config.mcpServers.'server-name'
node "<MCP_ROOT>/server/dist/index.js" --help
node --version
cd "$env:MCP_ROOT/server" && npm install
```

Common fixes:
- Ensure `command` and path args exist.
- Use forward slashes in config paths.
- Restart Claude Desktop completely.

### "spawn ENOENT"

Cause: command executable not found.

Fix:
```powershell
$nodePath = (Get-Command node).Source
Write-Host "Use this path: $nodePath"
```

### Environment Variables Missing

Cause: malformed `env` block.

Fix:
```json
{
  "mcpServers": {
    "server": {
      "command": "node",
      "args": ["server.js"],
      "env": { "API_KEY": "your-key-here" }
    }
  }
}
```

### Works in Terminal but Not in Claude

Cause: different PATH/environment.

Fix: use absolute paths:
```json
{
  "command": "C:/Program Files/nodejs/node.exe",
  "args": ["C:/Users/<YourUsername>/AppData/Roaming/npm/node_modules/@org/server/dist/index.js"]
}
```

### Config Corrupted

Recovery:
```powershell
$configPath = "$env:APPDATA/Claude/claude_desktop_config.json"
$backups = Get-ChildItem "$env:APPDATA/Claude/*.backup.*" | Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName $configPath
```

---

## Known Issues Prevention

- Don’t edit config while Claude Desktop is running.
- Prefer NPX for quick setup; prefer global installs for offline use.
- After cloning a repo: always run `npm install && npm run build`.
- Use `npx.cmd` on Windows to avoid `spawn npx ENOENT`.

---

## Complete Setup Checklist

- [ ] Node.js 18+ installed and in PATH
- [ ] Claude Desktop installed
- [ ] Config file exists and is backed up
- [ ] MCP server installed (default NPX)
- [ ] Server added to config with absolute Windows paths
- [ ] Claude Desktop restarted
- [ ] Server tools visible in Claude
- [ ] Registry updated (if using)

### mcp: references/client-configs.md

# MCP Client Configs

## Known Clients (Example Locations)

- Claude Desktop: `%APPDATA%\Claude\claude_desktop_config.json`
- Cursor: `~/.cursor/mcp.json` (format varies)
- Claude Code CLI: `~/.claude/settings.json` (format varies)

## Notes
- Paths may differ by install method or OS.
- If a config path is missing, mark the client as `detected: false` and leave `configPath` empty in the registry.
- Prefer prompting the user for a config path rather than guessing when the file is not found.

### mcp: references/common-servers.md

# Common MCP Servers (Examples)

- @modelcontextprotocol/server-filesystem
- @modelcontextprotocol/server-memory
- @modelcontextprotocol/server-github
- @modelcontextprotocol/server-git
- @modelcontextprotocol/server-slack
- @modelcontextprotocol/server-notion
- @modelcontextprotocol/server-google-drive
- @modelcontextprotocol/server-postgres
- @modelcontextprotocol/server-sqlite
- @modelcontextprotocol/server-redis
- SimpleMem (self-hosted, HTTP transport) — persistent semantic memory
- @pashvc/mcp-server-coolify
- @pashvc/mcp-server-oci
- @pashvc/mcp-server-hetzner
- @pashvc/mcp-server-contabo
- @pashvc/mcp-server-cloudflare

### mcp: references/diagnostics.md

# Diagnostics

## Config JSON invalid
- Symptom: client fails to start MCP servers
- Fix: validate JSON (`Get-Content config | ConvertFrom-Json`)

## spawn ENOENT
- Symptom: server fails to start, command not found
- Fix: verify command path and install method

## Tools not appearing
- Symptom: MCP tools missing in client UI
- Fix: restart client after config changes

## Permissions errors
- Symptom: access denied to paths or sockets
- Fix: use absolute paths, verify permissions, avoid Windows paths in WSL configs

### mcp: references/installation-patterns.md

# Installation Patterns

## NPX (Recommended)
```json
{ "command": "npx", "args": ["-y", "@package/mcp-server"] }
```
Pros: always latest, no global install
Cons: slower startup, requires internet on first run

## Global npm
```json
{ "command": "mcp-server-name" }
```
Requires: `npm install -g @package/mcp-server`
Pros: faster startup, works offline
Cons: manual updates

## Local Clone
```json
{ "command": "node", "args": ["D:/mcp/server-name/dist/index.js"] }
```
Pros: full control, editable source
Cons: manual build and updates

## HTTP Transport (Remote/Self-Hosted)
```json
{ "type": "http", "url": "https://example.com/mcp", "headers": { "Authorization": "Bearer TOKEN" } }
```
Used for: cloud-hosted or self-hosted MCP servers (e.g., SimpleMem, remote APIs)
Pros: no local process, shared across devices, centrally managed
Cons: requires network, needs auth token

### mcp: references/known-issues.md

# Known Issues Prevention (MCP)

## Issue 1: Editing config while client is running
- Error: config is overwritten or ignored
- Prevention: close client before editing, then restart

## Issue 2: Relative paths in server configs
- Error: server fails to start
- Prevention: always use absolute paths

## Issue 3: Mixed install methods
- Error: server resolves to wrong version
- Prevention: stick to one method per server

### mcp: references/registry-schema.md

# MCP Registry Schema

The MCP registry is the source of truth for clients and servers.

Location:
```
$ADMIN_ROOT/registries/mcp-registry.json
```

## Top-level Fields
- `schemaVersion`: Registry schema version
- `lastUpdated`: ISO timestamp of last write
- `clients`: Known MCP clients and detection status
- `servers`: Normalized MCP server entries
- `installMethods`: Install patterns (npx, npm-global, local-clone)
- `syncHistory`: Audit trail of install/update/remove events

## Server Entry (Normalized)
```json
{
  "serverId": "filesystem",
  "name": "Filesystem MCP",
  "package": "@modelcontextprotocol/server-filesystem",
  "version": "0.6.2",
  "installMethod": "npx",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:/Users/Owner/Documents"],
  "env": {},
  "clients": {
    "claude-desktop": { "installed": true, "status": "working", "toolCount": 8 }
  },
  "lastVerified": "2025-01-31T12:00:00Z"
}
```
