# Cross-Platform Coordination

Windows ↔ WSL coordination, path conversion, and handoff protocols.

**Note (Consolidation)**: Local tasks now route through the `admin` skill, using
platform-specific references (windows.md, wsl.md, unix.md).

## Contents
- Shared Admin Root
- Decision Matrix
- Path Conversion
- Handoff Protocols
- .wslconfig Management
- wsl.conf (Per-Distribution)
- Line Ending Handling
- Common Operations
- Troubleshooting

---

## Shared Admin Root

**CRITICAL**: On machines with both Windows and WSL, the `.admin` folder is **shared** on the Windows filesystem.

| Environment | ADMIN_ROOT Value | Physical Location |
|-------------|------------------|-------------------|
| Windows | `C:/Users/<WIN_USER>/.admin` | `C:/Users/<WIN_USER>/.admin` |
| WSL | `/mnt/c/Users/<WIN_USER>/.admin` | `C:/Users/<WIN_USER>/.admin` |

**Benefits:**
- **One device profile** (`<DEVICE_NAME>.json`) - not duplicated
- **Unified logs** - operations from both environments in one place
- **Single source of truth** - installed tools tracked once

**How it works:**
- WSL detects it's running on Windows (via `/proc/version`)
- WSL defaults `ADMIN_ROOT` to `/mnt/c/Users/$WIN_USER/.admin`
- Both environments read/write the same files

## Decision Matrix

| Operation | Windows (admin / windows.md) | WSL (admin / wsl.md) | Notes |
|-----------|------------------------|-----------------|-------|
| Install Windows app | ✅ | - | winget, scoop |
| Install Linux package | - | ✅ | apt, dpkg |
| Edit .wslconfig | ✅ | - | Windows file |
| Docker containers | - | ✅ | Runs in WSL |
| Docker Desktop settings | ✅ | - | Windows app |
| MCP server setup | ✅ | - | Claude Desktop is Windows |
| Python venv (WSL) | - | ✅ | uv, venv |
| Python venv (Windows) | ✅ | - | Windows Python |
| Windows Terminal profile | ✅ | - | Windows Terminal app |
| .zshrc / .bashrc | - | ✅ | WSL user config |
| systemd services | - | ✅ | Linux systemd |
| Windows services | ✅ | - | sc.exe |
| WSL memory/CPU | ✅ | - | .wslconfig |
| npm global (Windows) | ✅ | - | Windows npm |
| npm global (WSL) | - | ✅ | WSL npm |
| Git commits | Either | Either | User preference |
| Git credential manager | ✅ | - | Windows GCM |

## Path Conversion

### Windows → WSL

| Windows Path | WSL Path |
|--------------|----------|
| `C:/Users/<WIN_USER>` | `/mnt/c/Users/<WIN_USER>` |
| `D:/projects` | `/mnt/d/projects` |
| `D:/Dropbox` | `/mnt/d/Dropbox` |

**PowerShell function:**
```powershell
function Convert-ToWslPath {
    param([string]$WindowsPath)
    $path = $WindowsPath -replace '\\', '/'
    $path = $path -replace '^([A-Za-z]):', '/mnt/$1'.ToLower()
    $path
}
# Convert-ToWslPath "D:/projects/myapp" → /mnt/d/projects/myapp
```

**Bash (using wslpath):**
```bash
wslpath -u 'C:/Users/<WIN_USER>/Documents'
# Returns: /mnt/c/Users/Owner/Documents
```

### WSL → Windows

| WSL Path | Windows Path |
|----------|--------------|
| `/home/user` | `\\wsl$\Ubuntu-24.04\home\user` |
| `/mnt/c/Users` | `C:/Users` |

**Bash:**
```bash
wslpath -w /home/username/file.txt
# Returns: \\wsl$\Ubuntu-24.04\home\username\file.txt
```

## Handoff Protocols

### Tags for Cross-Admin Communication

| Tag | Meaning | Example |
|-----|---------|---------|
| `[REQUIRES-WSL-ADMIN]` | WinAdmin needs WSL Admin | Package installation |
| `[REQUIRES-WINADMIN]` | WSL Admin needs WinAdmin | Memory increase |
| `[AFFECTS-WSL]` | Windows change affects WSL | .wslconfig edit |
| `[AFFECTS-WINDOWS]` | WSL change affects Windows | Git credential |
| `[CROSS-PLATFORM]` | Involves both | Shared project setup |

