#Requires -Version 5.1
<#
.SYNOPSIS
    Admin Secrets - multi-backend secrets management (PowerShell)
.DESCRIPTION
    Supports three backends: infisical (cloud), vault (age-encrypted), env (plaintext).
    Uses satellite ~/.admin/.env to resolve backend, paths, and Infisical config.
.EXAMPLE
    .\secrets.ps1 HCLOUD_TOKEN              # Get from current backend
    .\secrets.ps1 -List                     # List all keys
    .\secrets.ps1 -Export                   # KEY=value format
    .\secrets.ps1 -Source                   # PowerShell $env: format
    .\secrets.ps1 -Decrypt                  # Show vault plaintext
    .\secrets.ps1 -Encrypt path.env         # Encrypt file to vault
    .\secrets.ps1 -Status                   # Show backend status
    .\secrets.ps1 -Backend infisical -List  # Force Infisical backend
    .\secrets.ps1 -MigrateToInfisical       # Push vault -> Infisical
#>

[CmdletBinding(DefaultParameterSetName = 'GetKey')]
param(
    [Parameter(Position = 0, ParameterSetName = 'GetKey')]
    [string]$KeyName,

    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(ParameterSetName = 'Export')]
    [switch]$Export,

    [Parameter(ParameterSetName = 'Source')]
    [switch]$Source,

    [Parameter(ParameterSetName = 'Decrypt')]
    [switch]$Decrypt,

    [Parameter(ParameterSetName = 'Encrypt')]
    [string]$Encrypt,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Migrate')]
    [switch]$MigrateToInfisical,

    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    [Parameter()]
    [ValidateSet('infisical', 'vault', 'env')]
    [string]$Backend,

    [Parameter()]
    [string]$Path,

    [Parameter()]
    [Alias('ProjectSlug')]
    [string]$Project
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

$AdminRoot = Get-AdminRoot
$AgeKey = Resolve-AgeKey
$VaultFile = Join-Path $AdminRoot "vault.age"

# --- Backend resolution ---
function Resolve-SecretsBackend {
    if ($Backend) { return $Backend }
    if ($env:ADMIN_SECRETS_BACKEND) { return $env:ADMIN_SECRETS_BACKEND }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^ADMIN_SECRETS_BACKEND=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return "vault"
}

function Resolve-InfisicalProjectId {
    if ($env:INFISICAL_PROJECT_ID) { return $env:INFISICAL_PROJECT_ID }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^INFISICAL_PROJECT_ID=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return $null
}

function Resolve-InfisicalEnv {
    if ($env:INFISICAL_ENVIRONMENT) { return $env:INFISICAL_ENVIRONMENT }
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        $match = Select-String -Path $satelliteEnv -Pattern "^INFISICAL_ENVIRONMENT=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return "prod"
}

$SecretsBackend = Resolve-SecretsBackend

# --- Project slug resolution ---
$ProjectsFile = Join-Path $AdminRoot "config\infisical-projects.json"

function Resolve-ProjectSlug {
    param([string]$Slug)
    if (Test-Path $ProjectsFile) {
        try {
            $config = Get-Content $ProjectsFile -Raw | ConvertFrom-Json
            $pid = $config.projects.$Slug.id
            if ($pid) { return $pid }
        } catch {}
    }
    if ($Slug -match '^[0-9a-f-]{36}$') { return $Slug }
    $envVarName = "INFISICAL_PROJECT_ID_" + ($Slug.ToUpper() -replace '-', '_')
    $envVal = [Environment]::GetEnvironmentVariable($envVarName)
    if ($envVal) { return $envVal }
    Write-Error "Cannot resolve project slug '$Slug'"
    return $null
}

# Resolve --Project flag to project ID override
$ProjectIdOverride = $null
if ($Project) {
    $ProjectIdOverride = Resolve-ProjectSlug -Slug $Project
    if (-not $ProjectIdOverride) { exit 1 }
}

