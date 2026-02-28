#Requires -Version 5.1
<#
.SYNOPSIS
    Displays Admin skill and profile version information
.DESCRIPTION
    Shows the current admin skill version, profile schema version, and
    profile's adminSkillVersion. Warns if versions are mismatched.
.EXAMPLE
    .\Get-AdminVersion.ps1
.EXAMPLE
    . .\Get-AdminVersion.ps1; Get-AdminVersion
#>

[CmdletBinding()]
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $SkillRoot "VERSION"
$ChangelogFile = Join-Path $SkillRoot "CHANGELOG.md"

function Get-AdminVersion {
    [CmdletBinding()]
    param()

    # Colors
    $ColorCyan = "Cyan"
    $ColorGreen = "Green"
    $ColorYellow = "Yellow"
    $ColorRed = "Red"
    $ColorGray = "Gray"

    # Read skill version
    $SkillVersion = "unknown"
    if (Test-Path $VersionFile) {
        $SkillVersion = (Get-Content $VersionFile -First 1).Trim()
    }

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    # Read profile
    $ProfilePath = Join-Path $AdminRoot "profiles\$env:COMPUTERNAME.json"
    $ProfileVersion = $null
    $ProfileSchemaVersion = $null
    $ProfileExists = $false

    if (Test-Path $ProfilePath) {
        $ProfileExists = $true
        try {
            $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json
            $ProfileVersion = $profile.adminSkillVersion
            $ProfileSchemaVersion = $profile.schemaVersion
        }
        catch {
            Write-Host "[WARN] Failed to parse profile" -ForegroundColor $ColorYellow
        }
    }

    # Display
    Write-Host ""
    Write-Host "=== Admin Version Info ===" -ForegroundColor $ColorCyan
    Write-Host ""
    Write-Host "Skill Version:    " -NoNewline
    Write-Host $SkillVersion -ForegroundColor $ColorGreen
    Write-Host "Skill Location:   $SkillRoot" -ForegroundColor $ColorGray
    Write-Host ""

    if ($ProfileExists) {
        Write-Host "Profile Found:    $ProfilePath" -ForegroundColor $ColorGray
        Write-Host "Schema Version:   " -NoNewline
        Write-Host $ProfileSchemaVersion -ForegroundColor $ColorGreen

        if ($ProfileVersion) {
            Write-Host "Profile Created By: " -NoNewline
            if ($ProfileVersion -eq $SkillVersion) {
                Write-Host "$ProfileVersion (current)" -ForegroundColor $ColorGreen
            } else {
                Write-Host "$ProfileVersion" -ForegroundColor $ColorYellow
                Write-Host ""
                Write-Host "[WARN] Profile was created by an older skill version" -ForegroundColor $ColorYellow
                Write-Host "       Consider re-running Setup-Interview.ps1 to update" -ForegroundColor $ColorYellow
            }
        } else {
            Write-Host "Profile Created By: " -NoNewline
            Write-Host "(pre-versioning)" -ForegroundColor $ColorYellow
            Write-Host ""
            Write-Host "[WARN] Profile predates versioning system" -ForegroundColor $ColorYellow
            Write-Host "       Run Setup-Interview.ps1 to create a versioned profile" -ForegroundColor $ColorYellow
        }
        # Display skill versions comparison
        Write-Host ""
        Write-Host "--- Suite Skill Versions ---" -ForegroundColor $ColorCyan
        $SkillsRootDir = Split-Path -Parent $SkillRoot
        $SiblingSkills = @("admin", "devops", "oci", "hetzner", "contabo", "digital-ocean", "vultr", "linode", "coolify", "kasm")
        $HasMismatch = $false

        foreach ($sName in $SiblingSkills) {
            # Current version from VERSION file
            $currentVer = "n/a"
            $sibVerFile = Join-Path $SkillsRootDir "$sName\VERSION"
            if (Test-Path $sibVerFile) {
                $currentVer = (Get-Content $sibVerFile -First 1).Trim()
            }

            # Profile version from skillVersions
            $profileSV = $null
            if ($profile.skillVersions) {
                $profileSV = $profile.skillVersions.$sName
            }

            $label = $sName.PadRight(16)
            if (-not $profileSV) {
                Write-Host "  $label" -NoNewline
                Write-Host "$currentVer".PadRight(10) -ForegroundColor $ColorYellow -NoNewline
                Write-Host " (not in profile)"
                $HasMismatch = $true
            } elseif ($profileSV -eq $currentVer) {
                Write-Host "  $label" -NoNewline
                Write-Host $currentVer -ForegroundColor $ColorGreen
            } else {
                Write-Host "  $label" -NoNewline
                Write-Host "$profileSV".PadRight(10) -ForegroundColor $ColorYellow -NoNewline
                Write-Host " -> " -NoNewline
                Write-Host $currentVer -ForegroundColor $ColorGreen
                $HasMismatch = $true
            }
        }

        if ($HasMismatch) {
            Write-Host ""
            Write-Host "[WARN] Some skill versions differ from profile" -ForegroundColor $ColorYellow
            Write-Host "       Re-run profile setup to update skillVersions" -ForegroundColor $ColorYellow
        }
    } else {
        Write-Host "Profile:          " -NoNewline
        Write-Host "Not found" -ForegroundColor $ColorYellow
        Write-Host "Expected:         $ProfilePath" -ForegroundColor $ColorGray
        Write-Host ""
        Write-Host "[INFO] Run Setup-Interview.ps1 to create a profile" -ForegroundColor $ColorCyan
    }

    Write-Host ""
    Write-Host "Changelog:        $ChangelogFile" -ForegroundColor $ColorGray
    Write-Host ""

    # Return version info as object
    return [PSCustomObject]@{
        SkillVersion = $SkillVersion
        ProfileExists = $ProfileExists
        ProfileVersion = $ProfileVersion
        ProfileSchemaVersion = $ProfileSchemaVersion
        VersionMatch = ($ProfileVersion -eq $SkillVersion)
    }
}

# Auto-run
Get-AdminVersion
