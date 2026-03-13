# MCP Filesystem Server Diagnostic Transcript

**Date:** 2026-03-13
**Issue:** MCP server `filesystem` not responding in Claude Desktop
**Device:** WOPR3 (WSL2 Ubuntu 24.04 on Windows 11 Pro)
**Skill consulted:** `/home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/SKILL.md`
**Reference consulted:** `references/mcp.md` (includes embedded CONFIGURATION.md, INSTALLATION.md, TROUBLESHOOTING.md, diagnostics.md, known-issues.md)

---

## Step 1: Profile Gate (Mandatory First Step)

Per SKILL.md, every session must begin with a profile check. No exceptions.

**Command I would run:**
```bash
/home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/scripts/test-admin-profile.sh
```

**Expected output:** `{"exists":true,"device":"WOPR3","adminRoot":"/mnt/c/Users/Owner/.admin","platform":"linux"}`

**If `exists: false`:** Stop and run `/setup-profile` before proceeding. Cannot diagnose without a profile.

**If `exists: true`:** Proceed. Extract `ADMIN_ROOT` and `ADMIN_DEVICE` for use in later steps.

---

## Step 2: Task Qualification

Per SKILL.md Task Qualification section: "If the task involves remote servers/VPS/cloud, stop and hand off to devops. If the task is local machine administration, continue."

**Decision:** This is a local MCP server issue in Claude Desktop. It is local machine administration. Continue with the admin skill.

---

## Step 3: SimpleMem Query (Check Past Issues)

Per CLAUDE.md memory integration guidance: "Before debugging, check if this error was seen before."

**Command I would run (if SimpleMem available):**
```
memory_query: "MCP filesystem server not responding Claude Desktop"
```

**Purpose:** Check whether this exact issue has been diagnosed before and whether a known fix exists. SimpleMem is optional -- if unavailable, continue without it.

---

## Step 4: Locate the Claude Desktop Config File

Per `references/mcp.md` > CONFIGURATION.md, the config path from WSL is:

**Commands I would run:**
```bash
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
CONFIG_PATH="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/claude_desktop_config.json"
echo "Config path: $CONFIG_PATH"
ls -la "$CONFIG_PATH"
```

**Also check profile for the config path:**
```bash
ADMIN_ROOT="/mnt/c/Users/Owner/.admin"
jq '.mcp.configFile' "$ADMIN_ROOT/profiles/WOPR3.json"
```

**What I'm looking for:** Confirm the config file exists and is readable from WSL.

---

## Step 5: Validate Config JSON

Per `references/mcp.md` > Troubleshooting > Manual Information Collection > Config Validity:

**Command I would run:**
```bash
cat "$CONFIG_PATH" | jq .
```

**What I'm looking for:**
- Valid JSON (if `jq` fails, the config is corrupt -- restore from backup)
- Presence of a `filesystem` entry under `.mcpServers`
- Correct structure: `command`, `args` fields present

**If JSON is invalid:**
```bash
# Restore from most recent backup
BACKUP=$(ls -t "${CONFIG_PATH}.backup."* 2>/dev/null | head -1)
if [ -n "$BACKUP" ]; then
    cp "$BACKUP" "$CONFIG_PATH"
    echo "Restored from backup: $BACKUP"
fi
```

---

## Step 6: Inspect the Filesystem Server Entry

**Command I would run:**
```bash
cat "$CONFIG_PATH" | jq '.mcpServers.filesystem'
```

**What I'm looking for:**
- `command` field exists (should be `"npx"` or `"node"`)
- `args` array is correct (should include `"-y"`, `"@modelcontextprotocol/server-filesystem"`, and an allowed directory path)
- All paths are **absolute Windows paths** (e.g., `C:/Users/Owner/Documents`), not WSL paths
- No `"disabled": true` flag
- If using npx: `"command": "npx"` (not `"npx.cmd"` from WSL, but on Windows side it should resolve)

**Expected correct entry (per references/INSTALLATION.md):**
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:/Users/Owner/Documents"]
}
```

**Common problems at this step:**
- Relative paths instead of absolute paths (known-issues.md Issue 2)
- WSL paths (`/mnt/c/...`) instead of Windows paths (`C:/...`) in the config
- Missing `-y` flag causing npx to hang waiting for confirmation
- Backslashes instead of forward slashes in paths

---

## Step 7: Check System Environment (Node.js and npm)

Per `references/mcp.md` > TROUBLESHOOTING.md > System Environment:

**Commands I would run (from WSL, checking the Windows-side Node):**
```bash
# Check WSL-side Node (informational)
node --version
which node
npm --version

# Check Windows-side Node (this is what Claude Desktop uses)
cmd.exe /c "node --version" 2>/dev/null
cmd.exe /c "where node" 2>/dev/null
cmd.exe /c "npm --version" 2>/dev/null
cmd.exe /c "npm root -g" 2>/dev/null
```

**What I'm looking for:**
- Node.js 18+ on the **Windows side** (Claude Desktop runs as a Windows app)
- npm accessible from Windows PATH
- If Node is missing or below v18 on Windows, that explains the failure

---

## Step 8: PATH Analysis

Per `references/mcp.md` > TROUBLESHOOTING.md > PATH Analysis:

**Command I would run:**
```bash
cmd.exe /c "echo %PATH%" 2>/dev/null | tr ';' '\n' | grep -iE 'npm|node'
```

**What I'm looking for:**
- Windows PATH includes the Node.js installation directory
- Windows PATH includes the npm global directory
- If `npx` is the command, it must be resolvable from the Windows PATH that Claude Desktop inherits

---

## Step 9: Test the Server Manually

Per `references/mcp.md` > TROUBLESHOOTING.md > Test a Server Manually:

**Command I would run (from Windows side via cmd.exe):**
```bash
cmd.exe /c "npx -y @modelcontextprotocol/server-filesystem --help" 2>&1
```

**What I'm looking for:**
- Does the server binary download and execute?
- Any `spawn ENOENT` errors (command not found)
- Any permission errors
- Any network errors (if npx needs to download the package)
- If it hangs: the `-y` flag may be missing, or there's a network/proxy issue

---

## Step 10: Check Claude Desktop Logs

Per `references/mcp.md` > TROUBLESHOOTING.md > Check Claude Logs:

**Commands I would run:**
```bash
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
LOG_DIR="/mnt/c/Users/$WIN_USER/AppData/Roaming/Claude/logs"

