#Requires -Version 5.1
<#
.SYNOPSIS
    Admin Suite Profile Loader - Loads device profile and deployment configs
.DESCRIPTION
    Reads profile.json and associated .env.local files, making context available
    for scripts and AI assistants.
.PARAMETER ProfilePath
    Path to profile.json (defaults to $HOME/.admin/profiles/$env:COMPUTERNAME.json)
.PARAMETER Deployment
    Optional: Load specific deployment's .env.local
.PARAMETER Export
    Export variables to current session
.EXAMPLE
    . .\Load-Profile.ps1
    Load-AdminProfile -Export
.EXAMPLE
    Load-AdminProfile -Deployment "vibeskills-oci" -Export
#>

[CmdletBinding()]
param(
    [string]$ProfilePath,
    [string]$Deployment,
    [switch]$Export,
    [switch]$Quiet
)

# Default profile location
$DefaultProfileDir = Join-Path $HOME ".admin\profiles"
$DefaultProfilePath = Join-Path $DefaultProfileDir "$env:COMPUTERNAME.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $Quiet) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "OK"    { "Green" }
            default { "Cyan" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Load-AdminProfile {
    [CmdletBinding()]
    param(
        [string]$Path = $DefaultProfilePath,
        [string]$DeploymentName,
        [switch]$ExportVars
    )

    if (-not $Path) { $Path = $DefaultProfilePath }
    
    if (-not (Test-Path $Path)) {
        Write-Log "Profile not found: $Path" "ERROR"
        Write-Log "Run Initialize-AdminProfile to create one" "WARN"
        return $null
    }

    Write-Log "Loading profile: $Path"
    
    try {
        $profile = Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log "Failed to parse profile: $_" "ERROR"
        return $null
    }

    if ($profile.schemaVersion -ne "3.0") {
        Write-Log "Profile schema version $($profile.schemaVersion) - expected 3.0" "WARN"
    }

    Write-Log "Device: $($profile.device.name) ($($profile.device.platform))" "OK"
    Write-Log "Tools: $($profile.tools.PSObject.Properties.Count) registered"
    Write-Log "Servers: $($profile.servers.Count) managed"

    if ($ExportVars) {
        $global:AdminProfile = $profile
        Write-Log "Exported `$AdminProfile to session" "OK"
    }

    if ($DeploymentName) {
        $deployment = $profile.deployments.$DeploymentName
        if (-not $deployment) {
            Write-Log "Deployment '$DeploymentName' not found in profile" "ERROR"
            Write-Log "Available: $($profile.deployments.PSObject.Properties.Name -join ', ')" "WARN"
        }
        elseif ($deployment.envFile -and (Test-Path $deployment.envFile)) {
            Write-Log "Loading deployment: $DeploymentName"
            $envVars = Load-EnvFile -Path $deployment.envFile
            if ($ExportVars -and $envVars) {
                $global:DeploymentEnv = $envVars
                Write-Log "Exported `$DeploymentEnv to session ($($envVars.Count) vars)" "OK"
            }
        }
        else {
            Write-Log "Deployment '$DeploymentName' has no envFile or file not found" "WARN"
        }
    }

    return $profile
}

function Load-EnvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$ExportToEnvironment
    )

    if (-not (Test-Path $Path)) {
        Write-Log "Env file not found: $Path" "ERROR"
        return $null
    }

    Write-Log "Parsing: $Path"
    
    $vars = @{}
    $lines = Get-Content $Path

    foreach ($line in $lines) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            
            $vars[$key] = $value
            
            if ($ExportToEnvironment) {
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }

    Write-Log "Loaded $($vars.Count) variables" "OK"
    return $vars
}

# --- Vault support ---
function Resolve-AgeKey {
    if ($env:AGE_KEY_PATH) { return $env:AGE_KEY_PATH }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^AGE_KEY_PATH=(.+)$" | Select-Object -First 1
        if ($match) {
            $keyPath = $match.Matches.Groups[1].Value
            # Convert WSL paths to Windows paths (e.g., /mnt/c/Users/... -> C:\Users\...)
            if ($keyPath -match '^/mnt/([a-z])/(.+)$') {
                $keyPath = "$($matches[1].ToUpper()):\$($matches[2] -replace '/', '\')"
            }
            return $keyPath
        }
    }
    return Join-Path $HOME ".age\key.txt"
}

