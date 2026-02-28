#Requires -Version 5.1
<#
.SYNOPSIS
    Tests if an admin profile exists and returns profile information
.DESCRIPTION
    Reliably checks for the admin profile, handling path resolution correctly.
    Returns JSON with profile path, existence status, and basic info if exists.
.EXAMPLE
    .\Test-AdminProfile.ps1
    Returns JSON: {"exists":true,"path":"C:\\Users\\Owner\\.admin\\profiles\\CASATEN.json","device":"CASATEN"}
.EXAMPLE
    . .\Test-AdminProfile.ps1; Test-AdminProfile
    Dot-source and call the function directly
#>

[CmdletBinding()]
param()

function Test-AdminProfile {
    [CmdletBinding()]
    param()

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    # Build profile path (use Join-Path to avoid quoting issues)
    $DeviceName = $env:COMPUTERNAME
    $ProfilePath = Join-Path $AdminRoot "profiles\$DeviceName.json"

    $result = @{
        exists = $false
        path = $ProfilePath
        device = $DeviceName
        adminRoot = $AdminRoot
    }

    if (Test-Path $ProfilePath) {
        $result.exists = $true
        try {
            $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json
            $result.schemaVersion = $profile.schemaVersion
            $result.adminSkillVersion = $profile.adminSkillVersion
            $result.platform = $profile.device.platform
        }
        catch {
            $result.parseError = $_.Exception.Message
        }
    }

    return $result | ConvertTo-Json -Compress
}

# Auto-run when executed directly
Test-AdminProfile
