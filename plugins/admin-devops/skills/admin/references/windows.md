# Windows Administration

_Consolidated from `skills/admin (windows)` on 2026-02-02_

## Skill Body

# Windows Administration

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: Windows platform, PowerShell 7.x

---

## ⚠️ Profile Gate (MANDATORY - DO THIS FIRST)

**STOP. Before ANY operation, you MUST check for the profile. This is not optional.**

### Step 1: Check Profile Exists

```powershell
# Use the helper script - it handles path resolution correctly
pwsh -NoProfile -File "scripts/Test-AdminProfile.ps1"
```

Returns JSON: `{"exists":true,"path":"...","device":"CASATEN",...}`

### Step 2: If Profile Missing → Run Setup

If `exists` is `false`:
```powershell
pwsh -NoProfile -File "scripts/Setup-Interview.ps1"
```

**DO NOT proceed with ANY task until profile exists.**

### Step 3: Load Profile

```powershell
. "scripts/Load-Profile.ps1"
Load-AdminProfile -Export
```

### Step 4: Check Preferences Before Commands

```powershell
# User wants to install a package
$preferredManager = $AdminProfile.preferences.packages.manager
# Returns: "scoop" or "winget" or "chocolatey"
```

---

## Quick Start (5 Minutes)

### 1) Verify PowerShell 7.x

```powershell
$PSVersionTable.PSVersion
# Should show 7.x (NOT 5.1)
```

If PowerShell 7 is not installed:
```powershell
winget install Microsoft.PowerShell
```

### 2) Load Profile (Already Required by Gate)

```powershell
. ..\admin\scripts\Load-Profile.ps1
Load-AdminProfile -Export
```

### 3) Verify Environment

```powershell
Show-AdminSummary
```

---

## Critical Rules

### Always Do

- Use PowerShell 7.x (`pwsh.exe`), not Windows PowerShell 5.1 (`powershell.exe`)
- Use PowerShell cmdlets, not bash/Linux commands
- Use full paths with `Test-Path` before file operations
- Set PATH in Windows Registry for persistence (not just session)
- Use `${env:VARIABLE}` syntax for environment variables

### Never Do

- Use bash commands (`cat`, `ls`, `grep`, `echo`, `export`)
- Use relative paths without verification
- Modify system PATH without backup
- Run scripts without execution policy check
- Create duplicate config files (update the existing one)

---

## Package Installation (Profile-Aware)

### Check Preference First

```powershell
$pkgMgr = $AdminProfile.preferences.packages.manager

switch ($pkgMgr) {
    "scoop"   { scoop install $package }
    "winget"  { winget install $package }
    "choco"   { choco install $package -y }
    default   { winget install $package }
}
```

### Quick Reference by Manager

| Manager | Install | Update | List |
|---------|---------|--------|------|
| scoop | `scoop install x` | `scoop update x` | `scoop list` |
| winget | `winget install x` | `winget upgrade x` | `winget list` |
| choco | `choco install x -y` | `choco upgrade x` | `choco list` |

---

## Python Commands (Profile-Aware)

**Check profile first:**

```powershell
$pyMgr = $AdminProfile.preferences.python.manager
# Returns: "uv", "pip", "conda", "poetry"
```

| Profile Says | Instead of `pip install x` | Use |
|--------------|---------------------------|-----|
| `uv` | ❌ | `uv pip install x` |
| `pip` | ✅ | `pip install x` |
| `conda` | ❌ | `conda install x` |
| `poetry` | ❌ | `poetry add x` |

---

## Node Commands (Profile-Aware)

```powershell
$nodeMgr = $AdminProfile.preferences.node.manager
# Returns: "npm", "pnpm", "yarn", "bun"
```

| Profile Says | Instead of `npm install` | Use |
|--------------|--------------------------|-----|
| `npm` | ✅ | `npm install` |
| `pnpm` | ❌ | `pnpm install` |
| `yarn` | ❌ | `yarn` |
| `bun` | ❌ | `bun install` |

---

## Bash to PowerShell Translation

