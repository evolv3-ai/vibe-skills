# Admin Routing Guide

> **Legacy Notice (Alpha Consolidation)**: This guide references pre-consolidation
> skills (admin (windows), admin (wsl), admin-*-infra, devops (app reference)). The current
> routing model is two skills: **admin** (local) and **devops** (remote).
> Use `skills/admin/SKILL.md` for the authoritative routing rules.

Detailed routing rules for the admin orchestrator skill.

## Contents
- ⚠️ Environment Detection (Run First!)
- Routing Decision Flow
- Step 0: Admin Environment Check
- Keyword → Skill Mapping
- Context Validation
- Handoff Protocol
- Skill Availability Check
- Examples

---

## ⚠️ Environment Detection (MUST Run First)

**Before ANY routing logic, detect the execution environment:**

```bash
# Run this FIRST - determines WSL vs Windows Git Bash vs Native Linux
if grep -qi microsoft /proc/version 2>/dev/null; then
    ENV="wsl"
    ADMIN_ROOT="/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/.admin"
elif [[ "$OS" == "Windows_NT" || -n "$MSYSTEM" ]]; then
    ENV="windows-gitbash"
    ADMIN_ROOT="$HOME/.admin"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    ENV="macos"
    ADMIN_ROOT="$HOME/.admin"
else
    ENV="linux"
    ADMIN_ROOT="$HOME/.admin"
fi
echo "Detected: ENV=$ENV, ADMIN_ROOT=$ADMIN_ROOT"
```

### Quick Reference

| Session Started From | ENV Value | Key Indicator | Path Example |
|---------------------|-----------|---------------|--------------|
| WSL terminal | `wsl` | `/proc/version` has "microsoft" | `/mnt/c/Users/Owner/.admin` |
| Windows (PowerShell/CMD/Terminal) | `windows-gitbash` | `$OS=Windows_NT` | `/c/Users/Owner/.admin` |
| Native Linux | `linux` | No Microsoft, no Windows_NT | `/home/user/.admin` |
| macOS | `macos` | `uname -s` = "Darwin" | `/Users/user/.admin` |

### Critical Rules

1. **Claude Code ALWAYS uses bash** - even on Windows (via Git Bash/MINGW)
2. **Never run PowerShell syntax directly** - no `Test-Path`, `$env:VAR`, etc.
3. **To run PowerShell**: Use `pwsh.exe -Command "..."`
4. **WSL vs Git Bash paths**: `/mnt/c/` only works in WSL, use `C:/` or `/c/` in Git Bash

---

## Routing Decision Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     ADMIN ROUTING ENGINE                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  STEP 0a: DETECT ENVIRONMENT  │
              │  (wsl / windows-gitbash /     │
              │   linux / macos)              │
              │  → Sets $ENV and $ADMIN_ROOT  │
              └───────────────┬───────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  STEP 0b: Check Admin Env     │
              │  $ADMIN_ROOT/.env exists?     │
              │  $ADMIN_ROOT/logs/ exists?    │
              └───────────────┬───────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
        ┌───────────┐                 ┌───────────────┐
        │    YES    │                 │      NO       │
        │  Continue │                 │ Run First-Run │
        └─────┬─────┘                 │    Setup      │
              │                       └───────┬───────┘
              │                               │
              │◄──────────────────────────────┘
              │
              ▼
         ┌───────────────────┬───────────────────┐
         ▼                   ▼                   ▼
    ┌─────────────┐    ┌─────────┐        ┌─────────┐
    │ windows-    │    │   wsl   │        │  linux  │
    │ gitbash     │    │         │        │ /macos  │
    └──────┬──────┘    └────┬────┘        └────┬────┘
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TASK CLASSIFICATION                        │
└─────────────────────────────────────────────────────────────────┘
                              │
    ┌────────────┬────────────┼────────────┬────────────┐
    ▼            ▼            ▼            ▼            ▼
┌────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐
│ Server │ │ Windows  │ │WSL/Unix  │ │   MCP    │ │ Profile │
│  Task  │ │  System  │ │  System  │ │   Task   │ │/Logging │
└───┬────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘
    │           │            │            │            │
    ▼           ▼            ▼            ▼            ▼
┌────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐
│ admin- │ │  admin-  │ │  admin-  │ │  admin-  │ │  admin  │
│devops  │ │ windows  │ │ wsl/unix │ │   mcp    │ │ (self)  │
└───┬────┘ └──────────┘ └────┬─────┘ └────┬─────┘ └─────────┘
    │                        │
    │                        ├───────────────┐
    │                        ▼               ▼
    │                 ┌──────────┐    ┌──────────┐
    │                 │  admin-  │    │  admin-  │
    │                 │   wsl    │    │   unix   │
    │                 └──────────┘    └──────────┘
    │                                      │
    ▼                                      │
