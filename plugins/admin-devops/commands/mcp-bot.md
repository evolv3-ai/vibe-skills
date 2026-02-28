---
name: mcp-bot
description: Manage MCP servers - install, configure, diagnose, and troubleshoot
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[install | diagnose | list | remove | registry]"
---

# /mcp-bot Command

Manage Model Context Protocol (MCP) servers for Claude Desktop and Claude Code CLI.

## Registry Location

MCP server configurations are tracked in:
```
~/.admin/mcp-registry.json
```

Claude Desktop config location (from profile):
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`

## Workflow by Subcommand

### `/mcp-bot list` - List MCP Servers

Read the MCP registry and display status:

```
Name            | Package                     | Status  | Tools | Client
----------------|-----------------------------|---------| ------|--------
filesystem      | @anthropic/mcp-fs           | working | 5     | Desktop
coolify         | @pashvc/mcp-server-coolify  | working | 50    | Desktop
win-cli         | D:/mcp/win-cli-mcp-server   | error   | 12    | CLI
```

Status values:
- `working` - Server starts and tools are available
- `error` - Server fails to start
- `pending` - Newly added, not yet tested
- `disabled` - Manually disabled

### `/mcp-bot install` - Install New MCP Server

Use TUI to guide installation:

#### Q1: Installation Method
Ask: "How would you like to install the MCP server?"

| Option | Description |
|--------|-------------|
| NPX (Recommended) | Install via npx -y @package/name |
| Global npm | Install globally with npm install -g |
| Local clone | Clone repo and point to local path |
| Browse registry | Choose from known good servers |

#### Q2: Server Selection (if "Browse registry")
Ask: "Which MCP server would you like to install?"

| Option | Description |
|--------|-------------|
| filesystem | File system operations |
| github | GitHub API integration |
| postgres | PostgreSQL database |
| puppeteer | Browser automation |
| Other (specify) | Enter custom package name |

#### Q3: Client Selection
Ask: "Which client should use this server?"

| Option | Description |
|--------|-------------|
| Claude Desktop | Add to claude_desktop_config.json |
| Claude Code CLI | Add to project .mcp.json |
| Both | Add to both configurations |

Then run the installation:

**PowerShell:**
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-install-server.ps1" `
  -ServerName "filesystem" `
  -Package "@anthropic/mcp-fs" `
  -Method "npx" `
  -Client "desktop"
```

### `/mcp-bot diagnose` - Diagnose MCP Issues

Run comprehensive diagnostics:

**PowerShell:**
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-diagnose.ps1"
```

Checks:
1. Node.js version (18+ required)
2. npm global packages
3. Config file syntax validation
4. Each server's startup status
5. Environment variables
6. Permission issues

Output detailed report with:
- Passed checks
- Warnings
- Errors with suggested fixes

### `/mcp-bot remove` - Remove MCP Server

Use TUI to select server to remove:

Ask: "Which MCP server would you like to remove?"
(List installed servers)

Then:
1. Remove from Claude Desktop config
2. Remove from CLI config (if present)
3. Update registry
4. Optionally uninstall npm package

**PowerShell:**
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-remove-server.ps1" -ServerName "filesystem"
```

### `/mcp-bot registry` - Manage Registry

#### View Registry
```bash
cat ~/.admin/mcp-registry.json | jq .
```

#### Add to Registry
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-add-server.ps1" `
  -ServerName "custom-server" `
  -Package "@user/mcp-server" `
  -Description "My custom MCP server"
```

#### Sync Registry
Scan Claude Desktop config and update registry with current state:
```powershell
& "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-scan-clients.ps1"
```

## MCP Registry Format

```json
{
  "servers": {
    "filesystem": {
      "name": "filesystem",
      "package": "@anthropic/mcp-fs",
      "version": "1.0.0",
      "command": "npx -y @anthropic/mcp-fs",
      "configFile": null,
      "environment": {},
      "status": "working",
      "toolCount": 5,
      "clients": ["desktop"],
      "installedAt": "2026-02-04T12:00:00Z",
      "lastChecked": "2026-02-04T12:00:00Z",
      "notes": ""
    }
  },
  "clients": {
    "desktop": {
      "configPath": "C:/Users/You/AppData/Roaming/Claude/claude_desktop_config.json",
      "lastBackup": "2026-02-04T12:00:00Z"
    },
    "cli": {
      "configPath": null
    }
  }
}
```

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

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `spawn ENOENT` | Command not found | Check path, install globally |
| `Server not starting` | Config syntax | Validate JSON |
| `Tools not appearing` | Didn't restart | Close/reopen Claude |
| `Permission denied` | Path issue | Use absolute Windows paths |

## Tips

- Always backup config before changes (automatic with scripts)
- Use absolute paths for local clones
- Restart Claude Desktop after config changes
- Check `/mcp-bot diagnose` first when troubleshooting
- NPX pattern is most reliable for published packages