| Bash | PowerShell | Notes |
|------|------------|-------|
| `cat file` | `Get-Content file` | Or `gc` |
| `cat file \| head -20` | `Get-Content file -Head 20` | |
| `cat file \| tail -20` | `Get-Content file -Tail 20` | |
| `ls -la` | `Get-ChildItem -Force` | |
| `grep "x" file` | `Select-String "x" file` | Or `sls` |
| `echo "x"` | `Write-Output "x"` | |
| `echo "x" > file` | `Set-Content file -Value "x"` | |
| `echo "x" >> file` | `Add-Content file -Value "x"` | |
| `export VAR=x` | `$env:VAR = "x"` | Session only |
| `export VAR=x` (perm) | `[Environment]::SetEnvironmentVariable("VAR", "x", "User")` | |
| `test -f file` | `Test-Path file -PathType Leaf` | |
| `test -d dir` | `Test-Path dir -PathType Container` | |
| `mkdir -p dir` | `New-Item -ItemType Directory -Path dir -Force` | |
| `rm -rf dir` | `Remove-Item dir -Recurse -Force` | |
| `which cmd` | `Get-Command cmd` | |
| `curl URL` | `Invoke-WebRequest URL` | |
| `jq` | `ConvertFrom-Json` / `ConvertTo-Json` | |

---

## PATH Operations

### Check Tool Path from Profile

```powershell
# Instead of searching, use profile
$gitPath = $AdminProfile.tools.git.path
# Returns: "C:/Program Files/Git/mingw64/bin/git.exe"
```

### Add to PATH (Permanent)

```powershell
$newPath = "C:/new/path"
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -notlike "*$newPath*") {
    [Environment]::SetEnvironmentVariable('PATH', "$newPath;$currentPath", 'User')
}
# Refresh session
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User') + ";" + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
```

---

## Environment Variables

### From Profile

```powershell
# Key paths are in profile
$AdminProfile.paths.sshKeys      # C:/Users/Owner/.ssh
$AdminProfile.paths.npmGlobal    # C:/Users/Owner/AppData/Roaming/npm
$AdminProfile.paths.projects     # D:/
```

### Set Permanent Variable

```powershell
[Environment]::SetEnvironmentVariable("MY_VAR", "value", "User")
```

---

## Check Tool Status

Before installing, check profile:

```powershell
$tool = Get-AdminTool "docker"
if ($tool.present -and $tool.installStatus -eq "working") {
    Write-Host "Docker already installed: $($tool.version)"
} else {
    # Install using preferred manager
    $mgr = $AdminProfile.preferences.packages.manager
    # ... install logic
}
```

---

## After ANY Operation (MANDATORY)

**Always log the operation and update the profile.**

### Log the Event

```powershell
# Source the logging helper
. "scripts/Log-AdminEvent.ps1"

# Log success
Log-AdminEvent -Message "Installed 7zip via winget" -Level OK

# Log failure (also creates an issue file)
Log-AdminEvent -Message "Failed to install 7zip: access denied" -Level ERROR
```

### On Failure: Create Issue

```powershell
. "scripts/New-AdminIssue.ps1"
New-AdminIssue -Title "7zip installation failed" -Category install -Tags @("winget","7zip")
```

---

## After Installation

Update profile:

```powershell
$AdminProfile.tools["newtool"] = @{
    present = $true
    version = "1.0.0"
    installedVia = $AdminProfile.preferences.packages.manager
    path = (Get-Command newtool).Source
    installStatus = "working"
    lastChecked = (Get-Date).ToString("o")
}

# Add to history
$AdminProfile.history += @{
    date = (Get-Date).ToString("o")
    action = "install"
    tool = "newtool"
    method = $AdminProfile.preferences.packages.manager
    status = "success"
}

# Save
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile
```

---

## Execution Policy

```powershell
# Check
Get-ExecutionPolicy -List

# Set for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Bypass for single script
powershell -ExecutionPolicy Bypass -File script.ps1
```

---

## PowerShell Profile

Location: `$AdminProfile.preferences.shell.profilePath`

```powershell
# Edit
notepad $PROFILE

# Recommended: Source admin profile loader
. "$HOME\.admin\scripts\Load-Profile.ps1"
Load-AdminProfile -Export -Quiet
```

---

## Capabilities Check

Before operations, verify capabilities:

```powershell
if (-not (Test-AdminCapability "canRunPowershell")) {
    Write-Error "PowerShell not available"
    return
}

if (Test-AdminCapability "hasDocker") {
    # Docker operations safe
}
```

---

## Scope Boundaries

