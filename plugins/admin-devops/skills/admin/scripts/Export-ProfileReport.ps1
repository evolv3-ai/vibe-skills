# Export-ProfileReport.ps1
# Generate a comprehensive device profile report
# Usage: .\scripts\Export-ProfileReport.ps1 [-OutputFile "report.md"] [-Format "markdown"]

param(
    [string]$AdminRoot = $env:ADMIN_ROOT,
    [string]$DeviceName = $env:COMPUTERNAME,
    [string]$OutputFile,
    [ValidateSet("markdown", "json", "text")]
    [string]$Format = "markdown",
    [switch]$AllDevices,         # Report on all devices
    [switch]$IncludeLogs,        # Include recent log entries
    [int]$LogLines = 20
)

$ErrorActionPreference = "Continue"

if (-not $AdminRoot) {
    Write-Host "ERROR: ADMIN_ROOT not set" -ForegroundColor Red
    exit 1
}

$report = @()
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Header
$report += "# Device Profile Report"
$report += ""
$report += "Generated: $timestamp"
$report += ""

# Determine devices to report on
$devices = if ($AllDevices) {
    Get-ChildItem "$AdminRoot/devices" -Directory | Select-Object -ExpandProperty Name
} else {
    @($DeviceName)
}

foreach ($device in $devices) {
    $profilePath = "$AdminRoot/devices/$device/profile.json"

    if (-not (Test-Path $profilePath)) {
        $report += "## $device"
        $report += ""
        $report += "**Profile not found**"
        $report += ""
        continue
    }

    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json

    $report += "## $device"
    $report += ""

    # Device Info
    $report += "### Device Information"
    $report += ""
    $report += "| Property | Value |"
    $report += "|----------|-------|"
    $report += "| OS | $($profile.deviceInfo.os) |"
    $report += "| OS Version | $($profile.deviceInfo.osVersion) |"
    $report += "| Last Updated | $($profile.deviceInfo.lastUpdated) |"
    $report += "| Timezone | $($profile.deviceInfo.timezone) |"
    $report += ""

    # System Info
    $report += "### System Information"
    $report += ""
    $report += "| Property | Value |"
    $report += "|----------|-------|"
    $report += "| PowerShell | $($profile.systemInfo.powershellVersion) ($($profile.systemInfo.powershellEdition)) |"
    $report += "| Architecture | $($profile.systemInfo.architecture) |"
    $report += "| CPU | $($profile.systemInfo.cpu) |"
    $report += "| RAM | $($profile.systemInfo.ram) |"
    $report += ""

    # Package Managers
    $report += "### Package Managers"
    $report += ""
    $report += "| Manager | Installed | Version |"
    $report += "|---------|-----------|---------|"

    foreach ($pm in $profile.packageManagers.PSObject.Properties) {
        $status = if ($pm.Value.present) { "Yes" } else { "No" }
        $version = if ($pm.Value.version) { $pm.Value.version } else { "-" }
        $report += "| $($pm.Name) | $status | $version |"
    }
    $report += ""

    # Installed Tools
    $report += "### Installed Tools"
    $report += ""
    $report += "| Tool | Installed | Version | Via | Last Checked |"
    $report += "|------|-----------|---------|-----|--------------|"

    foreach ($tool in $profile.installedTools.PSObject.Properties) {
        $status = if ($tool.Value.present) { "Yes" } else { "No" }
        $version = if ($tool.Value.version) { $tool.Value.version } else { "-" }
        $via = if ($tool.Value.installedVia) { $tool.Value.installedVia } else { "-" }
        $checked = if ($tool.Value.lastChecked) {
            ([DateTime]$tool.Value.lastChecked).ToString("yyyy-MM-dd")
        } else { "-" }
        $report += "| $($tool.Name) | $status | $version | $via | $checked |"
    }
    $report += ""

    # Installation History
    if ($profile.installationHistory -and $profile.installationHistory.Count -gt 0) {
        $report += "### Recent Installation History"
        $report += ""
        $report += "| Date | Action | Tool | Version | Status |"
        $report += "|------|--------|------|---------|--------|"

        $history = $profile.installationHistory | Select-Object -Last 10
        foreach ($entry in $history) {
            $report += "| $($entry.date) | $($entry.action) | $($entry.tool) | $($entry.version) | $($entry.status) |"
        }
        $report += ""
    }

    # Recent Logs
    if ($IncludeLogs) {
        $logsPath = "$AdminRoot/devices/$device/logs.txt"
        if (Test-Path $logsPath) {
            $report += "### Recent Logs"
            $report += ""
            $report += "``````"
            $logs = Get-Content $logsPath -Tail $LogLines
            $logs | ForEach-Object { $report += $_ }
            $report += "``````"
            $report += ""
        }
    }

    $report += "---"
    $report += ""
}

# Cross-device comparison (if all devices)
if ($AllDevices -and $devices.Count -gt 1) {
    $report += "## Cross-Device Tool Comparison"
    $report += ""

    # Collect all tools
    $allTools = @{}

    foreach ($device in $devices) {
        $profilePath = "$AdminRoot/devices/$device/profile.json"
        if (Test-Path $profilePath) {
            $profile = Get-Content $profilePath -Raw | ConvertFrom-Json
            foreach ($tool in $profile.installedTools.PSObject.Properties) {
                if (-not $allTools.ContainsKey($tool.Name)) {
                    $allTools[$tool.Name] = @{}
                }
                $allTools[$tool.Name][$device] = $tool.Value.version
            }
        }
    }

    # Build comparison table
    $header = "| Tool |"
    $separator = "|------|"
    foreach ($device in $devices) {
        $header += " $device |"
        $separator += "--------|"
    }

    $report += $header
    $report += $separator

    foreach ($tool in $allTools.Keys | Sort-Object) {
        $row = "| $tool |"
        foreach ($device in $devices) {
            $version = $allTools[$tool][$device]
            $row += " $(if ($version) { $version } else { '-' }) |"
        }
        $report += $row
    }
    $report += ""
}

# Output
$finalReport = $report -join "`n"

if ($Format -eq "json") {
    # Convert to structured JSON
    $jsonData = @{
        generated = $timestamp
        devices = @()
    }

    foreach ($device in $devices) {
        $profilePath = "$AdminRoot/devices/$device/profile.json"
        if (Test-Path $profilePath) {
            $jsonData.devices += Get-Content $profilePath -Raw | ConvertFrom-Json
        }
    }

    $finalReport = $jsonData | ConvertTo-Json -Depth 10
}

if ($OutputFile) {
    $finalReport | Set-Content $OutputFile -Encoding UTF8
    Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
} else {
    $finalReport
}