# --- Infisical operations ---
function Test-InfisicalReady {
    if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
        Write-Error "infisical CLI not installed. See: https://infisical.com/docs/cli/overview"
        return $false
    }
    $projectId = Resolve-InfisicalProjectId
    if (-not $projectId) {
        Write-Error "INFISICAL_PROJECT_ID not set in satellite .env or environment"
        return $false
    }
    return $true
}

function Get-InfisicalSecret {
    param([string]$Key)
    $projectId = if ($ProjectIdOverride) { $ProjectIdOverride } else { Resolve-InfisicalProjectId }
    $envSlug = Resolve-InfisicalEnv
    $args = @("secrets", "get", $Key, "--projectId", $projectId, "--env", $envSlug, "--plain")
    if ($Path) { $args += @("--path", $Path) }
    & infisical @args 2>$null
}

function Get-InfisicalKeys {
    $projectId = if ($ProjectIdOverride) { $ProjectIdOverride } else { Resolve-InfisicalProjectId }
    $envSlug = Resolve-InfisicalEnv
    $args = @("secrets", "--projectId", $projectId, "--env", $envSlug)
    if ($Path) { $args += @("--path", $Path) }
    $output = & infisical @args 2>$null
    $output | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ } | Sort-Object
}

function Get-InfisicalExport {
    $projectId = if ($ProjectIdOverride) { $ProjectIdOverride } else { Resolve-InfisicalProjectId }
    $envSlug = Resolve-InfisicalEnv
    $args = @("export", "--projectId", $projectId, "--env", $envSlug, "--format=dotenv")
    if ($Path) { $args += @("--path", $Path) }
    & infisical @args 2>$null
}

# --- Fallback wrappers ---
function Get-SecretWithFallback {
    param([string]$Key)
    $value = $null
    switch ($SecretsBackend) {
        'infisical' {
            if (Test-InfisicalReady) {
                $value = Get-InfisicalSecret -Key $Key
            }
            if (-not $value -and (Test-Path $VaultFile) -and (Test-Path $AgeKey)) {
                $lines = Invoke-DecryptVault
                foreach ($line in $lines) {
                    if ($line -match "^${Key}=(.*)$") { $value = $matches[1] -replace '^["'']|["'']$'; break }
                }
            }
        }
        'vault' {
            $value = Get-SecretValue -Key $Key
            return $value
        }
        'env' {
            $masterEnv = Join-Path $AdminRoot ".env"
            if (Test-Path $masterEnv) {
                $match = Select-String -Path $masterEnv -Pattern "^${Key}=(.+)$" | Select-Object -First 1
                if ($match) { $value = $match.Matches.Groups[1].Value }
            }
        }
    }
    if (-not $value) {
        Write-Error "Secret '$Key' not found (backend: $SecretsBackend)"
        exit 1
    }
    return $value
}

function Get-KeysWithFallback {
    switch ($SecretsBackend) {
        'infisical' {
            if (Test-InfisicalReady) { return Get-InfisicalKeys }
            return Get-SecretKeys
        }
        'vault' { return Get-SecretKeys }
        'env' {
            $masterEnv = Join-Path $AdminRoot ".env"
            if (Test-Path $masterEnv) {
                Get-Content $masterEnv | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } |
                    ForEach-Object { ($_ -split '=', 2)[0] } | Sort-Object
            }
        }
    }
}

function Get-ExportWithFallback {
    switch ($SecretsBackend) {
        'infisical' {
            if (Test-InfisicalReady) { return Get-InfisicalExport }
            return Get-SecretExport
        }
        'vault' { return Get-SecretExport }
        'env' {
            $masterEnv = Join-Path $AdminRoot ".env"
            if (Test-Path $masterEnv) {
                Get-Content $masterEnv | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' -and $_ -match '=' }
            }
        }
    }
}