| Task Type | Route To |
|-----------|----------|
| WSL administration | `admin (wsl)` |
| MCP servers | `admin (mcp)` |
| Linux/macOS admin | `admin (unix)` |
| Cross-platform routing | `admin` |

---

## Related Skills

| Task | Route To |
|------|----------|
| WSL operations | `admin (wsl)` |
| MCP servers | `admin (mcp)` |
| Server provisioning | `devops` |
| Profile management | `admin` |

---

## References

- `references/bash-to-powershell.md` - Full command translation table
- `references/package-managers.md` - winget/scoop/npm/choco workflows
- `references/path-configuration.md` - PATH safety and persistence
- `references/environment-variables.md` - Session vs permanent variables
- `references/known-issues.md` - Common pitfalls and prevention
- `references/OPERATIONS.md` - Troubleshooting and diagnostics

## Reference Appendices

### windows: references/OPERATIONS.md

# Windows Operations Reference

Extended operations for Windows administration: known issues prevention, bundled resources, troubleshooting, setup checklist, and version snapshots.

## Contents
- Known Issues Prevention
- Using Bundled Resources
- Troubleshooting
- Complete Setup Checklist
- Official Documentation
- Package Versions (Snapshot)

---

## Known Issues Prevention

This skill prevents **15** documented issues:

### Issue #1: Using bash commands in PowerShell
**Error**: `cat : The term 'cat' is not recognized`
**Why It Happens**: PowerShell uses different cmdlets than bash
**Prevention**: Use translation table above (`cat` -> `Get-Content`)

### Issue #2: PATH not persisting
**Error**: Commands work in one session but not another
**Why It Happens**: Setting `$env:PATH` only affects current session
**Prevention**: Use `[Environment]::SetEnvironmentVariable()` for persistence

### Issue #3: JSON depth truncation
**Error**: JSON output shows `@{...}` instead of nested values
**Why It Happens**: Default `-Depth` is 2
**Prevention**: Always use `ConvertTo-Json -Depth 10`

### Issue #4: Profile not loading
**Error**: Profile functions/aliases not available
**Why It Happens**: Wrong profile location or `-NoProfile` flag
**Prevention**: Verify `$PROFILE` path and check startup flags

### Issue #5: Script execution blocked
**Error**: `script.ps1 cannot be loaded because running scripts is disabled`
**Why It Happens**: Execution policy is Restricted
**Prevention**: Set `RemoteSigned` for current user

### Issue #6: npm global commands not found
**Error**: `npm : The term 'npm' is not recognized`
**Why It Happens**: npm path not in system PATH
**Prevention**: Add `%APPDATA%\npm` to User PATH via registry

### Issue #7: PowerShell 5.1 vs 7.x confusion
**Error**: Features not working, different behavior
**Why It Happens**: Using `powershell.exe` (5.1) instead of `pwsh.exe` (7.x)
**Prevention**: Always use `pwsh` command or verify with `$PSVersionTable`

---

## Using Bundled Resources

### Scripts (scripts/)

**Verify-ShellEnvironment.ps1** - Comprehensive environment check
```powershell
.\scripts\Verify-ShellEnvironment.ps1
```

Tests: PowerShell version, profile location, PATH configuration, tool availability

### Templates (templates/)

**profile-template.ps1** - Recommended PowerShell profile
```powershell
Copy-Item templates/profile-template.ps1 $PROFILE
```

---

## Troubleshooting

### Problem: Command not found after installation
**Solution**:
1. Check PATH: `$env:PATH -split ';' | Select-String "expected-path"`
2. Refresh session: Start new PowerShell window
3. Check registry PATH vs session PATH

### Problem: Profile changes not taking effect
**Solution**:
1. Verify profile path: `$PROFILE`
2. Dot-source to reload: `. $PROFILE`
3. Check for syntax errors: `pwsh -NoProfile -Command ". '$PROFILE'"`

### Problem: JSON losing data on save
**Solution**: Always use `-Depth 10` or higher with `ConvertTo-Json`

