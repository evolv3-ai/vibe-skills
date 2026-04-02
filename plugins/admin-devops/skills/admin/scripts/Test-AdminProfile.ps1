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

    # Satellite .env path
    $satelliteEnv = Join-Path $HOME ".admin\.env"

    # Priority 1: ADMIN_ROOT env var already set
    if ($env:ADMIN_ROOT) {
        $AdminRoot = $env:ADMIN_ROOT
        $DeviceName = if ($env:ADMIN_DEVICE) { $env:ADMIN_DEVICE } else { $env:COMPUTERNAME }
        $Platform = $env:ADMIN_PLATFORM

    # Priority 2: Satellite .env file (primary mechanism)
    } elseif (Test-Path $satelliteEnv) {
        $satVars = @{}
        foreach ($line in Get-Content $satelliteEnv) {
            if ($line -match '^([A-Z_]+)=(.*)$') { $satVars[$matches[1]] = $matches[2] }
        }
        $AdminRoot = if ($satVars['ADMIN_ROOT']) { $satVars['ADMIN_ROOT'] } else { Join-Path $HOME ".admin" }
        $DeviceName = if ($satVars['ADMIN_DEVICE']) { $satVars['ADMIN_DEVICE'] } else { $env:COMPUTERNAME }
        $Platform = $satVars['ADMIN_PLATFORM']

    # Priority 3: Legacy fallback
    } else {
        $AdminRoot = Join-Path $HOME ".admin"
        $DeviceName = $env:COMPUTERNAME
        $Platform = $null
    }

    # Build profile path
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

    # Add satellite-derived metadata
    if ($Platform) { $result.platform = $Platform }
    if (Test-Path $satelliteEnv) {
        if (-not $satVars) {
            $satVars = @{}
            foreach ($line in Get-Content $satelliteEnv) {
                if ($line -match '^([A-Z_]+)=(.*)$') { $satVars[$matches[1]] = $matches[2] }
            }
        }
        $result.secretsBackend = if ($satVars['ADMIN_SECRETS_BACKEND']) { $satVars['ADMIN_SECRETS_BACKEND'] } else { "vault" }
        if ($satVars['ADMIN_PROFILE_REPO']) { $result.profileRepo = $satVars['ADMIN_PROFILE_REPO'] }

        # Preferences (parity with bash)
        $prefs = @{}
        if ($satVars['ADMIN_PKG_MGR']) { $prefs.packages = $satVars['ADMIN_PKG_MGR'] }
        if ($satVars['ADMIN_WIN_PKG_MGR']) { $prefs.winPackages = $satVars['ADMIN_WIN_PKG_MGR'] }
        if ($satVars['ADMIN_PY_MGR']) { $prefs.python = $satVars['ADMIN_PY_MGR'] }
        if ($satVars['ADMIN_NODE_MGR']) { $prefs.node = $satVars['ADMIN_NODE_MGR'] }
        if ($satVars['ADMIN_SHELL']) { $prefs.shell = $satVars['ADMIN_SHELL'] }
        if ($prefs.Count -gt 0) { $result.preferences = $prefs }
    }

    return $result | ConvertTo-Json -Compress
}

# Auto-run when executed directly
Test-AdminProfile
