# Centralized Logging System

Unified logging across all admin operations and devices.

## Contents
- Log File Strategy
- Log Entry Format
- Bash Logging Function
- PowerShell Logging Function
- Reading Logs
- Log Rotation (Optional)
- Best Practices

---

## Log File Strategy

| Log File | Location | Purpose |
|----------|----------|---------|
| Device Log | `devices/{DEVICE}/logs.txt` | All operations on this device |
| Operations Log | `logs/central/operations.log` | General operations (all devices) |
| Installations Log | `logs/central/installations.log` | Software installations only |
| System Changes Log | `logs/central/system-changes.log` | Config/registry changes |
| Handoffs Log | `logs/central/handoffs.log` | Cross-platform handoffs |

## Log Entry Format

### Standard Format

```
YYYY-MM-DDTHH:MM:SS±HH:MM [DEVICE][PLATFORM] LEVEL: Operation - Details
```

Example entries:
```
2025-12-08T14:30:15-05:00 [<DEVICE_NAME>][wsl] SUCCESS: Install - Installed git via apt
2025-12-08T14:31:00-05:00 [<DEVICE_NAME>][windows] ERROR: Install - Python installation failed
2025-12-08T14:32:00-05:00 [<DEVICE_NAME>][wsl] HANDOFF: Windows task required - Update .wslconfig
```

### Log Levels

| Level | Color | Use Case |
|-------|-------|----------|
| SUCCESS | Green | Completed operations |
| ERROR | Red | Failed operations |
| WARNING | Yellow | Non-critical issues |
| INFO | White | General information |
| HANDOFF | Cyan | Cross-platform coordination |

## Bash Logging Function

For WSL, Linux, and macOS:

```bash
log_admin() {
    local level="$1"      # INFO|SUCCESS|ERROR|WARN|HANDOFF
    local category="$2"   # operation|installation|system-change|handoff
    local message="$3"
    local details="${4:-}"

    # Get values with defaults
    local timestamp=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
    local device="${DEVICE_NAME:-$(hostname)}"
    local platform="${ADMIN_PLATFORM:-$(detect_platform)}"
    local log_dir="${ADMIN_LOG_PATH:-$HOME/.admin/logs}"

    # Construct log line
    local log_line="$timestamp [$device][$platform] $level: $message"
    [[ -n "$details" ]] && log_line="$log_line | $details"

    # Ensure directories exist
    mkdir -p "$log_dir/devices/$device" 2>/dev/null

    # Write to category log
    echo "$log_line" >> "$log_dir/${category}s.log"

    # Write to device history
    echo "$log_line" >> "$log_dir/devices/$device/history.log"

    # Console output for errors
    [[ "$level" == "ERROR" ]] && echo "ERROR: $message" >&2
}

# Platform detection helper (case-insensitive grep for WSL)
detect_platform() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OS" == "Windows_NT" ]]; then
        echo "windows"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}
```

### Usage Examples (Bash)

```bash
# Installation logging
log_admin "SUCCESS" "installation" "Installed Docker" "version=24.0.7 method=apt"
log_admin "ERROR" "installation" "Python install failed" "error=dependency conflict"

# Operation logging
log_admin "INFO" "operation" "Session started" "user=$USER"
log_admin "SUCCESS" "operation" "Backup completed" "size=2.3GB"

# System change logging
log_admin "SUCCESS" "system-change" "Updated PATH" "added=/usr/local/go/bin"
log_admin "WARNING" "system-change" "Config modified" "file=~/.bashrc"

# Handoff logging
log_admin "HANDOFF" "handoff" "Windows task required" "task=update .wslconfig"
```

## PowerShell Logging Function

For Windows:

```powershell
function Log-Operation {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("SUCCESS", "ERROR", "INFO", "PENDING", "WARNING", "HANDOFF")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [string]$Details,

        [ValidateSet("operation", "installation", "system-change", "handoff")]
        [string]$LogType = "operation",

        [string]$AdminRoot = $env:ADMIN_ROOT,
        [string]$DeviceName = $env:COMPUTERNAME
    )

    # Default admin root
    if (-not $AdminRoot) {
        $AdminRoot = "$env:USERPROFILE\.admin"
    }

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $platform = "windows"
    $logEntry = "$timestamp [$DeviceName][$platform] $Status: $Operation - $Details"

    # Ensure directories exist
    $deviceLogDir = "$AdminRoot\logs\devices\$DeviceName"
    $centralLogDir = "$AdminRoot\logs"

    New-Item -ItemType Directory -Path $deviceLogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $centralLogDir -Force | Out-Null

    # Always log to device log
    Add-Content "$deviceLogDir\history.log" -Value $logEntry

    # Log to appropriate central log
    $centralLog = switch ($LogType) {
        "installation" { "$centralLogDir\installations.log" }
        "system-change" { "$centralLogDir\system-changes.log" }
        "handoff" { "$centralLogDir\handoffs.log" }
        default { "$centralLogDir\operations.log" }
    }
    Add-Content $centralLog -Value $logEntry

    # Console output with color
    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "PENDING" { "Cyan" }
        "HANDOFF" { "Cyan" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}
```

