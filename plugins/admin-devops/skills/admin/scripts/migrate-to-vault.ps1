#Requires -Version 5.1
<#
.SYNOPSIS
    Migrate plaintext .env to age-encrypted vault
.DESCRIPTION
    Encrypts $ADMIN_ROOT\.env to $ADMIN_ROOT\vault.age using age encryption.
    Verifies round-trip integrity and optionally enables ADMIN_VAULT in satellite .env.
.PARAMETER SourceEnv
    Path to plaintext .env file (default: $ADMIN_ROOT\.env)
.EXAMPLE
    .\migrate-to-vault.ps1
.EXAMPLE
    .\migrate-to-vault.ps1 -SourceEnv C:\path\to\custom.env
#>

[CmdletBinding()]
param(
    [string]$SourceEnv
)

$AgeKey = Join-Path $HOME ".age\key.txt"
$SatelliteEnv = Join-Path $HOME ".admin\.env"

# Resolve ADMIN_ROOT
function Get-AdminRoot {
    if ($env:ADMIN_ROOT) { return $env:ADMIN_ROOT }
    if (Test-Path $SatelliteEnv) {
        $match = Select-String -Path $SatelliteEnv -Pattern "^ADMIN_ROOT=(.+)$" | Select-Object -First 1
        if ($match) { return $match.Matches.Groups[1].Value }
    }
    return Join-Path $HOME ".admin"
}

$AdminRoot = Get-AdminRoot
$VaultFile = Join-Path $AdminRoot "vault.age"
if (-not $SourceEnv) { $SourceEnv = Join-Path $AdminRoot ".env" }

Write-Host "`n=== Admin Vault Migration ===" -ForegroundColor Cyan
Write-Host "Source:  $SourceEnv"
Write-Host "Vault:   $VaultFile"
Write-Host "Key:     $AgeKey"
Write-Host ""

# Step 1: Check prerequisites
Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Cyan

if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] age not installed. Install: scoop install age" -ForegroundColor Red
    exit 1
}
$ageVersion = & age --version 2>$null
Write-Host "[OK] age CLI available ($ageVersion)" -ForegroundColor Green

# Step 2: Generate key if needed
if (-not (Test-Path $AgeKey)) {
    Write-Host "[INFO] No age key found. Generating..." -ForegroundColor Cyan
    $keyDir = Split-Path $AgeKey -Parent
    if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force | Out-Null }
    & age-keygen -o $AgeKey 2>&1
    Write-Host "[OK] Key generated at $AgeKey" -ForegroundColor Green
    Write-Host ""
    Write-Host "[WARN] IMPORTANT: Back up this key! Without it, vault cannot be decrypted." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "[OK] Age key exists at $AgeKey" -ForegroundColor Green
}

# Step 3: Verify source .env
if (-not (Test-Path $SourceEnv)) {
    Write-Host "[ERROR] Source file not found: $SourceEnv" -ForegroundColor Red
    exit 1
}