┌────────────────┐                         │
│ Provider Task? │                         │
└───────┬────────┘                         │
        │ YES                              │
        ▼                                  │
┌────────────────┐                         │
│ devops (provider reference)  │◄────────────────────────┘
│ (oci, hetzner, │    (MCP may need server)
│  vultr, etc.)  │
└───────┬────────┘
        │
        ▼
┌────────────────┐
│ App Deployment?│
└───────┬────────┘
        │ YES
        ▼
┌────────────────┐
│  devops (app reference)   │
│(coolify, kasm) │
└────────────────┘
```

## Step 0b: Admin Environment Check

**After environment detection, verify the admin environment exists.**

### What to Verify

1. `$ADMIN_ROOT` directory exists
2. `$ADMIN_ROOT/.env` configuration file exists
3. `$ADMIN_ROOT/logs/` directory exists
4. `$ADMIN_ROOT/profiles/` directory exists

### If Any Check Fails

Run the first-run setup flow from `first-run-setup.md`:

1. Detect platform (Windows, WSL, Linux, macOS)
2. Create directory structure
3. Generate `.env` with detected values
4. Create device profile
5. Verify write permissions

### Why This Must Be First

- **Logging requires `$ADMIN_ROOT/logs/`** - handoffs can't be tracked without it
- **Profiles require `$ADMIN_ROOT/profiles/`** - installed tool history will be lost
- **Sub-skills read `$ADMIN_ROOT/.env`** - config must exist before routing
- **Late setup corrupts state** - tasks may run without proper logging

---

## Keyword → Skill Mapping

### Server Management

```yaml
keywords:
  - server, servers, provision, deploy, infrastructure
  - cloud, VPS, VM, instance, droplet, linode
  - inventory, "my servers", "server list"
route_to: devops

sub_routing:
  - keywords: [oracle, oci, "oracle cloud", ARM64, "always free"]
    route_to: oci

  - keywords: [hetzner, hcloud, CAX, european]
    route_to: hetzner

  - keywords: [digitalocean, doctl, droplet]
    route_to: digital-ocean

  - keywords: [vultr, "vultr-cli", "high frequency"]
    route_to: vultr

  - keywords: [linode, akamai, "linode-cli"]
    route_to: linode

  - keywords: [contabo, cntb, budget]
    route_to: contabo

  - keywords: [coolify, paas, "self-hosted heroku"]
    route_to: coolify

  - keywords: [kasm, workspaces, vdi, "virtual desktop"]
    route_to: kasm
```

### Windows Administration

```yaml
keywords:
  - powershell, pwsh, windows, winget, scoop, chocolatey
  - registry, "environment variable", PATH
  - ".wslconfig", "windows terminal"
  - "Get-", "Set-", "New-", "Remove-"  # PowerShell cmdlets
route_to: admin (windows)
requires_context: windows

if_wrong_context: |
  This is a Windows task but you're in WSL/Unix.
  Please open a Windows terminal to proceed.

sub_routing:
  - keywords: [mcp, "model context protocol", "claude desktop", mcpServers]
    route_to: admin (mcp)
```

### WSL Administration

```yaml
keywords:
  - wsl, wsl2, ubuntu
  - docker, container, "docker-compose"
  - wslpath, /mnt/c
route_to: admin (wsl)
requires_context: wsl

if_wrong_context: |
  This is a WSL task but you're not in WSL.
  Please run: wsl -d Ubuntu-24.04
```

### Unix Administration (macOS/Linux)

```yaml
keywords:
  - linux, ubuntu, debian, apt, dpkg
  - macos, osx, darwin, homebrew, brew
  - systemd, systemctl, journalctl
  - bash, zsh
  - python, pip, uv, venv
  - node, npm, nvm
route_to: admin (unix)
requires_context: [linux, macos]

if_wrong_context: |
  This is a macOS/Linux task but you're in Windows/WSL.
  Use a native macOS/Linux terminal, or if you meant WSL use admin (wsl).
```

### Profile/Logging (handled by admin itself)

```yaml
keywords:
  - profile, "my tools", "installed tools"
  - log, logs, history, "what did I install"
  - sync, "cross-device", "my devices"
route_to: self
```

### Cross-Platform

```yaml
keywords:
  - "both windows and", "windows and wsl"
  - cross-platform, "on both"
