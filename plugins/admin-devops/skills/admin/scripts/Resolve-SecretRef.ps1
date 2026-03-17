#Requires -Version 5.1
<#
.SYNOPSIS
    Resolve Secret Ref - Parse infisical:// URIs and fetch secrets
.DESCRIPTION
    Parses URIs of the form: infisical://PROJECT/ENV/FOLDER/KEY
    Resolves project slug to ID via mapping file, calls infisical secrets get
    with --path and --projectId, falls back to vault.
.PARAMETER Uri
    Full infisical:// URI (e.g., infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN)
.PARAMETER Project
    Project slug (alternative to URI)
.PARAMETER Environment
    Environment slug (default: prod)
.PARAMETER Path
    Folder path within the project (default: /)
.PARAMETER Key
    Secret key name
.PARAMETER Method
    Auth method: cli-login or universal-auth
.PARAMETER Quiet
    Suppress warning messages
.EXAMPLE
    .\Resolve-SecretRef.ps1 "infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN"
.EXAMPLE
    .\Resolve-SecretRef.ps1 -Project admin-operator -Environment prod -Path /providers/hetzner -Key HCLOUD_TOKEN
#>

[CmdletBinding(DefaultParameterSetName = 'Uri')]
param(
    [Parameter(Position = 0, ParameterSetName = 'Uri')]
    [string]$Uri,

    [Parameter(ParameterSetName = 'Explicit')]
    [string]$Project,

    [Parameter(ParameterSetName = 'Explicit')]
    [string]$Environment = "prod",

    [Parameter(ParameterSetName = 'Explicit')]
    [string]$Path = "/",

    [Parameter(ParameterSetName = 'Explicit')]
    [string]$Key,

    [Parameter()]
    [ValidateSet('cli-login', 'universal-auth')]
    [string]$Method,

    [switch]$Quiet
)

# --- Resolve paths ---
function Get-AdminRoot {
    if ($env:ADMIN_ROOT) { return $env:ADMIN_ROOT }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_ROOT=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return Join-Path $HOME ".admin"
}

function Resolve-AgeKeyPath {
    if ($env:AGE_KEY_PATH) { return $env:AGE_KEY_PATH }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^AGE_KEY_PATH=(.+)$" | Select-Object -First 1
        if ($match) {
            $keyPath = $match.Matches.Groups[1].Value
            if ($keyPath -match '^/mnt/([a-z])/(.+)$') {
                $keyPath = "$($matches[1].ToUpper()):\$($matches[2] -replace '/', '\')"
            }
            return $keyPath
        }
    }
    return Join-Path $HOME ".age\key.txt"
}

$AdminRoot = Get-AdminRoot
$AgeKey = Resolve-AgeKeyPath
$VaultFile = Join-Path $AdminRoot "vault.age"
$ProjectsFile = if ($env:INFISICAL_PROJECTS) { $env:INFISICAL_PROJECTS } else { Join-Path $AdminRoot "config\infisical-projects.json" }

# --- Parse URI ---
function Parse-InfisicalUri {
    param([string]$UriString)

    if ($UriString -notmatch '^infisical://') {
        Write-Error "URI must start with infisical://"
        return $null
    }

    $path = $UriString -replace '^infisical://', ''
    $parts = $path -split '/'

    if ($parts.Count -lt 3) {
        Write-Error "URI must have at least project/env/key: $UriString"
        return $null
    }

    $result = @{
        Project = $parts[0]
        Environment = $parts[1]
        Key = $parts[$parts.Count - 1]
        Path = "/"
    }

    if ($parts.Count -gt 3) {
        $folderParts = $parts[2..($parts.Count - 2)]
        $result.Path = "/" + ($folderParts -join "/")
    }

    return $result
}