$secretCount = (Get-Content $SourceEnv | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' }).Count
Write-Host "[OK] Source file: $SourceEnv ($secretCount entries)" -ForegroundColor Green

# Step 4: Encrypt
Write-Host "[INFO] Encrypting to vault..." -ForegroundColor Cyan

$publicKey = & age-keygen -y $AgeKey 2>$null
& age -e -r $publicKey -a -o $VaultFile $SourceEnv

Write-Host "[OK] Vault created: $VaultFile" -ForegroundColor Green

# Step 5: Verify round-trip
Write-Host "[INFO] Verifying round-trip integrity..." -ForegroundColor Cyan

$decrypted = & age --decrypt -i $AgeKey $VaultFile 2>$null
$original = Get-Content $SourceEnv -Raw

if ($decrypted -join "`n" -eq $original.TrimEnd()) {
    Write-Host "[OK] Round-trip verification PASSED" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Round-trip verification FAILED!" -ForegroundColor Red
    Write-Host "[WARN] Vault may be corrupted. Source .env NOT deleted." -ForegroundColor Yellow
    exit 1
}

# Step 6: Enable vault
Write-Host ""
if (Test-Path $SatelliteEnv) {
    $currentMode = Select-String -Path $SatelliteEnv -Pattern "^ADMIN_VAULT=(.+)$" | Select-Object -First 1
    if ($currentMode -and $currentMode.Matches.Groups[1].Value -eq "enabled") {
        Write-Host "[OK] ADMIN_VAULT=enabled already set" -ForegroundColor Green
    } else {
        $enable = Read-Host "Enable vault in satellite .env? (ADMIN_VAULT=enabled) [y/N]"
        if ($enable -eq "y") {
            $content = Get-Content $SatelliteEnv -Raw
            if ($content -match "ADMIN_VAULT=") {
                $content = $content -replace "ADMIN_VAULT=.*", "ADMIN_VAULT=enabled"
            } else {
                $content += "`nADMIN_VAULT=enabled"
            }
            Set-Content -Path $SatelliteEnv -Value $content.TrimEnd() -NoNewline
            Write-Host "[OK] ADMIN_VAULT=enabled set in $SatelliteEnv" -ForegroundColor Green
        } else {
            Write-Host "[INFO] Skipped. Enable later by adding ADMIN_VAULT=enabled to $SatelliteEnv" -ForegroundColor Cyan
        }
    }
}

# Step 7: Generate manifest .env (keys visible, secrets in vault)
Write-Host ""
Write-Host "[INFO] Generating manifest .env (keys visible, secrets in vault)..." -ForegroundColor Cyan

# Known non-secret keys that should keep their values
$NonSecretKeys = @(
    "ADMIN_ROOT", "ADMIN_DEVICE", "ADMIN_PLATFORM", "ADMIN_VAULT", "AGE_KEY_PATH",
    "ADMIN_SYNC_ENABLED", "ADMIN_SYNC_PATH", "ADMIN_LOG_PATH", "ADMIN_PROFILE_PATH",
    "ADMIN_USER", "DEVICE_NAME", "WIN_USER_HOME", "WIN_ADMIN_PATH",
    "WSL_ADMIN_PATH", "WSL_DISTRO", "SSH_KEY_PATH", "SSH_PUBLIC_KEY_PATH",
    "SSH_CONFIG_PATH", "OCI_CONFIG_PATH", "OCI_REGION", "HCLOUD_CONTEXT",
    "COOLIFY_DOMAIN", "COOLIFY_ADMIN_EMAIL", "COOLIFY_WILDCARD_DOMAIN",
    "KASM_DOMAIN", "SIMPLEMEM_URL", "CLOUDFLARE_TUNNEL_NAME"
)

$manifestLines = @(
    "# ======================================================================"
    "# Admin Profile Configuration"
    "# Secret values stored in vault.age"
    "# Non-secret values editable directly here"
    "# ======================================================================"
    ""
)

foreach ($line in $plaintext -split "`n") {
    $trimmed = $line.Trim()

    # Pass through comments and blank lines
    if ($trimmed -match '^\s*#' -or [string]::IsNullOrWhiteSpace($trimmed)) {
        $manifestLines += $trimmed
        continue
    }

    # Skip lines without =
    if ($trimmed -notmatch '=') { continue }

    $eqIdx = $trimmed.IndexOf('=')
    $key = $trimmed.Substring(0, $eqIdx)
    $value = $trimmed.Substring($eqIdx + 1)

    if ($NonSecretKeys -contains $key) {
        # Keep non-secret values populated
        $manifestLines += "${key}=${value}"
    } else {
        # Secret: show key, empty value, comment
        $manifestLines += "${key}=".PadRight(45) + "# in vault"
    }
}

$manifestLines | Set-Content -Path $SourceEnv -Encoding UTF8
Write-Host "[OK] Manifest .env written: $SourceEnv" -ForegroundColor Green
Write-Host "[INFO] All keys visible. Secret values stored only in vault.age" -ForegroundColor Cyan

# Done
Write-Host "`n=== Migration Complete ===" -ForegroundColor Green
Write-Host "Vault:     $VaultFile ($secretCount secrets)"
Write-Host "Manifest:  $SourceEnv (keys visible, secrets empty)"
Write-Host "Key:       $AgeKey"
Write-Host ""
Write-Host "Test with:"
Write-Host "  .\secrets.ps1 -Status            # Check everything"
Write-Host "  .\secrets.ps1 -List              # List all keys"
Write-Host "  .\secrets.ps1 HCLOUD_TOKEN       # Get single secret"