function Invoke-MigrateToInfisical {
    Assert-AgeKey
    Assert-Vault
    if (-not (Test-InfisicalReady)) { exit 1 }

    $projectId = Resolve-InfisicalProjectId
    $envSlug = Resolve-InfisicalEnv
    Write-Host "Migrating vault secrets to Infisical..."
    $count = 0

    $lines = Invoke-DecryptVault
    foreach ($line in $lines) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $key = ($line -split '=', 2)[0]
        $val = ($line -split '=', 2)[1]
        Write-Host -NoNewline "  $key... "
        try {
            & infisical secrets set "${key}=${val}" --projectId $projectId --env $envSlug 2>$null | Out-Null
            Write-Host "OK"
            $count++
        } catch {
            Write-Host "FAILED" -ForegroundColor Red
        }
    }
    Write-Host ""
    Write-Host "Migrated $count secrets to Infisical (project: $projectId, env: $envSlug)"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Verify: .\secrets.ps1 -Backend infisical -List"
    Write-Host "  2. Update satellite .env: ADMIN_SECRETS_BACKEND=infisical"
    Write-Host "  3. Keep vault.age as offline fallback"
}

# --- Validation ---
function Assert-AgeKey {
    if (-not (Test-Path $AgeKey)) {
        Write-Error "Age key not found at $AgeKey`nGenerate one with: age-keygen -o $AgeKey"
        exit 1
    }
}

function Assert-Vault {
    if (-not (Test-Path $VaultFile)) {
        Write-Error "Vault not found at $VaultFile`nCreate one with: .\secrets.ps1 -Encrypt path\to\.env"
        exit 1
    }
}

# --- Core operations ---
function Invoke-DecryptVault {
    Assert-AgeKey
    Assert-Vault
    & age --decrypt -i $AgeKey $VaultFile 2>$null
}

function Get-SecretValue {
    param([string]$Key)
    $lines = Invoke-DecryptVault
    foreach ($line in $lines) {
        if ($line -match "^${Key}=(.*)$") {
            return $matches[1] -replace '^["'']|["'']$'
        }
    }
    Write-Error "Secret '$Key' not found in vault"
    exit 1
}

function Get-SecretKeys {
    $lines = Invoke-DecryptVault
    $lines | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' -and $_ -match '=' } |
        ForEach-Object { ($_ -split '=', 2)[0] } | Sort-Object
}

function Get-SecretExport {
    $lines = Invoke-DecryptVault
    $lines | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' -and $_ -match '=' }
}