# List available log files
ls -la "$LOG_DIR/"

# Check recent log entries for MCP errors
tail -50 "$LOG_DIR/main.log" 2>/dev/null
grep -iE 'mcp|filesystem|error|ENOENT|spawn|timeout' "$LOG_DIR"/*.log 2>/dev/null | tail -30
```

**What I'm looking for:**
- `spawn ENOENT` -- command not found (fix: use absolute path to node/npx)
- `EACCES` or permission denied -- path access issue
- `timeout` -- server started but did not respond to init handshake
- `JSON parse error` -- config file is malformed
- `not responding` or `disconnected` -- server crashed after startup

---

## Step 11: Check MCP Registry (if available)

Per `references/mcp.md` > Registry-First Approach:

**Command I would run:**
```bash
ADMIN_ROOT="/mnt/c/Users/Owner/.admin"
REGISTRY="$ADMIN_ROOT/registries/mcp-registry.json"
if [ -f "$REGISTRY" ]; then
    jq '.servers.filesystem // .mcpServers.filesystem // "NOT_FOUND"' "$REGISTRY"
else
    echo "Registry not found at $REGISTRY"
fi
```

**What I'm looking for:**
- Whether the filesystem server is tracked in the registry
- Its recorded status (`working`, `pending`, `broken`)
- Install method and version
- Last verified date

---

## Step 12: Diagnosis Summary and Remediation

Based on the findings from Steps 4-11, I would present a diagnosis organized by likelihood:

### Most Likely Causes (in order):

1. **Config JSON syntax error** -- Detected in Step 5. Fix: restore backup, re-add entry.

2. **`spawn ENOENT` (npx/node not in PATH)** -- Detected in Steps 7-8 and logs.
   Fix per TROUBLESHOOTING.md: use absolute path to the executable:
   ```json
   {
     "command": "C:/Program Files/nodejs/node.exe",
     "args": ["C:/Users/Owner/AppData/Roaming/npm/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js", "C:/Users/Owner/Documents"]
   }
   ```
   Or install globally: `npm install -g @modelcontextprotocol/server-filesystem`

3. **Wrong path format** -- WSL paths in config instead of Windows paths. Fix: convert all paths to `C:/...` format.

4. **Server disabled** -- `"disabled": true` in the config entry. Fix: remove the `disabled` field or set to `false`.

5. **Claude Desktop not restarted after config change** -- Per Critical Rules: "Restart the client after config changes." Fix: fully close and reopen Claude Desktop.

6. **Mixed install methods** -- Per known-issues.md Issue 3. Fix: pick one method (npx or global) and remove the other.

7. **Stale npx cache** -- npx cached an old/broken version. Fix:
   ```bash
   cmd.exe /c "npx clear-npx-cache" 2>/dev/null
   # or
   cmd.exe /c "npm cache clean --force"
   ```

### Remediation Workflow:

1. **Backup** the current config (per Critical Rules: "Backup client configs before editing")
2. **Apply the fix** identified from diagnosis
3. **Validate** the config JSON parses cleanly
4. **Restart** Claude Desktop completely
5. **Verify** the filesystem tools appear in Claude's tool list
6. **Update** the profile and registry with new status

---

## Step 13: Log the Diagnostic Operation

Per SKILL.md, logging is mandatory for every operation.

**Command I would run:**
```bash
source /home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/scripts/log-admin-event.sh
log_admin_event "MCP diagnostic: filesystem server not responding in Claude Desktop - [DIAGNOSIS RESULT]" "OK"
```

---

## Step 14: Store Findings in SimpleMem (if available)

Per CLAUDE.md memory integration: "Installation outcomes (success AND failure, with error details)" and "Issue resolutions and workarounds discovered."

**Command I would run (if SimpleMem available):**
```
memory_add:
  speaker: "admin:mcp-bot"
  text: "MCP filesystem server diagnosed on WOPR3: [root cause]. Fix: [fix applied]. Config path: [path]."
```

---

## Files and References Consulted

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill entry point, profile gate, task routing, logging requirements |
| `references/mcp.md` | MCP management hub (config locations, install patterns, troubleshooting, registry) |
| Embedded: `references/CONFIGURATION.md` | Config file locations and structure |
| Embedded: `references/INSTALLATION.md` | Install methods (npx, global, clone) |
| Embedded: `references/TROUBLESHOOTING.md` | Diagnostic script, manual collection, common problems |
| Embedded: `references/diagnostics.md` | Quick-reference symptom/fix table |
| Embedded: `references/known-issues.md` | Prevention checklist (3 known issues) |
| Embedded: `references/registry-schema.md` | Registry structure for tracking server status |
| Embedded: `references/client-configs.md` | Client config file locations |
| `CLAUDE.md` | Device profile (WOPR3), platform notes, SimpleMem conventions |
