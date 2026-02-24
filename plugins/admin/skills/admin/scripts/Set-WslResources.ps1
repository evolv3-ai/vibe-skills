# Set-WslResources.ps1
# Configure WSL2 resource allocation
# Usage: .\scripts\Set-WslResources.ps1 -Memory 16GB -Processors 8 -Swap 4GB

param(
    [string]$Memory = "16GB",
    [int]$Processors = 8,
    [string]$Swap = "4GB",
    [switch]$EnableMemoryReclaim,
    [switch]$EnableSparseVhd,
    [switch]$NoRestart,
    [switch]$DryRun
)

$wslConfigPath = "$env:USERPROFILE\.wslconfig"

Write-Host "`n=== Configure WSL Resources ===" -ForegroundColor Cyan
Write-Host "Config path: $wslConfigPath" -ForegroundColor Gray

# Backup existing config
if (Test-Path $wslConfigPath) {
    $backupPath = "$wslConfigPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $wslConfigPath $backupPath
    Write-Host "Backup created: $backupPath" -ForegroundColor Green
}

# Build configuration
$config = @"
# WSL2 Configuration
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# By: Set-WslResources.ps1

[wsl2]
# Memory allocation
memory=$Memory

# Processor count
processors=$Processors

# Swap size
swap=$Swap

# Enable localhost forwarding (Windows can access WSL services)
localhostForwarding=true

# Enable nested virtualization
nestedVirtualization=true

# Enable GUI applications (WSLg)
guiApplications=true
"@

# Add experimental features if requested
if ($EnableMemoryReclaim -or $EnableSparseVhd) {
    $config += "`n`n[experimental]"

    if ($EnableMemoryReclaim) {
        $config += "`n# Automatically reclaim cached memory"
        $config += "`nautoMemoryReclaim=gradual"
    }

    if ($EnableSparseVhd) {
        $config += "`n# Enable sparse VHD for automatic compaction"
        $config += "`nsparseVhd=true"
    }
}

# Display configuration
Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host $config -ForegroundColor Gray

if ($DryRun) {
    Write-Host "`nDry run - no changes made" -ForegroundColor Yellow
    return
}

# Write configuration
$config | Set-Content $wslConfigPath -Encoding UTF8
Write-Host "`nConfiguration saved to: $wslConfigPath" -ForegroundColor Green

# Restart WSL if requested
if (-not $NoRestart) {
    Write-Host "`nRestarting WSL to apply changes..." -ForegroundColor Yellow

    # Get running distributions
    $running = wsl --list --running 2>&1

    # Shutdown WSL
    wsl --shutdown
    Write-Host "WSL shutdown complete" -ForegroundColor Green

    Start-Sleep 2

    # Verify with status check
    Write-Host "`nVerifying new configuration..." -ForegroundColor Yellow

    # Start default distribution and check memory
    $defaultDistro = (wsl --list 2>&1 | Where-Object { $_ -match '\*' }) -replace '\*\s+', '' -replace '\s.*', ''

    if ($defaultDistro) {
        Write-Host "Starting $defaultDistro..." -ForegroundColor Gray
        wsl -d $defaultDistro -e free -h
    }
} else {
    Write-Host "`nRun 'wsl --shutdown' to apply changes" -ForegroundColor Yellow
}

# Log the change
if ($env:ADMIN_ROOT) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - [$env:COMPUTERNAME] SUCCESS: WSL Config - Set memory=$Memory, processors=$Processors, swap=$Swap"
    $logsPath = "$env:ADMIN_ROOT/devices/$env:COMPUTERNAME/logs.txt"
    if (Test-Path (Split-Path $logsPath)) {
        Add-Content $logsPath -Value $logEntry
    }
    $centralLog = "$env:ADMIN_ROOT/logs/central/system-changes.log"
    if (Test-Path (Split-Path $centralLog)) {
        Add-Content $centralLog -Value $logEntry
    }
    Write-Host "`nLogged to admin logs" -ForegroundColor Gray
}

Write-Host "`nDone!" -ForegroundColor Green