function Invoke-EncryptFile {
    param([string]$InputFile)
    if (-not (Test-Path $InputFile)) {
        Write-Error "File not found: $InputFile"
        exit 1
    }
    Assert-AgeKey
    $publicKey = & age-keygen -y $AgeKey 2>$null
    & age -e -r $publicKey -a -o $VaultFile $InputFile
    $count = (Get-Content $InputFile | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' }).Count
    Write-Host "Encrypted: $InputFile -> $VaultFile ($count secrets)"
}

function Show-VaultStatus {
    Write-Host "Admin Secrets Status"
    Write-Host ("─" * 36)
    Write-Host "Backend:     $SecretsBackend"
    Write-Host ""

    # Infisical status
    if ($SecretsBackend -eq 'infisical' -or (Get-Command infisical -ErrorAction SilentlyContinue)) {
        Write-Host "Infisical:"
        if (Get-Command infisical -ErrorAction SilentlyContinue) {
            $projectId = Resolve-InfisicalProjectId
            $envSlug = Resolve-InfisicalEnv
            Write-Host "  CLI:       installed"
            Write-Host "  Project:   $(if ($projectId) { $projectId } else { 'not set' })"
            Write-Host "  Env:       $envSlug"
            if ($projectId) {
                try {
                    & infisical secrets --projectId $projectId --env $envSlug 2>$null | Out-Null
                    Write-Host "  Auth:      OK"
                } catch {
                    Write-Host "  Auth:      FAILED (run: infisical login)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  CLI:       NOT INSTALLED" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    Write-Host "Age key:     $AgeKey"
    if (Test-Path $AgeKey) {
        $publicKey = & age-keygen -y $AgeKey 2>$null
        Write-Host "  Status:    OK"
        Write-Host "  Public:    $publicKey"
    } else {
        Write-Host "  Status:    MISSING" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Vault:       $VaultFile"
    if (Test-Path $VaultFile) {
        $size = (Get-Item $VaultFile).Length
        Write-Host "  Status:    OK ($size bytes)"
        try {
            $count = (Invoke-DecryptVault | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' }).Count
            Write-Host "  Secrets:   $count"
        } catch {
            Write-Host "  Secrets:   ? (decrypt failed)"
        }
    } else {
        Write-Host "  Status:    NOT CREATED" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Satellite:   $(Join-Path $HOME '.admin\.env')"
    $satelliteEnv = Join-Path $HOME ".admin\.env"
    if (Test-Path $satelliteEnv) {
        Write-Host "  ADMIN_ROOT=$AdminRoot"
        $vaultMatch = Select-String -Path $satelliteEnv -Pattern "^ADMIN_VAULT=(.+)$" | Select-Object -First 1
        $vaultMode = if ($vaultMatch) { $vaultMatch.Matches.Groups[1].Value } else { "not set" }
        Write-Host "  ADMIN_VAULT=$vaultMode"
        $backendMatch = Select-String -Path $satelliteEnv -Pattern "^ADMIN_SECRETS_BACKEND=(.+)$" | Select-Object -First 1
        $backendMode = if ($backendMatch) { $backendMatch.Matches.Groups[1].Value } else { "not set" }
        Write-Host "  ADMIN_SECRETS_BACKEND=$backendMode"
    } else {
        Write-Host "  Status:    MISSING" -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host @"
Admin Vault - age-encrypted secrets management (PowerShell)

Usage:
  .\secrets.ps1 KEY                - Get value for KEY
  .\secrets.ps1 -List              - List all secret keys
  .\secrets.ps1 -Export            - Export all secrets (KEY=value format)
  .\secrets.ps1 -Source            - Output for PowerShell env (set-item)
  .\secrets.ps1 -Decrypt           - Decrypt and display all secrets
  .\secrets.ps1 -Encrypt FILE      - Encrypt plaintext file to vault
  .\secrets.ps1 -Status            - Show vault status and paths
  .\secrets.ps1 -Help              - Show this help

Examples:
  .\secrets.ps1 HCLOUD_TOKEN              # Get Hetzner API token
  `$token = .\secrets.ps1 HCLOUD_TOKEN    # Store in variable
  .\secrets.ps1 -Source | Invoke-Expression  # Load all to env

Files:
  Key:       $AgeKey
  Vault:     $VaultFile
"@
}

# --- Main ---
if ($Help) { Show-Help; return }
if ($Status) { Show-VaultStatus; return }
if ($MigrateToInfisical) { Invoke-MigrateToInfisical; return }
if ($List) { Get-KeysWithFallback; return }
if ($Export) { Get-ExportWithFallback; return }
if ($Decrypt) { Invoke-DecryptVault; return }
if ($Encrypt) { Invoke-EncryptFile -InputFile $Encrypt; return }
if ($Source) {
    Get-ExportWithFallback | ForEach-Object {
        if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $val = $matches[2] -replace '^["'']|["'']$'
            "`$env:$($matches[1]) = '$val'"
        }
    }
    return
}

if ($KeyName) {
    Get-SecretWithFallback -Key $KeyName
    return
}

Write-Host "Usage: .\secrets.ps1 KEY | -List | -Export | -Source | -Decrypt | -Encrypt FILE | -Status | -Backend | -MigrateToInfisical | -Help" -ForegroundColor Yellow
exit 1