### Windows → WSL Handoff

```powershell
function Request-WslAdminHandoff {
    param(
        [Parameter(Mandatory)][string]$Task,
        [string]$Details,
        [string]$AdminRoot = $env:ADMIN_ROOT
    )

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $logEntry = "$timestamp [$env:COMPUTERNAME][windows] HANDOFF: $Task | $Details"

    if ($AdminRoot) {
        Add-Content "$AdminRoot\logs\handoffs.log" -Value $logEntry
    }

    Write-Host "`n[REQUIRES-WSL-ADMIN]" -ForegroundColor Yellow
    Write-Host "Task: $Task" -ForegroundColor Cyan
    if ($Details) { Write-Host "Details: $Details" -ForegroundColor Gray }
    Write-Host "`nSwitch to WSL:" -ForegroundColor White
    Write-Host "  wsl -d Ubuntu-24.04" -ForegroundColor Gray
}
```

### WSL → Windows Handoff

```bash
request_winadmin_handoff() {
    local task="$1"
    local details="$2"

    local timestamp=$(date -Iseconds)
    local device="${DEVICE_NAME:-$(hostname)}"
    local log_entry="$timestamp [$device][wsl] HANDOFF: $task | $details"

    if [[ -n "$ADMIN_LOG_PATH" ]]; then
        echo "$log_entry" >> "$ADMIN_LOG_PATH/handoffs.log"
    fi

    echo ""
    echo "[REQUIRES-WINADMIN]"
    echo "Task: $task"
    [[ -n "$details" ]] && echo "Details: $details"
    echo ""
    echo "Exit WSL and use PowerShell:"
    echo "  exit"
}
```

## .wslconfig Management

### File Location

```
C:/Users/{USERNAME}/.wslconfig
```

### Configuration Template

```ini
[wsl2]
memory=16GB
processors=8
swap=4GB
localhostForwarding=true
nestedVirtualization=true
guiApplications=true

[experimental]
sparseVhd=true
autoMemoryReclaim=gradual
```

### Resource Recommendations

| System RAM | WSL Memory | Processors | Swap |
|------------|------------|------------|------|
| 16GB | 8GB | 4 | 2GB |
| 32GB | 16GB | 8 | 4GB |
| 64GB | 24GB | 12 | 8GB |
| 128GB | 48GB | 16 | 16GB |

### Apply Changes

```powershell
# Edit config
notepad "$env:USERPROFILE/.wslconfig"

# Restart WSL to apply
wsl --shutdown
```

## wsl.conf (Per-Distribution)

Located at `/etc/wsl.conf` inside WSL:

```ini
[boot]
systemd=true

[automount]
enabled=true
root=/mnt/
options="metadata,umask=22,fmask=11"

[network]
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true
```

## Line Ending Handling

### Problem

Windows uses CRLF (`\r\n`), Linux uses LF (`\n`).

### Solutions

**Convert to Unix (for WSL):**
```bash
dos2unix script.sh
```

**Convert to Windows:**
```bash
unix2dos script.sh
```

**Git configuration:**
```bash
# Windows
git config --global core.autocrlf true

# WSL
git config --global core.autocrlf input
```

**.gitattributes:**
```
* text=auto
*.sh text eol=lf
*.ps1 text eol=crlf
```

## Common Operations

### Check WSL Status

```powershell
wsl --version
wsl --list --verbose
wsl --status
```

### WSL Memory Usage

```powershell
wsl -d Ubuntu-24.04 -e free -h
```

### Reclaim Disk Space

```powershell
# Clean up inside WSL
wsl -d Ubuntu-24.04 -e sudo apt autoremove -y
wsl -d Ubuntu-24.04 -e sudo apt clean

# Shutdown and compact
wsl --shutdown
# Then compact VHD (requires admin)
```

## Troubleshooting

### WSL Not Starting

```powershell
wsl --status
wsl --update
Restart-Service LxssManager
```

### Memory Not Reclaimed

Add to `.wslconfig`:
```ini
[experimental]
autoMemoryReclaim=gradual
```

### Can't Access Windows Files from WSL

Check `/etc/wsl.conf` has:
```ini
[automount]
enabled=true
```

### Permission Denied on WSL Files

Access via `\\wsl$\` path, not directly through AppData.
