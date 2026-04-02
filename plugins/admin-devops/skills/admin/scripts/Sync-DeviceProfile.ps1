# Sync-DeviceProfile.ps1
# Verify and update device profile with current system state
# Optionally sync profiles directory with a private GitHub repo
# Usage: .\scripts\Sync-DeviceProfile.ps1 [-UpdateVersions] [-ResolveConflicts] [-RepoSync]

param(
    [string]$AdminRoot = $env:ADMIN_ROOT,
    [string]$DeviceName = $env:COMPUTERNAME,
    [switch]$UpdateVersions,     # Update all tool versions
    [switch]$ResolveConflicts,   # Auto-resolve sync conflicts
    [switch]$DryRun,             # Show changes without applying
    [switch]$RepoSync,           # Sync profiles dir with GitHub repo
    [switch]$RepoInit,           # Initialize profiles dir as git repo
    [switch]$RepoStatus          # Show repo sync status
)

$ErrorActionPreference = "Continue"

Write-Host "`n=== Sync Device Profile ===" -ForegroundColor Cyan
Write-Host "Device: $DeviceName" -ForegroundColor Gray
Write-Host "Admin Root: $AdminRoot" -ForegroundColor Gray

if (-not $AdminRoot) {
    Write-Host "ERROR: ADMIN_ROOT not set. Use -AdminRoot parameter or set `$env:ADMIN_ROOT" -ForegroundColor Red
    exit 1
}

$profilePath = "$AdminRoot/profiles/$DeviceName.json"

if (-not (Test-Path $profilePath)) {
    Write-Host "ERROR: Profile not found: $profilePath" -ForegroundColor Red
    Write-Host "Run New-AdminProfile.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Check for sync conflicts
$conflictFiles = Get-ChildItem "$AdminRoot/profiles/$DeviceName*.json" -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne "$DeviceName.json" }

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

Write-Host "`nProfile last updated: $($profile.device.lastUpdated)" -ForegroundColor Gray

# Verify and update tools
Write-Host "`n=== Tool Verification ===" -ForegroundColor Yellow

$changes = @()

foreach ($tool in $profile.tools.PSObject.Properties) {
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
            $profile.tools.$name.present = $actuallyPresent
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
            $profile.tools.$name.version = $actualVersion
        }
    }

    # Update lastChecked
    if (-not $DryRun) {
        $profile.tools.$name.lastChecked = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    # Update path if found
    if ($cmd -and -not $DryRun) {
        $profile.tools.$name.path = $cmd.Source
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
        $profile.device.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        $profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath -Encoding UTF8
        Write-Host "`nProfile saved: $profilePath" -ForegroundColor Green

        # Log sync
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp - [$DeviceName] SUCCESS: Sync - Profile synchronized ($($changes.Count) changes)"
        $logDir = Join-Path $AdminRoot "logs"
        if (-not (Test-Path $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }
        Add-Content (Join-Path $logDir "operations.log") -Value $logEntry
    }
}

# =============================================================================
# GitHub Repo Sync
# =============================================================================

function Get-ProfileRepo {
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_PROFILE_REPO=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return $null
}

function Get-ProfilesDir {
    return Join-Path $AdminRoot "profiles"
}

function Test-GitRepo {
    param([string]$Path)
    try {
        $null = git -C $Path rev-parse --is-inside-work-tree 2>$null
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

function Invoke-RepoInit {
    $repo = Get-ProfileRepo
    if (-not $repo) {
        Write-Host "ERROR: ADMIN_PROFILE_REPO not set in satellite .env" -ForegroundColor Red
        return
    }
    $profilesDir = Get-ProfilesDir
    if (Test-GitRepo $profilesDir) {
        Write-Host "Already a git repo: $profilesDir" -ForegroundColor Yellow
        return
    }
    Write-Host "Initializing git repo in $profilesDir" -ForegroundColor Cyan
    git -C $profilesDir init -b main
    git -C $profilesDir remote add origin $repo
    git -C $profilesDir add -A
    $fileCount = (git -C $profilesDir diff --cached --name-only | Measure-Object).Count
    if ($fileCount -gt 0) {
        git -C $profilesDir commit -m "feat: initial profile sync ($fileCount files)"
        git -C $profilesDir push -u origin main
        Write-Host "Initialized and pushed $fileCount files" -ForegroundColor Green
    } else {
        Write-Host "No files to commit" -ForegroundColor Yellow
    }
}

function Invoke-RepoPull {
    $profilesDir = Get-ProfilesDir
    if (-not (Test-GitRepo $profilesDir)) {
        Write-Host "Not a git repo: $profilesDir (use -RepoInit first)" -ForegroundColor Red
        return
    }
    Write-Host "Pulling profile repo..." -ForegroundColor Cyan
    git -C $profilesDir pull --rebase --autostash
    Write-Host "Pull complete" -ForegroundColor Green
}

function Invoke-RepoPush {
    $profilesDir = Get-ProfilesDir
    if (-not (Test-GitRepo $profilesDir)) {
        Write-Host "Not a git repo: $profilesDir (use -RepoInit first)" -ForegroundColor Red
        return
    }
    $status = git -C $profilesDir status --porcelain
    if (-not $status) {
        Write-Host "No local changes to push" -ForegroundColor Gray
        return
    }
    git -C $profilesDir add -A
    $changed = (git -C $profilesDir diff --cached --name-only | Select-Object -First 5) -join ', '
    git -C $profilesDir commit -m "sync($DeviceName): profile update ($changed)"
    git -C $profilesDir push
    Write-Host "Pushed profile changes" -ForegroundColor Green
}

function Show-RepoStatus {
    $profilesDir = Get-ProfilesDir
    $repo = Get-ProfileRepo
    Write-Host "`nProfile Repo Sync Status" -ForegroundColor Cyan
    Write-Host ("─" * 36)
    Write-Host "Profiles dir:  $profilesDir"
    Write-Host "Repo:          $(if ($repo) { $repo } else { 'not configured' })"
    if (-not $repo) {
        Write-Host "Status:        DISABLED" -ForegroundColor Yellow
        return
    }
    if (-not (Test-GitRepo $profilesDir)) {
        Write-Host "Status:        NOT INITIALIZED (use -RepoInit)" -ForegroundColor Yellow
        return
    }
    $status = git -C $profilesDir status --porcelain
    if ($status) {
        Write-Host "Local changes: YES" -ForegroundColor Yellow
        $status | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "Local changes: none" -ForegroundColor Green
    }
    $branch = git -C $profilesDir branch --show-current 2>$null
    Write-Host "Branch:        $branch"
    Write-Host "Remote:        $(git -C $profilesDir remote get-url origin 2>$null)"
}

# Handle repo sync commands
if ($RepoInit) { Invoke-RepoInit; Write-Host ""; return }
if ($RepoStatus) { Show-RepoStatus; Write-Host ""; return }
if ($RepoSync) {
    $repo = Get-ProfileRepo
    if ($repo -and (Test-GitRepo (Get-ProfilesDir))) {
        Invoke-RepoPull
        Invoke-RepoPush
    } else {
        Write-Host "Repo sync not configured or not initialized" -ForegroundColor Yellow
    }
    Write-Host ""
    return
}

Write-Host ""
