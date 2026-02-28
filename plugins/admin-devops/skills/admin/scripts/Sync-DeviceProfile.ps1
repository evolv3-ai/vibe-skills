# Sync-DeviceProfile.ps1
# Verify and update device profile with current system state
# Usage: .\scripts\Sync-DeviceProfile.ps1 [-UpdateVersions] [-ResolveConflicts]

param(
    [string]$AdminRoot = $env:ADMIN_ROOT,
    [string]$DeviceName = $env:COMPUTERNAME,
    [switch]$UpdateVersions,     # Update all tool versions
    [switch]$ResolveConflicts,   # Auto-resolve sync conflicts
    [switch]$DryRun              # Show changes without applying
)

$ErrorActionPreference = "Continue"

Write-Host "`n=== Sync Device Profile ===" -ForegroundColor Cyan
Write-Host "Device: $DeviceName" -ForegroundColor Gray
Write-Host "Admin Root: $AdminRoot" -ForegroundColor Gray

if (-not $AdminRoot) {
    Write-Host "ERROR: ADMIN_ROOT not set. Use -AdminRoot parameter or set `$env:ADMIN_ROOT" -ForegroundColor Red
    exit 1
}

$profilePath = "$AdminRoot/devices/$DeviceName/profile.json"

if (-not (Test-Path $profilePath)) {
    Write-Host "ERROR: Profile not found: $profilePath" -ForegroundColor Red
    Write-Host "Run Initialize-DeviceProfile.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Check for sync conflicts
$conflictFiles = Get-ChildItem "$AdminRoot/devices/$DeviceName/profile*.json" -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne "profile.json" }

if ($conflictFiles.Count -gt 0) {
    Write-Host "`nWARNING: Found $($conflictFiles.Count) conflict file(s):" -ForegroundColor Yellow
    $conflictFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }

    if ($ResolveConflicts) {
        Write-Host "`nResolving conflicts..." -ForegroundColor Cyan
        # Merge logic would go here (simplified for now)
        foreach ($conflict in $conflictFiles) {
            if (-not $DryRun) {
                Remove-Item $conflict.FullName
                Write-Host "  Removed: $($conflict.Name)" -ForegroundColor Gray
            } else {
                Write-Host "  Would remove: $($conflict.Name)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "Use -ResolveConflicts to auto-resolve" -ForegroundColor Gray
    }
}

# Load profile
$profile = Get-Content $profilePath -Raw | ConvertFrom-Json

Write-Host "`nProfile last updated: $($profile.deviceInfo.lastUpdated)" -ForegroundColor Gray

# Verify and update tools
Write-Host "`n=== Tool Verification ===" -ForegroundColor Yellow

$changes = @()

foreach ($tool in $profile.installedTools.PSObject.Properties) {
    $name = $tool.Name
    $info = $tool.Value

    Write-Host "`n$name`:" -ForegroundColor Cyan

    # Check if tool exists
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    $actuallyPresent = $null -ne $cmd
    $actualVersion = $null

    if ($cmd) {
        try {
            $actualVersion = & $name --version 2>&1 | Select-Object -First 1
            $actualVersion = $actualVersion -replace '^v', ''
        } catch {}
    }

    # Compare with profile
    $profilePresent = $info.present
    $profileVersion = $info.version

    Write-Host "  Profile: present=$profilePresent, version=$profileVersion" -ForegroundColor Gray
    Write-Host "  Actual:  present=$actuallyPresent, version=$actualVersion" -ForegroundColor Gray

    # Detect changes
    if ($profilePresent -ne $actuallyPresent) {
        $change = "presence changed ($profilePresent -> $actuallyPresent)"
        Write-Host "  CHANGE: $change" -ForegroundColor Yellow
        $changes += [PSCustomObject]@{
            Tool = $name
            Field = "present"
            Old = $profilePresent
            New = $actuallyPresent
        }

        if (-not $DryRun) {
            $profile.installedTools.$name.present = $actuallyPresent
        }
    }

    if ($UpdateVersions -and $actualVersion -and ($profileVersion -ne $actualVersion)) {
        $change = "version changed ($profileVersion -> $actualVersion)"
        Write-Host "  CHANGE: $change" -ForegroundColor Yellow
        $changes += [PSCustomObject]@{
            Tool = $name
            Field = "version"
            Old = $profileVersion
            New = $actualVersion
        }

        if (-not $DryRun) {
            $profile.installedTools.$name.version = $actualVersion
        }
    }

    # Update lastChecked
    if (-not $DryRun) {
        $profile.installedTools.$name.lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    # Update path if found
    if ($cmd -and -not $DryRun) {
        $profile.installedTools.$name.path = $cmd.Source
    }
}

# Verify package managers
Write-Host "`n=== Package Manager Verification ===" -ForegroundColor Yellow

$pkgManagers = @("winget", "scoop", "npm", "choco")

foreach ($pm in $pkgManagers) {
    $cmd = Get-Command $pm -ErrorAction SilentlyContinue
    $exists = $null -ne $cmd

    if ($profile.packageManagers.$pm) {
        $profileExists = $profile.packageManagers.$pm.present

        if ($profileExists -ne $exists) {
            Write-Host "$pm`: presence changed ($profileExists -> $exists)" -ForegroundColor Yellow
            if (-not $DryRun) {
                $profile.packageManagers.$pm.present = $exists
            }
        }

        if ($exists -and $UpdateVersions -and -not $DryRun) {
            try {
                $version = & $pm --version 2>&1 | Select-Object -First 1
                $profile.packageManagers.$pm.version = $version -replace '^v', ''
            } catch {}
        }

        if (-not $DryRun) {
            $profile.packageManagers.$pm.lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        }
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($changes.Count -eq 0) {
    Write-Host "No changes detected" -ForegroundColor Green
} else {
    Write-Host "Changes detected: $($changes.Count)" -ForegroundColor Yellow
    $changes | Format-Table -AutoSize
}

# Save profile
if ($changes.Count -gt 0 -or $UpdateVersions) {
    if ($DryRun) {
        Write-Host "`nDry run - no changes saved" -ForegroundColor Yellow
    } else {
        $profile.deviceInfo.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        $profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath -Encoding UTF8
        Write-Host "`nProfile saved: $profilePath" -ForegroundColor Green

        # Log sync
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp - [$DeviceName] SUCCESS: Sync - Profile synchronized ($($changes.Count) changes)"
        Add-Content "$AdminRoot/devices/$DeviceName/logs.txt" -Value $logEntry
    }
}

Write-Host ""