### Problem: Scripts from internet won't run
**Solution**:
```powershell
# Unblock single file
Unblock-File -Path script.ps1

# Or set execution policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Complete Setup Checklist

- [ ] PowerShell 7.x installed (`pwsh --version`)
- [ ] Execution policy set to RemoteSigned
- [ ] npm path in User PATH (registry)
- [ ] Profile created and loading
- [ ] `.env` file created from template
- [ ] Verification script passes
- [ ] Package managers working (winget, scoop, npm)

---

## Official Documentation

- **PowerShell**: https://learn.microsoft.com/en-us/powershell/
- **winget**: https://learn.microsoft.com/en-us/windows/package-manager/winget/
- **scoop**: https://scoop.sh/
- **chocolatey**: https://chocolatey.org/

---

## Package Versions (Snapshot, Verified 2025-12-06)

```json
{
  "tools": {
    "PowerShell": "7.5.x",
    "winget": "1.9.x",
    "scoop": "0.5.x"
  }
}
```

### windows: references/bash-to-powershell.md

# Bash to PowerShell Translation (Full)

| Bash Command | PowerShell Equivalent | Notes |
|--------------|----------------------|-------|
| `cat file.txt` | `Get-Content file.txt` | Or `gc` alias |
| `cat file.txt | head -20` | `Get-Content file.txt -Head 20` | Built-in parameter |
| `cat file.txt | tail -20` | `Get-Content file.txt -Tail 20` | Built-in parameter |
| `ls` | `Get-ChildItem` | Or `dir`, `gci` aliases |
| `ls -la` | `Get-ChildItem -Force` | Shows hidden files |
| `grep "pattern" file` | `Select-String "pattern" file` | Or `sls` alias |
| `grep -r "pattern" .` | `Get-ChildItem -Recurse | Select-String "pattern"` | Recursive search |
| `echo "text"` | `Write-Output "text"` | Or `Write-Host` for display |
| `echo "text" > file` | `Set-Content file -Value "text"` | Overwrites file |
| `echo "text" >> file` | `Add-Content file -Value "text"` | Appends to file |
| `export VAR=value` | `$env:VAR = "value"` | Session only |
| `export VAR=value` (permanent) | `[Environment]::SetEnvironmentVariable("VAR", "value", "User")` | Persists |
| `test -f file` | `Test-Path file -PathType Leaf` | Check file exists |
| `test -d dir` | `Test-Path dir -PathType Container` | Check dir exists |
| `mkdir -p dir/sub` | `New-Item -ItemType Directory -Path dir/sub -Force` | Creates parents |
| `rm file` | `Remove-Item file` | Delete file |
| `rm -rf dir` | `Remove-Item dir -Recurse -Force` | Delete directory |
| `cp src dst` | `Copy-Item src dst` | Copy file |
| `mv src dst` | `Move-Item src dst` | Move/rename |
| `pwd` | `Get-Location` | Or `$PWD` variable |
| `cd dir` | `Set-Location dir` | `cd` alias works |
| `which cmd` | `Get-Command cmd` | Find command location |
| `ps aux` | `Get-Process` | List processes |
| `kill PID` | `Stop-Process -Id PID` | Kill process |
| `curl URL` | `Invoke-WebRequest URL` | Use `Invoke-RestMethod` for APIs |
| `wget URL -O file` | `Invoke-WebRequest URL -OutFile file` | Download file |
| `jq` | `ConvertFrom-Json` / `ConvertTo-Json` | JSON handling |
| `sed 's/old/new/g'` | `(Get-Content file) -replace 'old','new'` | Text replacement |
| `awk` | `Select-Object`, `ForEach-Object` | Data processing |
| `source file.sh` | `. .\file.ps1` | Dot-source script |

### windows: references/environment-variables.md

# Environment Variables (Windows)

## Session Variables (Temporary)

```powershell
# Set variable
$env:MY_VAR = "value"

# Read variable
$env:MY_VAR

# Remove variable
Remove-Item Env:\MY_VAR
```

## Permanent Variables

```powershell
# Set User variable (persists across sessions)
[Environment]::SetEnvironmentVariable("MY_VAR", "value", "User")

# Set Machine variable (requires admin)
[Environment]::SetEnvironmentVariable("MY_VAR", "value", "Machine")

# Read from specific scope
[Environment]::GetEnvironmentVariable("MY_VAR", "User")

# Remove permanent variable
[Environment]::SetEnvironmentVariable("MY_VAR", $null, "User")
```

## Load Variables from .env File

```powershell
function Load-EnvFile {
    param([string]$Path = ".env")

    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match '^([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                Set-Item -Path "Env:\\$name" -Value $value
                Write-Host "Loaded: $name"
            }
        }
    } else {
        Write-Warning "File not found: $Path"
    }
}