$AgeKey = Resolve-AgeKey

# Resolve vault path from ADMIN_ROOT (same as Get-AdminRoot but inline for bootstrap)
$_adminRoot = $null
$_satelliteEnv = Join-Path $HOME ".admin\.env"
if (Test-Path $_satelliteEnv) {
    $_match = Select-String -Path $_satelliteEnv -Pattern "^ADMIN_ROOT=(.+)$" | Select-Object -First 1
    if ($_match) {
        $_adminRoot = $_match.Matches.Groups[1].Value
        # Convert WSL paths to Windows paths
        if ($_adminRoot -match '^/mnt/([a-z])/(.+)$') {
            $_adminRoot = "$($matches[1].ToUpper()):\$($matches[2] -replace '/', '\')"
        }
    }
}
if (-not $_adminRoot) { $_adminRoot = Join-Path $HOME ".admin" }
$VaultFile = Join-Path $_adminRoot "vault.age"

function Get-VaultMode {
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if ($env:ADMIN_VAULT) { return $env:ADMIN_VAULT }
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_VAULT=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return "disabled"
}

function Test-VaultReady {
    $status = @{ Ready = $true; Missing = @() }

    if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
        $status.Ready = $false
        $status.Missing += "age CLI (install: scoop install age)"
    }
    if (-not (Test-Path $AgeKey)) {
        $status.Ready = $false
        $status.Missing += "Age key ($AgeKey) - generate: age-keygen -o $AgeKey"
    }

    # Resolve vault path from ADMIN_ROOT
    $adminRoot = $null
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_ROOT=(.+)$" | Select-Object -First 1
        if ($match) { $adminRoot = $match.Matches.Groups[1].Value }
    }
    if (-not $adminRoot) { $adminRoot = Join-Path $HOME ".admin" }
    $script:VaultFile = Join-Path $adminRoot "vault.age"

    if (-not (Test-Path $script:VaultFile)) {
        $status.Ready = $false
        $status.Missing += "Vault file ($($script:VaultFile)) - run: secrets --encrypt .env"
    }

    return $status
}

function Load-Vault {
    [CmdletBinding()]
    param([switch]$ExportToEnvironment)

    $vaultStatus = Test-VaultReady
    if (-not $vaultStatus.Ready) {
        foreach ($m in $vaultStatus.Missing) {
            Write-Log "Vault dep missing: $m" "WARN"
        }
        return $null
    }

    Write-Log "Decrypting vault: $script:VaultFile"

    try {
        $plaintext = & age --decrypt -i $AgeKey $script:VaultFile 2>$null
    }
    catch {
        Write-Log "Vault decryption failed: $_" "ERROR"
        return $null
    }

    if (-not $plaintext) {
        Write-Log "Vault decryption returned empty output" "ERROR"
        return $null
    }

    $vars = @{}
    foreach ($line in $plaintext -split "`n") {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            $vars[$key] = $value
            if ($ExportToEnvironment) {
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }

    Write-Log "Loaded $($vars.Count) secrets from vault" "OK"
    return $vars
}

function Load-AdminSecrets {
    [CmdletBinding()]
    param([switch]$ExportToEnvironment)

    $mode = Get-VaultMode

    if ($mode -eq "enabled") {
        $result = Load-Vault -ExportToEnvironment:$ExportToEnvironment
        if ($result) {
            if ($ExportToEnvironment) {
                $global:AdminSecrets = $result
            }
            return $result
        }
        Write-Log "Vault enabled but failed - falling back to plaintext .env" "WARN"
    }

    # Fallback: plaintext .env
    $adminRoot = $null
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_ROOT=(.+)$" | Select-Object -First 1
        if ($match) { $adminRoot = $match.Matches.Groups[1].Value }
    }
    if (-not $adminRoot) { $adminRoot = Join-Path $HOME ".admin" }
    $masterEnv = Join-Path $adminRoot ".env"

    if (Test-Path $masterEnv) {
        Write-Log "Loading secrets from plaintext .env"
        $result = Load-EnvFile -Path $masterEnv -ExportToEnvironment:$ExportToEnvironment
        if ($ExportToEnvironment -and $result) {
            $global:AdminSecrets = $result
        }
        return $result
    }

    return $null
}

