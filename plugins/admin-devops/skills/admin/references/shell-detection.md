# Shell Detection Reference

This document explains how the admin skill detects and adapts to different shell environments.

## Contents
- Two Separate Concepts
- Why Shell Detection Matters
- IMPORTANT: Claude Code on Windows Uses Git Bash
- Detection Method
- Platform Detection Helpers
- Platform + Shell Matrix
- Claude Code on Windows: Path Conversion

---

## Two Separate Concepts

The admin skill tracks TWO environment variables:

| Variable | Purpose | Values |
|----------|---------|--------|
| `ADMIN_PLATFORM` | Operating system | windows, wsl, linux, macos |
| `ADMIN_SHELL` | Command interpreter | bash, powershell, zsh, cmd |

**Why both?** Because platform doesn't always determine shell:
- Windows can run PowerShell, Bash (Git Bash), or CMD
- WSL runs Bash on top of Windows
- macOS can run Bash or Zsh

## Why Shell Detection Matters

Claude Code can run in different shell environments:
- **PowerShell** (Windows native)
- **Bash** (WSL, Linux, macOS, Git Bash)
- **Zsh** (macOS default, some Linux)

The commands for these shells are completely different. Using bash syntax in PowerShell (or vice versa) causes errors.

## IMPORTANT: Claude Code on Windows Uses Git Bash

**Critical Finding (Issue 004)**: On Windows, Claude Code's Bash tool executes commands through a **Git Bash subprocess** (MINGW64), even when the host terminal is PowerShell.

| Context | Shell |
|---------|-------|
| Host terminal (what user sees) | PowerShell 7 |
| Claude Code Bash tool | Git Bash (MINGW64) |
| Detected `ADMIN_SHELL` | bash |

