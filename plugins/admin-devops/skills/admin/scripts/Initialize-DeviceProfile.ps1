# Initialize-DeviceProfile.ps1
# Set up device profile and directory structure for a new device
# Usage: .\scripts\Initialize-DeviceProfile.ps1 -AdminRoot "$env:USERPROFILE/.admin"

param(
    [Parameter(Mandatory)]
    [string]$AdminRoot,

    [string]$DeviceName = $env:COMPUTERNAME,

    [switch]$Force  # Overwrite existing profile
)

Write-Host "`n=== Initialize Device Profile ===" -ForegroundColor Cyan
Write-Host "Admin Root: $AdminRoot" -ForegroundColor Gray
Write-Host "Device: $DeviceName" -ForegroundColor Gray

# Verify admin root exists or create it
if (-not (Test-Path $AdminRoot)) {
    Write-Host "`nCreating admin root directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $AdminRoot -Force | Out-Null
}

# Create directory structure
$directories = @(
    "$AdminRoot/devices/$DeviceName",
    "$AdminRoot/logs/central",
    "$AdminRoot/registries",
    "$AdminRoot/configs"
)

Write-Host "`nCreating directory structure..." -ForegroundColor Yellow
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Exists: $dir" -ForegroundColor Gray
    }
}

# Create profile.json
$profilePath = "$AdminRoot/devices/$DeviceName/profile.json"

if ((Test-Path $profilePath) -and -not $Force) {
    Write-Host "`nProfile already exists: $profilePath" -ForegroundColor Yellow
    Write-Host "Use -Force to overwrite" -ForegroundColor Gray
} else {
    Write-Host "`nCreating device profile..." -ForegroundColor Yellow

    # Gather system info
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

    # Check package managers
    $hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    $hasScoop = $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
    $hasNpm = $null -ne (Get-Command npm -ErrorAction SilentlyContinue)
    $hasChoco = $null -ne (Get-Command choco -ErrorAction SilentlyContinue)

    # Build profile
    $profile = [ordered]@{
        schemaVersion = "1.0"
        deviceInfo = [ordered]@{
            name = $DeviceName
            os = $osInfo.Caption
            osVersion = $osInfo.Version
            lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            adminRoot = $AdminRoot
            timezone = (Get-TimeZone).Id
        }
        packageManagers = [ordered]@{
            winget = [ordered]@{
                present = $hasWinget
                version = if ($hasWinget) { (winget --version 2>&1) -replace '^v', '' } else { $null }
                lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                location = if ($hasWinget) { (Get-Command winget).Source } else { $null }
            }
            scoop = [ordered]@{
                present = $hasScoop
                version = if ($hasScoop) { (scoop --version 2>&1 | Select-Object -First 1) } else { $null }
                lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                location = if ($hasScoop) { (Get-Command scoop).Source } else { $null }
            }
            npm = [ordered]@{
                present = $hasNpm
                version = if ($hasNpm) { (npm --version 2>&1) } else { $null }
                lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                location = if ($hasNpm) { (Get-Command npm).Source } else { $null }
            }
            chocolatey = [ordered]@{
                present = $hasChoco
                version = if ($hasChoco) { (choco --version 2>&1) } else { $null }
                lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                location = if ($hasChoco) { (Get-Command choco).Source } else { $null }
            }
        }
        installedTools = [ordered]@{}
        installationHistory = @()
        systemInfo = [ordered]@{
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            powershellEdition = $PSVersionTable.PSEdition
            architecture = $env:PROCESSOR_ARCHITECTURE
            cpu = $cpuInfo.Name
            ram = "${ramGB}GB"
            lastSystemCheck = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        }
        paths = [ordered]@{
            npmGlobal = "$env:APPDATA/npm"
            scoopShims = "$env:USERPROFILE/scoop/shims"
            mcpRoot = "D:/mcp"
            projectsRoot = "D:/projects"
        }
    }

    # Detect common tools
    $commonTools = @("git", "node", "python", "claude", "code")

    foreach ($tool in $commonTools) {
        $cmd = Get-Command $tool -ErrorAction SilentlyContinue
        $version = $null

        if ($cmd) {
            try {
                $version = & $tool --version 2>&1 | Select-Object -First 1
            } catch {}
        }

        $profile.installedTools[$tool] = [ordered]@{
            present = $null -ne $cmd
            version = $version
            lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            installedVia = "unknown"
            path = if ($cmd) { $cmd.Source } else { $null }
            shimPath = $null
            notes = $null
        }
    }

    # Save profile
    $profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath -Encoding UTF8
    Write-Host "  Created: $profilePath" -ForegroundColor Green
}

# Create log files
$logFiles = @(
    "$AdminRoot/devices/$DeviceName/logs.txt",
    "$AdminRoot/logs/central/operations.log",
    "$AdminRoot/logs/central/installations.log",
    "$AdminRoot/logs/central/system-changes.log"
)

Write-Host "`nCreating log files..." -ForegroundColor Yellow
foreach ($logFile in $logFiles) {
    if (-not (Test-Path $logFile)) {
        "" | Set-Content $logFile
        Write-Host "  Created: $logFile" -ForegroundColor Green
    } else {
        Write-Host "  Exists: $logFile" -ForegroundColor Gray
    }
}

# Log initialization
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logEntry = "$timestamp - [$DeviceName] SUCCESS: Initialize - Device profile initialized"

Add-Content "$AdminRoot/devices/$DeviceName/logs.txt" -Value $logEntry
Add-Content "$AdminRoot/logs/central/operations.log" -Value $logEntry

Write-Host "`n=== Initialization Complete ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Set environment variable: `$env:ADMIN_ROOT = '$AdminRoot'" -ForegroundColor Gray
Write-Host "  2. Review profile: Get-Content '$profilePath' | ConvertFrom-Json" -ForegroundColor Gray
Write-Host "  3. Update installedVia fields for detected tools" -ForegroundColor Gray