function Get-AdminTool {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    if (-not $global:AdminProfile) {
        Write-Log "Profile not loaded. Run Load-AdminProfile -Export first" "ERROR"
        return $null
    }

    $tool = $global:AdminProfile.tools.$Name
    if (-not $tool) { Write-Log "Tool '$Name' not in profile" "WARN"; return $null }
    return $tool
}

function Get-AdminServer {
    [CmdletBinding()]
    param([string]$Id, [string]$Role, [string]$Provider)

    if (-not $global:AdminProfile) {
        Write-Log "Profile not loaded" "ERROR"; return $null
    }

    $servers = $global:AdminProfile.servers
    if ($Id) { return $servers | Where-Object { $_.id -eq $Id } }
    if ($Role) { return $servers | Where-Object { $_.role -eq $Role } }
    if ($Provider) { return $servers | Where-Object { $_.provider -eq $Provider } }
    return $servers
}

function Get-AdminPreference {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet("python", "node", "packages", "shell", "editor", "terminal")][string]$Category)

    if (-not $global:AdminProfile) { Write-Log "Profile not loaded" "ERROR"; return $null }
    return $global:AdminProfile.preferences.$Category
}

function Test-AdminCapability {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Capability)

    if (-not $global:AdminProfile) { return $false }
    return $global:AdminProfile.capabilities.$Capability -eq $true
}

function Show-AdminSummary {
    if (-not $global:AdminProfile) { Write-Log "Profile not loaded" "ERROR"; return }

    $p = $global:AdminProfile
    
    Write-Host "`n=== Admin Profile Summary ===" -ForegroundColor Cyan
    Write-Host "Device:     $($p.device.name) ($($p.device.platform))"
    Write-Host "User:       $($p.device.user)"
    Write-Host "Shell:      $($p.preferences.shell.preferred)"
    Write-Host ""
    
    Write-Host "Preferences:" -ForegroundColor Yellow
    Write-Host "  Python:   $($p.preferences.python.manager)"
    Write-Host "  Node:     $($p.preferences.node.manager)"
    Write-Host "  Packages: $($p.preferences.packages.manager)"
    Write-Host ""
    
    Write-Host "Capabilities:" -ForegroundColor Yellow
    $caps = @()
    if ($p.capabilities.hasWsl) { $caps += "WSL" }
    if ($p.capabilities.hasDocker) { $caps += "Docker" }
    if ($p.capabilities.mcpEnabled) { $caps += "MCP" }
    if ($p.capabilities.canAccessDropbox) { $caps += "Dropbox" }
    Write-Host "  $($caps -join ', ')"
    Write-Host ""
    
    Write-Host "Servers ($($p.servers.Count)):" -ForegroundColor Yellow
    foreach ($s in $p.servers) {
        $status = if ($s.status -eq "active") { "[+]" } else { "[ ]" }
        Write-Host "  $status $($s.name) ($($s.role)) - $($s.host)"
    }
    Write-Host ""
    
    Write-Host "Deployments:" -ForegroundColor Yellow
    foreach ($d in $p.deployments.PSObject.Properties) {
        $dep = $d.Value
        $hasEnv = if ($dep.envFile) { "[+]" } else { "[ ]" }
        Write-Host "  $hasEnv $($d.Name) ($($dep.type)/$($dep.provider)) - $($dep.status)"
    }
    Write-Host ""
}

if ($Export) {
    $loadedProfile = Load-AdminProfile -Path $ProfilePath -DeploymentName $Deployment -ExportVars
    if ($loadedProfile) {
        Load-AdminSecrets -ExportToEnvironment
        Show-AdminSummary
    }
}

# Note: Functions are available after dot-sourcing this script
# Usage: . .\Load-Profile.ps1; Load-AdminProfile -Export
