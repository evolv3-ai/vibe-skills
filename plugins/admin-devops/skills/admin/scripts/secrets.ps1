#Requires -Version 5.1
<#
.SYNOPSIS
    Admin Vault - age-encrypted secrets management (PowerShell)
.DESCRIPTION
    PowerShell equivalent of the bash secrets CLI wrapper.
    Uses age encryption to manage secrets stored in $ADMIN_ROOT/vault.age.
.EXAMPLE
    .\secrets.ps1 HCLOUD_TOKEN          # Get single secret
    .\secrets.ps1 -List                 # List all keys
    .\secrets.ps1 -Export               # KEY=value format
    .\secrets.ps1 -Source               # PowerShell $env: format
    .\secrets.ps1 -Decrypt              # Show all plaintext
    .\secrets.ps1 -Encrypt path.env     # Encrypt file to vault
    .\secrets.ps1 -Status               # Show vault status
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

    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help
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
    Write-Host "Admin Vault Status"
    Write-Host ("─" * 36)

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
if ($List) { Get-SecretKeys; return }
if ($Export) { Get-SecretExport; return }
if ($Decrypt) { Invoke-DecryptVault; return }
if ($Encrypt) { Invoke-EncryptFile -InputFile $Encrypt; return }
if ($Source) {
    Get-SecretExport | ForEach-Object {
        if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $val = $matches[2] -replace '^["'']|["'']$'
            "`$env:$($matches[1]) = '$val'"
        }
    }
    return
}

if ($KeyName) {
    Get-SecretValue -Key $KeyName
    return
}

Write-Host "Usage: .\secrets.ps1 KEY | -List | -Export | -Source | -Decrypt | -Encrypt FILE | -Status | -Help" -ForegroundColor Yellow
exit 1
