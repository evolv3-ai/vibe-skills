# MCP Filesystem Server Diagnostic Transcript

**Problem:** MCP server `filesystem` is not responding in Claude Desktop.
**Date:** 2026-03-13
**Approach:** General knowledge of MCP servers and Claude Desktop configuration.

---

## Step 1: Locate and inspect the Claude Desktop MCP configuration

The Claude Desktop config file holds all MCP server definitions. On different platforms:

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux/WSL:** `~/.config/Claude/claude_desktop_config.json`

Since this is a WSL environment with Claude Desktop running on the Windows side, the config is likely at:

```
/mnt/c/Users/Owner/AppData/Roaming/Claude/claude_desktop_config.json
```

**Command I would run:**

```bash
cat "/mnt/c/Users/Owner/AppData/Roaming/Claude/claude_desktop_config.json"
```

**What I'm looking for:**
- Is there a `filesystem` entry under `mcpServers`?
- Is the `command` field correct (e.g., `npx` or a direct path to the server binary)?
- Are the `args` correct (e.g., `["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"]`)?
- Are any `env` variables set that might interfere?

A typical working configuration looks like:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/some/allowed/directory"],
      "env": {}
    }
  }
}
```

---

## Step 2: Validate JSON syntax of the config file

Malformed JSON is a common cause of MCP servers failing to load silently.

**Command I would run:**

```bash
python3 -c "import json; json.load(open('/mnt/c/Users/Owner/AppData/Roaming/Claude/claude_desktop_config.json'))" 2>&1
```

**What I'm looking for:**
- Any JSON parse errors (trailing commas, missing quotes, etc.)
- If this fails, the entire MCP config is broken and no servers will load.

---

## Step 3: Check if the MCP server package is installed and accessible

The filesystem MCP server is typically run via `npx`, which pulls from npm. If npm/node is missing or misconfigured, the server won't start.

**Commands I would run:**

```bash
# Check if node is available from the Windows side (Claude Desktop runs on Windows)
/mnt/c/Program\ Files/nodejs/node.exe --version

# Check if npx is available
/mnt/c/Program\ Files/nodejs/npx.cmd --version

# Or check from WSL if node is on PATH
which node && node --version
which npx && npx --version
```

**What I'm looking for:**
- Node.js >= 18 is required for most MCP servers.
- If `npx` is not found, the server cannot start.
- Since Claude Desktop runs on Windows, the Windows-side Node installation is what matters, not the WSL one.

---

## Step 4: Test running the MCP server manually

Start the server manually to see if it produces errors on startup.

**Command I would run:**

```bash
npx -y @modelcontextprotocol/server-filesystem /tmp/test-dir 2>&1
```

Or on the Windows side:

```powershell
npx -y @modelcontextprotocol/server-filesystem C:\Users\Owner\Documents
```

**What I'm looking for:**
- Does it start without errors?
- Does it output valid JSON-RPC on stdout?
- Common failures: npm registry unreachable, package version conflicts, missing dependencies.
- If it prints an error and exits, that's the root cause.

---

## Step 5: Check Claude Desktop logs for MCP errors

Claude Desktop writes MCP-related logs that show server startup attempts and failures.

**Log locations:**

- **macOS:** `~/Library/Logs/Claude/mcp*.log` and `~/Library/Logs/Claude/mcp-server-filesystem.log`
- **Windows:** `%APPDATA%\Claude\logs\mcp*.log`

**Commands I would run:**

```bash
# List available log files
ls -la "/mnt/c/Users/Owner/AppData/Roaming/Claude/logs/"

# Read the MCP-specific log (name may vary)
cat "/mnt/c/Users/Owner/AppData/Roaming/Claude/logs/mcp.log"

# Or look for filesystem-specific log
cat "/mnt/c/Users/Owner/AppData/Roaming/Claude/logs/mcp-server-filesystem.log"
```

**What I'm looking for:**
- `spawn ENOENT` errors (command not found)
- `EACCES` errors (permission denied)
- `ETIMEDOUT` or connection errors
- JSON parse errors from malformed server output
- "Server disconnected" or "Server failed to start" messages

---

## Step 6: Verify the allowed directories exist and are accessible

The filesystem server requires valid directory paths as arguments. If the paths don't exist or aren't accessible, the server may fail.

**Command I would run:**

```bash
# Extract the paths from the config and check each one
# (paths would come from Step 1 inspection)
ls -la /path/from/config/
```

**What I'm looking for:**
- Do the directories exist?
- Does the user running Claude Desktop have read/write permissions?
- If WSL paths are specified (e.g., `//wsl.localhost/Ubuntu/home/...`), are they accessible from Windows?
- If Windows paths are specified, are they valid from the context where the server runs?

---

## Step 7: Check for port or process conflicts

If a previous instance of the server is still running, it could cause issues.

**Commands I would run:**

```bash
# Check for any running MCP filesystem server processes
ps aux | grep "server-filesystem" | grep -v grep

# On Windows side (via PowerShell)
powershell.exe -Command "Get-Process -Name node -ErrorAction SilentlyContinue | Select-Object Id, CommandLine"
```

**What I'm looking for:**
- Orphaned server processes that might conflict.
- Multiple instances trying to bind to the same resources.

---

## Step 8: Check npm cache and network issues

If `npx` is used, it downloads the package each time (unless cached). Network issues can prevent this.

**Commands I would run:**

```bash
# Test npm registry connectivity
npm ping

# Clear npm cache if corrupted
npm cache verify

# Try installing the package explicitly
npm install -g @modelcontextprotocol/server-filesystem
```

**What I'm looking for:**
- Registry connectivity issues
- Corrupted cache entries
- Version resolution failures

---

## Step 9: Restart Claude Desktop

After any configuration changes, Claude Desktop must be fully restarted (not just closing the window).

**Steps:**
1. Fully quit Claude Desktop (check system tray on Windows).
2. On Windows: Task Manager -> End any remaining `Claude.exe` processes.
3. Relaunch Claude Desktop.
4. Check the MCP server status indicator (hammer icon in the chat input area).

---

## Step 10: Verify server is responding via the Claude Desktop UI

After restart, check the MCP status in Claude Desktop:

1. Look for the hammer/tools icon near the chat input box.
2. Click it to see the list of connected MCP servers.
3. The `filesystem` server should appear with a green/connected status.
4. If it shows an error, the error message will point to the specific failure.

---

## Common Root Causes (Summary)

| Cause | Symptom | Fix |
|---|---|---|
| Malformed JSON config | No MCP servers load | Fix JSON syntax |
| Node.js not installed / not on PATH | `spawn ENOENT` in logs | Install Node.js, ensure it's on system PATH |
| Wrong path in config | Server starts then errors | Fix directory paths in config |
| Package not found / network issue | `npx` timeout or 404 | Check network, install package globally |
| Stale process | Server appears hung | Kill orphaned processes, restart |
| Permissions | `EACCES` errors | Fix directory/file permissions |
| Claude Desktop not restarted | Old config still loaded | Fully quit and relaunch |
| WSL/Windows path mismatch | Path not found | Use Windows-native paths in config (since Claude Desktop is a Windows app) |

---

## Key Insight for WSL Users

Claude Desktop runs as a **Windows application**. The MCP server processes it spawns also run on Windows. This means:
- Paths in the config must be **Windows paths** (e.g., `C:\Users\Owner\Documents`), not WSL paths.
- The `command` (e.g., `npx`) must be resolvable from the **Windows PATH**, not the WSL PATH.
- If you want the filesystem server to access WSL files, use the UNC path `\\wsl.localhost\Ubuntu\home\...` in the config.
