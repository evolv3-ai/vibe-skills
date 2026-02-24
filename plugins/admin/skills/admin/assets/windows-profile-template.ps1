# PowerShell Profile Template
# Location: Copy to $PROFILE (typically ~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1)
# Usage: Copy-Item profile-template.ps1 $PROFILE

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

# Terminal colors
$env:COLORTERM = "truecolor"

# =============================================================================
# PATH VERIFICATION
# =============================================================================

# Verify npm is in PATH (warning only, don't modify - should be in registry)
$npmPath = "$env:APPDATA\npm"
if ($env:PATH -notlike "*$npmPath*") {
    Write-Warning "npm not in PATH. Add to User PATH via Environment Variables."
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Load environment variables from .env file
function Load-EnvFile {
    param(
        [string]$Path = ".env"
    )

    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match '^([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Expand variables like ${ADMIN_ROOT}
                $value = [Environment]::ExpandEnvironmentVariables($value)
                Set-Item -Path "Env:\$name" -Value $value
            }
        }
        Write-Host "Loaded environment from $Path" -ForegroundColor Green
    } else {
        Write-Warning "Environment file not found: $Path"
    }
}

# Log operation to device log and central log
function Log-Operation {
    param(
        [ValidateSet("SUCCESS", "ERROR", "INFO", "PENDING", "WARNING")]
        [string]$Status,
        [string]$Operation,
        [string]$Details,
        [ValidateSet("operation", "installation", "system-change")]
        [string]$LogType = "operation"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $deviceName = $env:COMPUTERNAME
    $logEntry = "$timestamp - [$deviceName] $Status: $Operation - $Details"

    # Write to device log if path is set
    if ($env:DEVICE_LOGS -and (Test-Path (Split-Path $env:DEVICE_LOGS))) {
        Add-Content $env:DEVICE_LOGS -Value $logEntry
    }

    # Write to appropriate central log
    if ($env:CENTRAL_LOGS -and (Test-Path $env:CENTRAL_LOGS)) {
        $centralLog = switch ($LogType) {
            "installation" { "$env:CENTRAL_LOGS/installations.log" }
            "system-change" { "$env:CENTRAL_LOGS/system-changes.log" }
            default { "$env:CENTRAL_LOGS/operations.log" }
        }
        Add-Content $centralLog -Value $logEntry
    }

    # Console output with color
    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "PENDING" { "Cyan" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

# Quick JSON read helper
function Read-Json {
    param([string]$Path)
    if (Test-Path $Path) {
        Get-Content $Path -Raw | ConvertFrom-Json
    } else {
        Write-Warning "File not found: $Path"
        $null
    }
}

# Quick JSON write helper
function Write-Json {
    param(
        [Parameter(ValueFromPipeline)]$Object,
        [string]$Path,
        [int]$Depth = 10
    )
    $Object | ConvertTo-Json -Depth $Depth | Set-Content $Path
    Write-Host "Saved: $Path" -ForegroundColor Green
}

# Add to PATH (User scope, permanent)
function Add-ToPath {
    param([string]$NewPath)

    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($currentPath -notlike "*$NewPath*") {
        [Environment]::SetEnvironmentVariable('PATH', "$NewPath;$currentPath", 'User')
        $env:PATH = "$NewPath;$env:PATH"
        Write-Host "Added to PATH: $NewPath" -ForegroundColor Green
        Write-Host "Restart terminal for full effect." -ForegroundColor Yellow
    } else {
        Write-Host "Already in PATH: $NewPath" -ForegroundColor Gray
    }
}

# =============================================================================
# NAVIGATION SHORTCUTS
# =============================================================================

# Quick admin directory navigation (customize these)
function admin {
    if ($env:ADMIN_ROOT) {
        Set-Location $env:ADMIN_ROOT
    } else {
        Write-Warning "ADMIN_ROOT not set. Run Load-EnvFile first."
    }
}

function mcp {
    if ($env:MCP_ROOT) {
        Set-Location $env:MCP_ROOT
    } elseif (Test-Path "D:/mcp") {
        Set-Location "D:/mcp"
    } else {
        Write-Warning "MCP_ROOT not set and D:/mcp not found."
    }
}

# =============================================================================
# ALIASES
# =============================================================================

# Bash-like aliases for transition comfort
Set-Alias -Name which -Value Get-Command
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name touch -Value New-Item

# Shorthand for common operations
Set-Alias -Name env -Value Get-ChildItem -Description "List environment variables"
# Usage: env Env:

# =============================================================================
# PROMPT CUSTOMIZATION (Optional)
# =============================================================================

# Uncomment to customize prompt
# function prompt {
#     $location = (Get-Location).Path
#     $shortPath = $location -replace [regex]::Escape($HOME), '~'
#     Write-Host "[$env:COMPUTERNAME] " -NoNewline -ForegroundColor Cyan
#     Write-Host "$shortPath" -NoNewline -ForegroundColor Yellow
#     Write-Host " >" -NoNewline -ForegroundColor White
#     return " "
# }

# =============================================================================
# AUTO-LOAD (Optional)
# =============================================================================

# Uncomment to auto-load .env from specific directory
# if (Test-Path "D:\_admin\.env") {
#     Push-Location "D:\_admin"
#     Load-EnvFile
#     Pop-Location
# }

# =============================================================================
# STARTUP MESSAGE
# =============================================================================

# Uncomment for startup confirmation
# Write-Host "PowerShell profile loaded for $env:COMPUTERNAME" -ForegroundColor Green