**Implications**:
1. Bash commands work through Claude Code on Windows
2. PowerShell syntax will fail (it's interpreted by Git Bash)
3. `$env:USERPROFILE` won't work - use `$HOME` or `/c/Users/X/` paths
4. Windows commands like `winget` still work (they're executables, not shell builtins)

**To run native PowerShell commands from Claude Code on Windows**:
```bash
# Invoke PowerShell from Git Bash
pwsh.exe -Command "Get-Content \"$env:USERPROFILE\\.admin\\logs\\operations.log\""

# Multi-line PowerShell script
pwsh.exe -Command @'
$profile = Get-Content "$env:USERPROFILE\.admin\profiles\$env:COMPUTERNAME.json"
$profile | ConvertFrom-Json
'@
```

## Detection Method

### Automatic Detection

Claude Code determines the shell based on which commands work:

1. **Try `echo $BASH_VERSION`**
   - If it returns a version string → Bash mode
   - If it fails or returns empty → Check PowerShell

2. **Try `$PSVersionTable.PSVersion`**
   - If it returns version info → PowerShell mode
   - If it fails → Likely Bash mode

### Environment Indicators

| Indicator | Bash | PowerShell |
|-----------|------|------------|
| `$BASH_VERSION` | Has value | Empty/Error |
| `$PSVersionTable` | Error | Has value |
| `$HOME` | User home | Empty |
| `$env:USERPROFILE` | Empty | User home |
| Path separator | `/` | `\` |

## Platform Detection Helpers

Use these canonical helpers to determine `ADMIN_PLATFORM` separately from `ADMIN_SHELL`.

### Bash Mode

```bash
detect_platform() {
    # Check explicit override first
    if [[ -n "$ADMIN_PLATFORM" ]]; then
        echo "$ADMIN_PLATFORM"
        return
    fi

    # Auto-detect (case-insensitive grep for WSL)
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OS" == "Windows_NT" ]]; then
        echo "windows"  # Git Bash on Windows
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}
```

### PowerShell Mode

```powershell
function Get-AdminPlatform {
    # Check explicit override first
    if ($env:ADMIN_PLATFORM) {
        return $env:ADMIN_PLATFORM
    }

    # PowerShell 7+ provides $IsWindows/$IsLinux/$IsMacOS
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        if ($IsWindows) { return "windows" }
        if ($IsMacOS) { return "macos" }
        if ($IsLinux) {
            $isWsl = $false
            try {
                $isWsl = (Get-Content /proc/version -ErrorAction Stop) -match 'microsoft'
            } catch { }
            if ($isWsl) { return "wsl" }
            return "linux"
        }
    }

    # Cross-platform fallback for pwsh builds without $Is* variables
    try {
        $ri = [System.Runtime.InteropServices.RuntimeInformation]
        if ($ri::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { return "windows" }
        if ($ri::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { return "macos" }
        if ($ri::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
            $isWsl = $false
            try {
                $isWsl = (Get-Content /proc/version -ErrorAction Stop) -match 'microsoft'
            } catch { }
            if ($isWsl) { return "wsl" }
            return "linux"
        }
    } catch { }

    # Fallback for Windows PowerShell 5.1 (Windows-only)
    if ($env:OS -eq "Windows_NT") { return "windows" }

    return "linux"
}

# Usage: $platform = Get-AdminPlatform
```

## Shell Mode Syntax

Standard Bash and PowerShell syntax differ across the obvious primitives (directory
creation, env-var reads, file checks, conditionals, command capture) — use whichever
matches the detected `ADMIN_SHELL` and keep a single dialect per script. The
admin-specific habits that matter:

- **Build the admin root from the layered fallback** so callers can override it:
  Bash `"${ADMIN_LOG_PATH:-${ADMIN_ROOT:-$HOME/.admin}/logs}/operations.log"`;
  PowerShell `Join-Path $env:USERPROFILE '.admin\logs\operations.log'`.
- **Construct paths with `Join-Path` in PowerShell** rather than string concatenation,
  so the backslash style stays correct on native Windows.
- **Detect the shell before running anything**, then keep all commands in that one
  dialect; when a task genuinely needs the other shell, hand off with a clear message.

## Platform + Shell Matrix

| ADMIN_PLATFORM | ADMIN_SHELL | Environment | Config Location | Path Style |
|----------------|-------------|-------------|-----------------|------------|
| windows | powershell | Native Windows | `C:/Users/X/.admin` | Backslash |
| windows | bash | Git Bash / Claude Code | `/c/Users/X/.admin` | Forward slash |
| wsl | bash | WSL Ubuntu | `/mnt/c/Users/X/.admin` | Forward slash |
| linux | bash | Native Linux | `/home/X/.admin` | Forward slash |
| macos | zsh | macOS Terminal | `/Users/X/.admin` | Forward slash |

**WSL default**: When `ADMIN_PLATFORM=wsl` and `ADMIN_ROOT` is unset, use `/mnt/c/Users/$WIN_USER/.admin` to share state with Windows.

**Note**: Always store absolute paths in config files, never `~` (tilde).

## Claude Code on Windows: Path Conversion

When running on Windows through Claude Code (Git Bash):

| Windows Path | Git Bash Path |
|--------------|---------------|
| `C:/Users/Owner` | `/c/Users/Owner` |
| `D:/admin` | `/d/admin` |
| `%USERPROFILE%` | `$HOME` |
| `%COMPUTERNAME%` | `$(hostname)` (works) |

**Example - First-run setup on Windows via Claude Code**:
```bash
# Works on Windows Claude Code (Git Bash)
DEVICE_NAME="${DEVICE_NAME:-$(hostname)}"
ADMIN_ROOT="$HOME/.admin"

# Create directories (Git Bash style)
mkdir -p "$ADMIN_ROOT"/{logs,profiles,config}
mkdir -p "$ADMIN_ROOT/logs/devices/$DEVICE_NAME"

# Create profile
cat > "$ADMIN_ROOT/profiles/$DEVICE_NAME.json" << EOF
{
  "deviceInfo": {
    "name": "$DEVICE_NAME",
    "platform": "windows",
    "shell": "bash",
    "hostname": "$(hostname)",
    "user": "$USER",
    "adminRoot": "$ADMIN_ROOT",
    "lastUpdated": "$(date -Iseconds)"
  },
  "installedTools": {},
  "managedServers": []
}
EOF

echo "Profile created at: $ADMIN_ROOT/profiles/$DEVICE_NAME.json"
```