### Usage Examples (PowerShell)

```powershell
# Installation logging
Log-Operation -Status "SUCCESS" -Operation "Install" -Details "Installed git 2.47.0 via winget" -LogType "installation"
Log-Operation -Status "ERROR" -Operation "Install" -Details "Python installation failed: scoop error" -LogType "installation"

# Operation logging
Log-Operation -Status "INFO" -Operation "Session" -Details "WinAdmin session started"
Log-Operation -Status "SUCCESS" -Operation "Backup" -Details "Registry backup completed"

# System change logging
Log-Operation -Status "SUCCESS" -Operation "Config" -Details "Updated PATH in registry" -LogType "system-change"

# Handoff logging
Log-Operation -Status "HANDOFF" -Operation "Cross-Platform" -Details "WSL task required: install Docker" -LogType "handoff"
```

## Reading Logs

### Bash

```bash
# Read recent device logs
tail -20 "${ADMIN_LOG_PATH:-$HOME/.admin/logs}/devices/${DEVICE_NAME:-$(hostname)}/history.log"

# Read recent installations
tail -20 "${ADMIN_LOG_PATH:-$HOME/.admin/logs}/installations.log"

# Search logs for errors
grep "ERROR" "${ADMIN_LOG_PATH:-$HOME/.admin/logs}"/*.log

# Search by date
grep "2025-12-08" "${ADMIN_LOG_PATH:-$HOME/.admin/logs}/operations.log"
```

### PowerShell

```powershell
function Get-RecentLogs {
    param(
        [int]$Lines = 20,
        [ValidateSet("device", "operations", "installations", "system-changes", "handoffs", "all")]
        [string]$LogType = "device",
        [string]$AdminRoot = $env:ADMIN_ROOT,
        [string]$DeviceName = $env:COMPUTERNAME
    )

    if (-not $AdminRoot) {
        $AdminRoot = "$env:USERPROFILE\.admin"
    }

    $logs = switch ($LogType) {
        "device" { @("$AdminRoot\logs\devices\$DeviceName\history.log") }
        "operations" { @("$AdminRoot\logs\operations.log") }
        "installations" { @("$AdminRoot\logs\installations.log") }
        "system-changes" { @("$AdminRoot\logs\system-changes.log") }
        "handoffs" { @("$AdminRoot\logs\handoffs.log") }
        "all" {
            @(
                "$AdminRoot\logs\devices\$DeviceName\history.log",
                "$AdminRoot\logs\operations.log",
                "$AdminRoot\logs\installations.log",
                "$AdminRoot\logs\system-changes.log",
                "$AdminRoot\logs\handoffs.log"
            )
        }
    }

    foreach ($log in $logs) {
        if (Test-Path $log) {
            Write-Host "`n=== $(Split-Path $log -Leaf) ===" -ForegroundColor Cyan
            Get-Content $log -Tail $Lines
        }
    }
}

# Usage
Get-RecentLogs -Lines 10 -LogType "device"
Get-RecentLogs -Lines 50 -LogType "all"
```

## Log Rotation (Optional)

For long-running systems, implement log rotation:

### Bash

```bash
rotate_logs() {
    local log_dir="${ADMIN_LOG_PATH:-$HOME/.admin/logs}"
    local max_size=10485760  # 10MB

    for log in "$log_dir"/*.log; do
        if [[ -f "$log" ]] && [[ $(stat -f%z "$log" 2>/dev/null || stat -c%s "$log") -gt $max_size ]]; then
            mv "$log" "${log}.$(date +%Y%m%d)"
            gzip "${log}.$(date +%Y%m%d)"
            touch "$log"
            log_admin "INFO" "operation" "Rotated log" "file=$(basename $log)"
        fi
    done
}
```

### PowerShell

```powershell
function Invoke-LogRotation {
    param(
        [string]$AdminRoot = $env:ADMIN_ROOT,
        [int]$MaxSizeMB = 10
    )

    if (-not $AdminRoot) {
        $AdminRoot = "$env:USERPROFILE\.admin"
    }

    $maxBytes = $MaxSizeMB * 1MB

    Get-ChildItem "$AdminRoot\logs\*.log" | Where-Object {
        $_.Length -gt $maxBytes
    } | ForEach-Object {
        $archiveName = "$($_.FullName).$(Get-Date -Format 'yyyyMMdd')"
        Move-Item $_.FullName $archiveName
        Compress-Archive -Path $archiveName -DestinationPath "$archiveName.zip"
        Remove-Item $archiveName
        New-Item $_.FullName -ItemType File | Out-Null
        Log-Operation -Status "INFO" -Operation "Maintenance" -Details "Rotated log: $($_.Name)"
    }
}
```

## Best Practices

1. **Always log** - Every operation should have a log entry
2. **Be specific** - Include version numbers, file paths, command details
3. **Use correct level** - SUCCESS for completed, ERROR for failures
4. **Include context** - Add details that help debugging
5. **Consistent format** - Always use ISO 8601 timestamps
6. **Both logs** - Write to both device and central logs
7. **Don't delete** - Logs are append-only, use rotation instead