# Usage
Load-EnvFile ".env"
```

### windows: references/known-issues.md

# Known Issues Prevention (Windows)

This section captures common Windows admin pitfalls and how to avoid them.

## Issue 1: Using bash commands in PowerShell
- Error: `cat : The term 'cat' is not recognized`
- Cause: PowerShell uses cmdlets instead of bash commands
- Prevention: Use translation table (`cat` -> `Get-Content`)

## Issue 2: PATH not persisting
- Error: Commands work in one session but not another
- Cause: Setting `$env:PATH` only affects current session
- Prevention: Use `[Environment]::SetEnvironmentVariable()` for persistence

## Issue 3: JSON depth truncation
- Error: JSON output shows `@{...}` instead of nested values
- Cause: Default `ConvertTo-Json -Depth` is 2
- Prevention: Always use `ConvertTo-Json -Depth 10`

## Issue 4: Profile not loading
- Error: Profile functions/aliases not available
- Cause: Wrong profile location or `-NoProfile` flag
- Prevention: Verify `$PROFILE` path and check startup flags

## Issue 5: Script execution blocked
- Error: `script.ps1 cannot be loaded because running scripts is disabled`
- Cause: Execution policy is Restricted
- Prevention: Set `RemoteSigned` for current user

## Issue 6: npm global commands not found
- Error: `npm : The term 'npm' is not recognized`
- Cause: npm path not in system PATH
- Prevention: Add `%APPDATA%\npm` to User PATH via registry

## Issue 7: PowerShell 5.1 vs 7.x confusion
- Error: Features not working, different behavior
- Cause: Using `powershell.exe` (5.1) instead of `pwsh.exe` (7.x)
- Prevention: Use `pwsh` or verify with `$PSVersionTable`

### windows: references/package-managers.md

# Package Managers (Windows)

## winget (Preferred for Windows Apps)

```powershell
# Search for package
winget search "package-name"

# Install package
winget install Package.Name

# Install specific version
winget install Package.Name --version 1.2.3

# List installed packages
winget list

# Upgrade package
winget upgrade Package.Name

# Upgrade all packages
winget upgrade --all

# Uninstall package
winget uninstall Package.Name
```

## scoop (Developer Tools)

```powershell
# Install scoop (if not installed)
irm get.scoop.sh | iex

# Add buckets (repositories)
scoop bucket add extras
scoop bucket add versions

# Install package
scoop install git

# List installed
scoop list

# Update package
scoop update git

# Update all
scoop update *

# Uninstall
scoop uninstall git
```

## npm (Node.js Packages)

```powershell
# Install globally
npm install -g package-name

# List global packages
npm list -g --depth=0

# Update global package
npm update -g package-name

# Uninstall global
npm uninstall -g package-name
```

## chocolatey (Alternative)

```powershell
# Install chocolatey (admin required)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install package
choco install package-name -y

# List installed
choco list --local-only

# Upgrade
choco upgrade package-name -y

# Uninstall
choco uninstall package-name -y
```

### windows: references/path-configuration.md

# PATH Configuration (Windows)

## Check Current PATH

```powershell
# View full PATH
$env:PATH -split ';'

# Check if path exists in PATH
$env:PATH -split ';' | Where-Object { $_ -like "*npm*" }

# Check User vs Machine PATH separately
[Environment]::GetEnvironmentVariable('PATH', 'User') -split ';'
[Environment]::GetEnvironmentVariable('PATH', 'Machine') -split ';'
```

## Add to PATH (Permanent)

```powershell
# Add to User PATH (no admin required)
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$newPath = "C:\\new\\path"
if ($currentPath -notlike "*$newPath*") {
    [Environment]::SetEnvironmentVariable('PATH', "$newPath;$currentPath", 'User')
    Write-Host "Added $newPath to User PATH"
}

# Refresh current session
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User') + ";" + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
```

## Common PATH Entries

```powershell
# npm global packages
C:\\Users\\${env:USERNAME}\\AppData\\Roaming\\npm

# Scoop apps
C:\\Users\\${env:USERNAME}\\scoop\\shims

# Python (winget install)
C:\\Users\\${env:USERNAME}\\AppData\\Local\\Programs\\Python\\Python3xx

# Git
C:\\Program Files\\Git\\cmd
```
