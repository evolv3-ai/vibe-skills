#Requires -Version 5.1
<#
.SYNOPSIS
    Shows the Admin session start summary
.DESCRIPTION
    Displays the profile location, last 3 log entries, last 3 issues, and prompts
    the user for what they need help with. This is the core loop entry point.
.EXAMPLE
    . .\Show-AdminSessionStart.ps1
    Show-AdminSessionStart
#>

[CmdletBinding()]
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import dependencies
. (Join-Path $ScriptDir "Load-Profile.ps1")
. (Join-Path $ScriptDir "Log-AdminEvent.ps1")

function Show-AdminSessionStart {
    [CmdletBinding()]
    param()

    # Colors
    $ColorCyan = "Cyan"
    $ColorYellow = "Yellow"
    $ColorGreen = "Green"
    $ColorGray = "Gray"

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    $ProfileDir = Join-Path $AdminRoot "profiles"
    $ProfilePath = Join-Path $ProfileDir "$env:COMPUTERNAME.json"

    # Check if profile exists, run setup if not
    if (-not (Test-Path $ProfilePath)) {
        Write-Host "`n=== Admin Session Start ===" -ForegroundColor $ColorCyan
        Write-Host "[WARN] No profile found for $env:COMPUTERNAME" -ForegroundColor Yellow
        Write-Host "Running setup interview..." -ForegroundColor Gray

        $SetupScript = Join-Path $ScriptDir "Setup-Interview.ps1"
        if (Test-Path $SetupScript) {
            & $SetupScript
        } else {
            Write-Host "[ERROR] Setup script not found: $SetupScript" -ForegroundColor Red
            return
        }
    }

    # Load profile
    $profile = Load-AdminProfile -Path $ProfilePath -ExportVars

    if (-not $profile) {
        Write-Host "[ERROR] Failed to load profile" -ForegroundColor Red
        return
    }

    # Display header
    Write-Host ""
    Write-Host "=== Admin Session Start ===" -ForegroundColor $ColorCyan
    Write-Host "Profile: $($profile.device.name) ($($profile.device.platform))"
    Write-Host "Location: $AdminRoot"

    # Read last 3 log entries
    Write-Host ""
    Write-Host "Recent Activity:" -ForegroundColor $ColorYellow

    $LogPath = Join-Path $AdminRoot "logs\operations.log"
    if (Test-Path $LogPath) {
        $LogLines = Get-Content $LogPath -Tail 3 -ErrorAction SilentlyContinue
        if ($LogLines) {
            foreach ($line in $LogLines) {
                # Parse log entry: [timestamp] [device] [platform] [level] message
                if ($line -match '^\[([^\]]+)\]\s+\[[^\]]+\]\s+\[[^\]]+\]\s+\[([^\]]+)\]\s+(.+)$') {
                    $timestamp = $Matches[1]
                    $level = $Matches[2]
                    $message = $Matches[3]

                    # Simplify timestamp for display
                    try {
                        $dt = [datetime]::Parse($timestamp)
                        $displayTime = $dt.ToString("yyyy-MM-dd HH:mm")
                    } catch {
                        $displayTime = $timestamp.Substring(0, 16)
                    }

                    $levelColor = switch ($level) {
                        "ERROR" { "Red" }
                        "WARN"  { "Yellow" }
                        "OK"    { "Green" }
                        default { "Gray" }
                    }

                    Write-Host "  - [$displayTime] " -NoNewline -ForegroundColor $ColorGray
                    Write-Host $message -ForegroundColor $levelColor
                } else {
                    Write-Host "  - $line" -ForegroundColor $ColorGray
                }
            }
        } else {
            Write-Host "  (no logs yet)" -ForegroundColor $ColorGray
        }
    } else {
        Write-Host "  (no logs yet)" -ForegroundColor $ColorGray
    }

    # Read last 3 issues (by modification time)
    Write-Host ""
    Write-Host "Open Issues:" -ForegroundColor $ColorYellow

    $IssuesDir = Join-Path $AdminRoot "issues"
    if (Test-Path $IssuesDir) {
        $IssueFiles = Get-ChildItem -Path $IssuesDir -Filter "issue_*.md" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 3

        if ($IssueFiles) {
            foreach ($file in $IssueFiles) {
                # Read frontmatter to get status and title
                $content = Get-Content $file.FullName -Raw
                $status = "open"
                $title = $file.BaseName

                if ($content -match '(?ms)^---\s*\n(.+?)\n---') {
                    $frontmatter = $Matches[1]
                    if ($frontmatter -match 'status:\s*(\w+)') {
                        $status = $Matches[1]
                    }
                }

                # Get title from first heading
                if ($content -match '(?m)^#\s+(.+)$') {
                    $title = $Matches[1]
                }

                # Color based on status
                $statusBadge = if ($status -eq "open") { "[OPEN]" } else { "[DONE]" }
                $statusColor = if ($status -eq "open") { "Yellow" } else { "Green" }

                Write-Host "  - " -NoNewline
                Write-Host $statusBadge -ForegroundColor $statusColor -NoNewline
                Write-Host " $($file.BaseName): $title" -ForegroundColor $ColorGray
            }
        } else {
            Write-Host "  (no issues)" -ForegroundColor $ColorGray
        }
    } else {
        Write-Host "  (no issues directory)" -ForegroundColor $ColorGray
    }

    # Prompt
    Write-Host ""
    Write-Host "What do you need help with?" -ForegroundColor $ColorCyan
    Write-Host "Categories: troubleshoot | install | devenv | mcp | skills | devops" -ForegroundColor $ColorGray
    Write-Host ""

    # Log session start
    Log-AdminEvent "Session started" -Level "INFO" | Out-Null
}

# Auto-run if dot-sourced or executed
Show-AdminSessionStart