# --- Resolve project slug to ID ---
function Resolve-ProjectId {
    param([string]$Slug)

    # Check projects mapping file
    if (Test-Path $ProjectsFile) {
        try {
            $config = Get-Content $ProjectsFile -Raw | ConvertFrom-Json
            $projectId = $config.projects.$Slug.id
            if ($projectId) { return $projectId }
        } catch {}
    }

    # Check if slug is already a UUID
    if ($Slug -match '^[0-9a-f-]{36}$') { return $Slug }

    # Check env var
    $envVarName = "INFISICAL_PROJECT_ID_" + ($Slug.ToUpper() -replace '-', '_')
    $envVal = [Environment]::GetEnvironmentVariable($envVarName)
    if ($envVal) { return $envVal }

    # Legacy fallback
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^INFISICAL_PROJECT_ID=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }

    Write-Error "Cannot resolve project slug '$Slug' to ID"
    return $null
}

# --- Fetch from Infisical ---
function Get-InfisicalSecretByRef {
    param(
        [string]$ProjectId,
        [string]$EnvSlug,
        [string]$FolderPath,
        [string]$SecretKey,
        [string]$AuthMethod
    )

    if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) { return $null }

    $args = @("secrets", "get", $SecretKey, "--projectId", $ProjectId, "--env", $EnvSlug, "--plain")

    if ($FolderPath -ne "/") {
        $args += @("--path", $FolderPath)
    }

    # Handle universal-auth
    if ($AuthMethod -eq 'universal-auth' -and -not $env:INFISICAL_UNIVERSAL_AUTH_CLIENT_ID) {
        if ((Test-Path $VaultFile) -and (Test-Path $AgeKey)) {
            try {
                $vaultContent = & age --decrypt -i $AgeKey $VaultFile 2>$null
                foreach ($line in $vaultContent) {
                    if ($line -match '^INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=(.+)$') {
                        $env:INFISICAL_UNIVERSAL_AUTH_CLIENT_ID = $matches[1]
                    }
                    if ($line -match '^INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=(.+)$') {
                        $env:INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET = $matches[1]
                    }
                }
            } catch {}
        }
    }

    try {
        $result = & infisical @args 2>$null
        if ($result) { return $result }
    } catch {}

    return $null
}

# --- Vault fallback ---
function Get-VaultFallback {
    param([string]$SecretKey)

    if (-not (Test-Path $VaultFile) -or -not (Test-Path $AgeKey)) { return $null }

    try {
        $lines = & age --decrypt -i $AgeKey $VaultFile 2>$null
        foreach ($line in $lines) {
            if ($line -match "^${SecretKey}=(.*)$") {
                return $matches[1] -replace '^["'']|["'']$'
            }
        }
    } catch {}

    return $null
}

# --- Main ---
if ($Uri) {
    $parsed = Parse-InfisicalUri -UriString $Uri
    if (-not $parsed) { exit 1 }
    $Project = $parsed.Project
    $Environment = $parsed.Environment
    $Path = $parsed.Path
    $Key = $parsed.Key
}

if (-not $Project -or -not $Key) {
    Write-Error "Must provide either a URI or -Project + -Key"
    exit 1
}

if (-not $Environment) { $Environment = "prod" }
if (-not $Path) { $Path = "/" }

# Resolve project slug to ID
$projectId = Resolve-ProjectId -Slug $Project
if (-not $projectId) { $projectId = "" }

# Try Infisical
if ($projectId) {
    $value = Get-InfisicalSecretByRef -ProjectId $projectId -EnvSlug $Environment -FolderPath $Path -SecretKey $Key -AuthMethod $Method
    if ($value) {
        Write-Output $value
        exit 0
    }
    if (-not $Quiet) {
        Write-Warning "Infisical lookup failed, trying vault fallback"
    }
}

# Vault fallback
$value = Get-VaultFallback -SecretKey $Key
if ($value) {
    Write-Output $value
    exit 0
}

Write-Error "Secret '$Key' not found in Infisical (project: $Project, env: $Environment, path: $Path) or vault"
exit 1
