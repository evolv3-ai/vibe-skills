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

Drive `C:` maps to `/mnt/c`, `D:` to `/mnt/d`, etc. Backslashes become forward slashes. WSL home (`/home/user`) is reachable from Windows via the `\\wsl$\` UNC path.

| Windows Path | WSL Path |
|--------------|----------|
| `C:/Users/<WIN_USER>` | `/mnt/c/Users/<WIN_USER>` |
| `D:/Dropbox` | `/mnt/d/Dropbox` |
| `N:\Dropbox` | `/mnt/n/Dropbox` |
| `\\wsl$\Ubuntu-24.04\home\user` | `/home/user` |

Use `wslpath` for exact conversion in either direction:

```bash
wslpath -u 'C:/Users/Owner/Documents'   # → /mnt/c/Users/Owner/Documents
wslpath -w /home/username/file.txt        # → \\wsl$\Ubuntu-24.04\home\username\file.txt
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

Core resource knobs (`memory`, `processors`, `swap`) are what you tune most; add `autoMemoryReclaim` to return idle RAM to Windows.

```ini
[wsl2]
memory=16GB
processors=8
swap=4GB

[experimental]
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

Edit `.wslconfig` from the Windows side (it is a Windows file). NEVER edit it from inside WSL via `/mnt/c` — line-ending corruption can make it silently ignored.

```powershell
notepad "$env:USERPROFILE/.wslconfig"
wsl --shutdown   # restart WSL to apply
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

Windows uses CRLF, Linux uses LF. CRLF in a `.sh` file breaks shebangs and silently fails scripts — keep shell scripts LF. Convert with `dos2unix script.sh` / `unix2dos script.sh`.

Configure git to manage this automatically:

```bash
git config --global core.autocrlf true    # Windows
git config --global core.autocrlf input   # WSL
```

Or pin per-file via `.gitattributes`:

```
* text=auto
*.sh text eol=lf
*.ps1 text eol=crlf
```

## Common Operations

Run from Windows (PowerShell):

```powershell
wsl --version; wsl --list --verbose; wsl --status   # status
wsl -d Ubuntu-24.04 -e free -h                       # WSL memory usage

# Reclaim disk: clean inside WSL, then shutdown and compact the VHD (admin)
wsl -d Ubuntu-24.04 -e sudo apt autoremove -y
wsl -d Ubuntu-24.04 -e sudo apt clean
wsl --shutdown
```

## Troubleshooting

- **WSL not starting**: `wsl --status`, then `wsl --update`, then `Restart-Service LxssManager`.
- **Memory not reclaimed**: add `autoMemoryReclaim=gradual` under `[experimental]` in `.wslconfig` (see template above).
- **Can't access Windows files from WSL**: ensure `/etc/wsl.conf` has `[automount] enabled=true`.
- **Permission denied on WSL files**: access them through the `\\wsl$\` path (e.g. `\\wsl$\Ubuntu-24.04\home\user`), which routes through the 9P server with correct permissions.
