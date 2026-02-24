---
name: setup-profile
description: Create or reconfigure the admin device profile through a TUI interview
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[--reset]"
---

# /setup-profile Command

Create or reconfigure the admin device profile through an interactive TUI interview.

## Workflow

### Step 1: Check Existing Profile

Run the profile test script to determine current state:

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/Test-AdminProfile.ps1"
```

**Bash (WSL/Linux/macOS):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/test-admin-profile.sh"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"..."}`

### Step 2: Handle Existing Profile

If `exists: true` and no `--reset` flag:
- Ask user: "Profile already exists at {path}. Do you want to reconfigure it?"
- If no, exit gracefully

### Step 3: TUI Interview

Use `AskUserQuestion` to gather preferences:

#### Q1: Storage Location (Required)

Ask: "Will you use Admin on a single device or multiple devices?"

| Option | Description |
|--------|-------------|
| Single device (Recommended) | Local storage at `~/.admin`. Simple, no sync needed. |
| Multiple devices | Cloud-synced folder (Dropbox, OneDrive, NAS). Profiles shared across machines. |

If "Multiple devices", follow up: "Enter the path to your cloud-synced folder"
- Examples: `C:\Users\You\Dropbox\.admin`, `~/Dropbox/.admin`, `N:\Shared\.admin`

#### Q2: Package Manager Preference

Ask: "Which package manager do you prefer?"

| Option | Platforms |
|--------|-----------|
| winget (default for Windows) | Windows |
| scoop | Windows |
| chocolatey | Windows |
| brew | macOS, Linux |
| apt | Ubuntu/Debian |

#### Q3: Python Manager Preference

Ask: "Which Python environment manager do you prefer?"

| Option | Description |
|--------|-------------|
| uv (Recommended) | Fast, modern, replaces pip+venv |
| pip | Standard Python |
| conda | Data science focused |
| poetry | Project-based dependency management |

#### Q4: Node Manager Preference

Ask: "Which Node package manager do you prefer?"

| Option | Description |
|--------|-------------|
| npm (default) | Standard Node |
| pnpm | Efficient disk usage |
| yarn | Facebook's package manager |
| bun | Fast JavaScript runtime |

#### Q5: Inventory Scan

Ask: "Run a quick inventory scan to detect installed tools?"
- Yes: Scans for git, node, python, docker, ssh, etc.
- No: Creates minimal profile, tools detected on first use

### Step 4: Create Profile

Pass the collected answers to the setup script:

**PowerShell:**
```powershell
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/New-AdminProfile.ps1" `
  -AdminRoot "C:/Users/You/.admin" `
  -PkgMgr "winget" `
  -PyMgr "uv" `
  -NodeMgr "npm" `
  -ShellDefault "pwsh" `
  -RunInventory
```

**Bash:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/new-admin-profile.sh" \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "brew" \
  --py-mgr "uv" \
  --node-mgr "npm" \
  --shell-default "zsh" \
  --run-inventory
```

### Step 5: Verify and Report

Re-run the profile test to confirm creation, then report:
- Profile location
- Detected device info
- Configured preferences
- Next steps (e.g., "Try `/install git` to test")

## Error Handling

- If script not found: Report missing file and suggest reinstalling skill
- If profile creation fails: Show error message and suggest manual creation
- If permission denied: Suggest running with elevated privileges

## Tips

- Use `--reset` argument to force reconfiguration of existing profile
- Multi-device profiles should use cloud-synced folders for consistency
- The inventory scan is optional but recommended for accurate tool detection
