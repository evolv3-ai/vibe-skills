# Verify-ShellEnvironment.ps1
# Tests Windows PowerShell environment configuration
# Usage: .\scripts\Verify-ShellEnvironment.ps1

param(
    [switch]$Quiet  # Only show failures
)

Write-Host "`n=== Windows Shell Environment Verification ===" -ForegroundColor Cyan
Write-Host "Device: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

$passed = 0
$failed = 0
$warnings = 0

function Test-Item {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [switch]$IsWarning
    )

    $result = & $Test
    if ($result) {
        $script:passed++
        if (-not $Quiet) {
            Write-Host "  [PASS] $Name" -ForegroundColor Green
            if ($SuccessMessage) { Write-Host "         $SuccessMessage" -ForegroundColor Gray }
        }
    } else {
        if ($IsWarning) {
            $script:warnings++
            Write-Host "  [WARN] $Name" -ForegroundColor Yellow
        } else {
            $script:failed++
            Write-Host "  [FAIL] $Name" -ForegroundColor Red
        }
        if ($FailureMessage) { Write-Host "         $FailureMessage" -ForegroundColor Gray }
    }
}

# =============================================================================
# 1. PowerShell Version
# =============================================================================
Write-Host "1. PowerShell Version" -ForegroundColor Yellow

Test-Item -Name "PowerShell 7.x installed" -Test {
    $PSVersionTable.PSVersion.Major -ge 7
} -SuccessMessage "Version: $($PSVersionTable.PSVersion)" `
  -FailureMessage "Found: $($PSVersionTable.PSVersion). Install with: winget install Microsoft.PowerShell"

# =============================================================================
# 2. Profile Configuration
# =============================================================================
Write-Host "`n2. Profile Configuration" -ForegroundColor Yellow

Test-Item -Name "Profile path valid" -Test {
    $PROFILE -and $PROFILE.Length -gt 0
} -SuccessMessage $PROFILE `
  -FailureMessage "Profile path is empty or null"

Test-Item -Name "Profile file exists" -Test {
    Test-Path $PROFILE
} -SuccessMessage "Profile exists at $PROFILE" `
  -FailureMessage "Create with: New-Item -ItemType File -Path `$PROFILE -Force" -IsWarning

# =============================================================================
# 3. PATH Configuration
# =============================================================================
Write-Host "`n3. PATH Configuration" -ForegroundColor Yellow

$npmPath = "$env:APPDATA\npm"
Test-Item -Name "npm in User PATH (registry)" -Test {
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $userPath -like "*$npmPath*"
} -SuccessMessage "Found: $npmPath" `
  -FailureMessage "Add npm to User PATH via Environment Variables"

Test-Item -Name "npm in current session PATH" -Test {
    $env:PATH -like "*$npmPath*"
} -SuccessMessage "npm path accessible in current session" `
  -FailureMessage "Restart PowerShell after adding to PATH" -IsWarning

$scoopPath = "$env:USERPROFILE\scoop\shims"
Test-Item -Name "Scoop in PATH" -Test {
    $env:PATH -like "*scoop*"
} -SuccessMessage "Found scoop shims" `
  -FailureMessage "Scoop not installed or not in PATH" -IsWarning

# =============================================================================
# 4. Execution Policy
# =============================================================================
Write-Host "`n4. Execution Policy" -ForegroundColor Yellow

Test-Item -Name "Execution policy allows scripts" -Test {
    $policy = Get-ExecutionPolicy
    $policy -in @('RemoteSigned', 'Unrestricted', 'Bypass')
} -SuccessMessage "Policy: $(Get-ExecutionPolicy)" `
  -FailureMessage "Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"

# =============================================================================
# 5. Essential Tools
# =============================================================================
Write-Host "`n5. Essential Tools" -ForegroundColor Yellow

$tools = @(
    @{ Name = "winget"; Command = "winget"; VersionArg = "--version" }
    @{ Name = "node"; Command = "node"; VersionArg = "--version" }
    @{ Name = "npm"; Command = "npm"; VersionArg = "--version" }
    @{ Name = "git"; Command = "git"; VersionArg = "--version" }
)

foreach ($tool in $tools) {
    $cmd = Get-Command $tool.Command -ErrorAction SilentlyContinue
    Test-Item -Name "$($tool.Name) available" -Test {
        $null -ne $cmd
    } -SuccessMessage "Found: $($cmd.Source)" `
      -FailureMessage "$($tool.Name) not found in PATH"

    if ($cmd) {
        try {
            $version = & $tool.Command $tool.VersionArg 2>&1 | Select-Object -First 1
            if (-not $Quiet) {
                Write-Host "         Version: $version" -ForegroundColor Gray
            }
        } catch {}
    }
}

# Optional tools
$optionalTools = @(
    @{ Name = "claude"; Command = "claude"; VersionArg = "--version" }
    @{ Name = "code"; Command = "code"; VersionArg = "--version" }
    @{ Name = "scoop"; Command = "scoop"; VersionArg = "--version" }
)

Write-Host "`n6. Optional Tools" -ForegroundColor Yellow

foreach ($tool in $optionalTools) {
    $cmd = Get-Command $tool.Command -ErrorAction SilentlyContinue
    Test-Item -Name "$($tool.Name) available" -Test {
        $null -ne $cmd
    } -SuccessMessage "Found: $($cmd.Source)" `
      -FailureMessage "$($tool.Name) not installed" -IsWarning

    if ($cmd) {
        try {
            $version = & $tool.Command $tool.VersionArg 2>&1 | Select-Object -First 1
            if (-not $Quiet) {
                Write-Host "         Version: $version" -ForegroundColor Gray
            }
        } catch {}
    }
}

# =============================================================================
# 7. Environment File
# =============================================================================
Write-Host "`n7. Environment Configuration" -ForegroundColor Yellow

$adminRoot = if ($env:ADMIN_ROOT) { $env:ADMIN_ROOT } else { Join-Path $HOME ".admin" }
$envPath = Join-Path $adminRoot ".env"

Test-Item -Name ".env file exists (outside skill folder)" -Test {
    Test-Path $envPath
} -SuccessMessage "Found .env at $envPath" `
  -FailureMessage "Create .env from templates/.env.template in $adminRoot" -IsWarning

if (Test-Path $envPath) {
    Test-Item -Name "ADMIN_ROOT configured" -Test {
        $content = Get-Content $envPath -Raw
        $content -match "ADMIN_ROOT=.+"
    } -SuccessMessage "ADMIN_ROOT is set" `
      -FailureMessage "ADMIN_ROOT not configured in .env" -IsWarning
}

# =============================================================================
# Summary
# =============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Passed:   $passed" -ForegroundColor Green
Write-Host "Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
Write-Host "Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { "Yellow" } else { "Gray" })

if ($failed -eq 0) {
    Write-Host "`nEnvironment is properly configured!" -ForegroundColor Green
} else {
    Write-Host "`nFix the failures above before proceeding." -ForegroundColor Red
}

Write-Host ""