route_to: self
note: Admin coordinates calling multiple sub-skills
```

## Context Validation

Before routing to a skill, validate the context is appropriate:

```bash
validate_context() {
    local target_skill="$1"
    local current_platform=$(detect_platform)

    case "$target_skill" in
        admin (windows)|admin (mcp))
            if [[ "$current_platform" != "windows" ]]; then
                echo "HANDOFF: Open Windows terminal for this task"
                return 1
            fi
            ;;
        admin (wsl))
            if [[ "$current_platform" != "wsl" ]]; then
                echo "HANDOFF: Run 'wsl -d ${WSL_DISTRO:-Ubuntu-24.04}' first"
                return 1
            fi
            ;;
        admin (unix))
            if [[ "$current_platform" == "windows" ]]; then
                echo "HANDOFF: Open a macOS/Linux terminal for this task (non-WSL)"
                return 1
            fi
            if [[ "$current_platform" == "wsl" ]]; then
                echo "HANDOFF: This is a native macOS/Linux task. If you meant WSL, use admin (wsl)."
                return 1
            fi
            ;;
        devops|oci|hetzner|digital-ocean|vultr|linode|contabo|coolify|kasm)
            # These work from any context
            return 0
            ;;
    esac
    return 0
}
```

### PowerShell Mode

```powershell
function Test-AdminContext {
    param([string]$TargetSkill)

    $platform = Get-AdminPlatform
    $wslDistro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "Ubuntu-24.04" }

    switch -Wildcard ($TargetSkill) {
        'admin (windows)' {
            if ($platform -ne 'windows') {
                Log-Operation -Status "HANDOFF" -Operation "Cross-Platform" `
                    -Details "Windows task requested from $platform. Open a Windows terminal to proceed." `
                    -LogType "handoff"
                return $false
            }
        }
        'admin (mcp)' {
            if ($platform -ne 'windows') {
                Log-Operation -Status "HANDOFF" -Operation "Cross-Platform" `
                    -Details "MCP/Windows task requested from $platform. Open a Windows terminal to proceed." `
                    -LogType "handoff"
                return $false
            }
        }
        'admin (wsl)' {
            if ($platform -eq 'windows') {
                Log-Operation -Status "HANDOFF" -Operation "Cross-Platform" `
                    -Details "WSL task requested from Windows. Run: wsl -d $wslDistro" `
                    -LogType "handoff"
                return $false
            }
        }
        'admin (unix)' {
            if ($platform -eq 'windows' -or $platform -eq 'wsl') {
                Log-Operation -Status "HANDOFF" -Operation "Cross-Platform" `
                    -Details "macOS/Linux task requested from $platform. Use a native macOS/Linux shell (non-WSL)." `
                    -LogType "handoff"
                return $false
            }
        }
        'devops' { return $true }
        'oci' { return $true }
        'hetzner' { return $true }
        'digital-ocean' { return $true }
        'vultr' { return $true }
        'linode' { return $true }
        'contabo' { return $true }
        'coolify' { return $true }
        'kasm' { return $true }
        default { return $true }
    }

    return $true
}
```

## Handoff Protocol

When a task requires a different context:

1. **Log the handoff**:
   ```bash
   log_admin "HANDOFF" "handoff" "Task requires $target_context" "current=$current_platform"
   ```

2. **Provide clear instructions**:
   - For Windows: "Open Windows Terminal or PowerShell"
   - For WSL: "Run `wsl -d Ubuntu-24.04`"

3. **Tag for tracking**:
   - `[REQUIRES-WINADMIN]` - Must be done in Windows
   - `[REQUIRES-WSL-ADMIN]` - Must be done in WSL

## Skill Availability Check

Before routing, verify the target skill is installed:

```bash
check_skill_available() {
    local skill_name="$1"
    local skill_path="$HOME/.claude/skills/$skill_name"

    if [[ ! -d "$skill_path" ]]; then
        echo "Skill '$skill_name' not installed."
        echo "Install with: ./scripts/install-skill.sh $skill_name"
        return 1
    fi
    return 0
}
```

## Examples

### Example 1: "Install Docker"

1. Detect platform: WSL
2. Keywords: "install", "docker"
3. Match: admin (wsl)
4. Context check: WSL context valid for admin (wsl)
5. Route to: admin (wsl)

### Example 2: "Update .wslconfig memory"

1. Detect platform: WSL
2. Keywords: ".wslconfig"
3. Match: admin (windows) (Windows file)
4. Context check: FAIL - WSL context, need Windows
5. Log handoff: "Open Windows terminal to edit .wslconfig"
6. Tag: `[REQUIRES-WINADMIN]`

### Example 3: "Provision OCI server"

1. Detect platform: WSL
2. Keywords: "provision", "OCI", "server"
3. Match: devops → oci
4. Context check: Pass (servers work from any context)
5. Route to: devops (which routes to oci)

### Example 4: "What tools do I have installed?"

1. Detect platform: WSL
2. Keywords: "tools", "installed"
3. Match: admin (self) - profile query
4. Action: Read device profile, display installed tools
