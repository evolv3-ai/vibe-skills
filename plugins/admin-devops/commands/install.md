---
name: install
description: Install tools, clone repos, or run custom installers using profile preferences
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - Task
argument-hint: "[tool-name | repo-url | script-path]"
---

# /install Command

Install software using the user's preferred package manager, clone repositories, or run custom installer scripts.

Uses a **subagent pipeline**: tool-installer → verify-agent → docs-agent.

## Pipeline Overview

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  /install    │ ──→ │ tool-installer│ ──→ │verify-agent│ ──→ docs-agent (log)
│  (this cmd)  │     │  (install)   │     │ (verify)   │
└─────────────┘     └──────────────┘     └────────────┘
   Profile gate        Run install          Verify, then
   + TUI interview     commands             log to ~/.admin/
```

- **This command**: Profile gate, determine what to install, TUI prompts
- **tool-installer agent**: Execute installation using the profile's preferred manager
- **verify-agent**: Confirm the install works and report findings to docs-agent
- **docs-agent**: Log the operation, update profile, write a session summary

## Step 1: Profile Gate

Load the profile to get user preferences. **HALT if no profile exists.**

**Bash (WSL/Linux/macOS):**
```bash
result=$("${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "No profile found. Run /setup-profile first."
    exit 1
fi
```

**PowerShell (Windows):**
```powershell
$result = pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/Test-AdminProfile.ps1" | ConvertFrom-Json
if (-not $result.exists) {
    Write-Host "No profile found. Run /setup-profile first."
    exit 1
}
```

## Step 2: Determine Install Type

If no argument provided, use TUI to ask:

Ask: **"What would you like to install?"**

| Option | Description |
|--------|-------------|
| Package/Tool | Install via package manager (winget, scoop, brew, apt) |
| Git Repository | Clone a repository |
| Custom Script | Run an installer script |

### Package Selection (if no argument)

Ask: **"Which tool would you like to install?"**

Common options: git, node, python, docker, rust, go, 7zip, ripgrep, fd, fzf, jq, or specify other.

## Step 3: Execute Pipeline

### 3A: Package Installation

**Stage 1 - tool-installer agent**: Spawn tool-installer with Task tool.

Provide tool-installer with:
- Tool name to install
- Profile path (`~/.admin/profiles/{hostname}.json`)
- Preferred package manager (from profile)
- Platform (from `~/.admin/.env`)

tool-installer will:
1. Check if already installed via profile's `tools` section
2. Construct and run the install command using preferred manager
3. Return: success/failure, version installed, install method

| Manager | Install Command |
|---------|-----------------|
| winget | `winget install <package>` |
| scoop | `scoop install <package>` |
| choco | `choco install <package> -y` |
| brew | `brew install <package>` |
| apt | `sudo apt install -y <package>` |
| npm | `npm install -g <package>` |
| pip/uv | `uv pip install <package>` or `pip install <package>` |

**Stage 2 - verify-agent**: If tool-installer succeeded, spawn verify-agent with Task tool.

Provide verify-agent with:
- Tool name
- Expected version (from tool-installer result)
- Verification mode: post-install

verify-agent will:
1. Check binary exists and is in PATH
2. Verify version matches
3. Test dependencies
4. Run functional test
5. Return: pass/fail with details

**Stage 3 - docs-agent**: Spawn docs-agent with Task tool to record results.

Provide docs-agent with:
- Log entry: `[OK] Installed {tool} v{version} via {manager}` (or `[ERROR]` if failed)
- Profile update: `.tools.{tool}` with version, manager, status, timestamp
- If verify-agent found issues: Create issue (category: install, tags: tool name)

### 3B: Repository Clone

**Stage 1** - Clone directly (no agent needed for git clone):
1. Ask for destination path (default: `~/projects/`)
2. Clone: `git clone <repo-url> <destination>`

**Stage 2** - Detect and install dependencies:
- `package.json` → Ask: "Install Node dependencies?" → tool-installer agent
- `requirements.txt` → Ask: "Install Python dependencies?" → tool-installer agent
- `Cargo.toml` → Ask: "Build Rust project?" → run `cargo build`

**Stage 3** - docs-agent: Log the clone operation.

### 3C: Custom Script

1. Validate script path exists
2. Ask for confirmation before running
3. Execute the script
4. Spawn verify-agent if the script installed a tool
5. Spawn docs-agent to log the operation

## Step 4: Report

After pipeline completes, summarize:

```
Install Complete: docker
══════════════════════════

  Installed:   docker v27.5.0 via apt
  Verified:    ✅ Binary OK, daemon running, hello-world passed
  Logged:      ~/.admin/logs/operations.log
  Profile:     Updated .tools.docker

  Next steps:
  - Add user to docker group: sudo usermod -aG docker $USER
  - Log out and back in for group change to take effect
```

Or on failure:

```
Install Failed: docker
══════════════════════════

  Install:     ✅ Package installed successfully
  Verify:      ❌ Docker daemon not running
    Error:     Cannot connect to Docker daemon
    Fix:       sudo systemctl start docker

  Issue created: issue_20260211_docker_daemon_not_running
  Logged:      ~/.admin/logs/operations.log
```

## Error Handling

- **Package not found**: tool-installer suggests alternatives or correct package name
- **Permission denied**: tool-installer suggests elevated privileges
- **Network error**: Check connectivity, suggest retrying
- **Already installed**: Report current version, offer to update instead
- **Verification failed**: verify-agent reports specific failure and fix suggestion
- **Pipeline stage failed**: Skip subsequent stages, report where it broke

## Examples

```
/install git
/install docker
/install https://github.com/user/repo
/install ~/scripts/setup-dev.sh
/install  # (interactive mode with TUI)
```
