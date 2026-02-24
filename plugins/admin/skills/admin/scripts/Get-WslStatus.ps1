# Get-WslStatus.ps1
# Comprehensive WSL status report
# Usage: .\scripts\Get-WslStatus.ps1 [-Distribution "Ubuntu-24.04"]

param(
    [string]$Distribution,
    [switch]$Detailed
)

Write-Host "`n=== WSL Status Report ===" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# WSL Version
Write-Host "`n## WSL Version" -ForegroundColor Yellow
try {
    $version = wsl --version 2>&1
    $version | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "  ERROR: Could not get WSL version" -ForegroundColor Red
}

# Installed Distributions
Write-Host "`n## Installed Distributions" -ForegroundColor Yellow
$distros = wsl --list --verbose 2>&1
$distros | ForEach-Object { Write-Host "  $_" }

# Determine distribution to check
if (-not $Distribution) {
    # Get default distribution
    $defaultLine = $distros | Where-Object { $_ -match '\*' } | Select-Object -First 1
    if ($defaultLine -match '\*\s+(\S+)') {
        $Distribution = $Matches[1]
    }
}

if ($Distribution) {
    Write-Host "`n## Distribution: $Distribution" -ForegroundColor Yellow

    # Check if distribution is running
    $state = ($distros | Where-Object { $_ -match $Distribution }) -split '\s+' | Select-Object -Last 1
    Write-Host "  State: $state"

    if ($state -eq "Running") {
        # Memory
        Write-Host "`n### Memory Usage" -ForegroundColor Cyan
        wsl -d $Distribution -e free -h

        # Disk
        Write-Host "`n### Disk Usage" -ForegroundColor Cyan
        wsl -d $Distribution -e df -h /

        # Load
        Write-Host "`n### System Load" -ForegroundColor Cyan
        wsl -d $Distribution -e uptime

        if ($Detailed) {
            # Top processes
            Write-Host "`n### Top Processes (by memory)" -ForegroundColor Cyan
            wsl -d $Distribution -e bash -c "ps aux --sort=-%mem | head -10"

            # Docker status
            Write-Host "`n### Docker Status" -ForegroundColor Cyan
            $dockerStatus = wsl -d $Distribution -e bash -c "docker info 2>&1 | head -5" 2>&1
            if ($dockerStatus -match "error|Cannot") {
                Write-Host "  Docker not running or not installed" -ForegroundColor Gray
            } else {
                $dockerStatus | ForEach-Object { Write-Host "  $_" }
            }
        }
    } else {
        Write-Host "  Distribution is not running. Start with: wsl -d $Distribution" -ForegroundColor Yellow
    }
}

# .wslconfig
Write-Host "`n## .wslconfig" -ForegroundColor Yellow
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Host "  Location: $wslConfigPath" -ForegroundColor Gray
    Write-Host "  Contents:" -ForegroundColor Gray
    Get-Content $wslConfigPath | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  Not found (using defaults)" -ForegroundColor Gray
    Write-Host "  Default memory: 50% of system RAM or 8GB" -ForegroundColor Gray
    Write-Host "  Default processors: All" -ForegroundColor Gray
}

# Virtual disk info
if ($Detailed) {
    Write-Host "`n## Virtual Disk Files" -ForegroundColor Yellow
    $vhdxPaths = @(
        "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.*\LocalState\ext4.vhdx",
        "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
    )

    foreach ($pattern in $vhdxPaths) {
        $vhdx = Get-ChildItem $pattern -ErrorAction SilentlyContinue
        if ($vhdx) {
            foreach ($file in $vhdx) {
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                $sizeGB = [math]::Round($file.Length / 1GB, 2)
                Write-Host "  $($file.FullName)" -ForegroundColor Gray
                Write-Host "    Size: ${sizeGB}GB (${sizeMB}MB)" -ForegroundColor Gray
            }
        }
    }
}

# Network
Write-Host "`n## Network" -ForegroundColor Yellow
if ($Distribution -and $state -eq "Running") {
    Write-Host "  WSL IP:" -ForegroundColor Gray
    wsl -d $Distribution -e hostname -I
    Write-Host "  Windows can access WSL at: localhost (via localhostForwarding)" -ForegroundColor Gray
}

Write-Host "`n=== End Report ===" -ForegroundColor Cyan
