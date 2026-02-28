#Requires -Version 5.1
<#
.SYNOPSIS
    Install an MCP server for a specific client and update the registry.
.DESCRIPTION
    Updates the client config (Claude Desktop supported) and maintains
    the central MCP registry under $ADMIN_ROOT\registries\mcp-registry.json.
    Logs all operations and creates issues on failures.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [string[]]$Args,

    [hashtable]$Env = @{},

    [string]$Client = "claude-desktop",

    [switch]$NoBackup,

    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

# Import shared helpers from admin skill
$adminScriptsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "admin\scripts"
. (Join-Path $adminScriptsDir "Log-AdminEvent.ps1")
. (Join-Path $adminScriptsDir "New-AdminIssue.ps1")

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "[ERR]  $Msg" -ForegroundColor Red }

$adminRoot = if ($env:ADMIN_ROOT) { $env:ADMIN_ROOT } else { Join-Path $HOME ".admin" }
$registryDir = Join-Path $adminRoot "registries"
$registryPath = Join-Path $registryDir "mcp-registry.json"
$templatePath = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\mcp-registry.json"

# Ensure registry directory exists
if (-not (Test-Path $registryDir)) { New-Item -ItemType Directory -Path $registryDir -Force | Out-Null }
if (-not (Test-Path $registryPath)) {
    if (-not (Test-Path $templatePath)) {
        Write-Err "Registry template missing: $templatePath"
        Log-AdminEvent "MCP install failed: registry template missing" -Level "ERROR"
        New-AdminIssue -Title "MCP registry template missing" -Category "mcp" -Tags @("mcp","registry","install")
        exit 1
    }
    Copy-Item $templatePath $registryPath
    Log-AdminEvent "MCP registry initialized from template" -Level "INFO"
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

if (-not $registry.clients.$Client) {
    Write-Err "Unknown client: $Client"
    Log-AdminEvent "MCP install failed: unknown client '$Client'" -Level "ERROR"
    New-AdminIssue -Title "Unknown MCP client: $Client" -Category "mcp" -Tags @("mcp","client","install")
    exit 1
}

# Determine config path for supported clients
$configPath = $registry.clients.$Client.configPath
if (-not $configPath -or $configPath -eq "") {
    switch ($Client) {
        "claude-desktop" { $configPath = "$env:APPDATA\Claude\claude_desktop_config.json" }
        default { $configPath = $null }
    }
}

if (-not $configPath) {
    Write-Err "No config path for client: $Client"
    Log-AdminEvent "MCP install failed: no config path for client '$Client'" -Level "ERROR"
    New-AdminIssue -Title "No MCP config path for client: $Client" -Category "mcp" -Tags @("mcp","config","install")
    exit 1
}

if (-not (Test-Path $configPath)) {
    Write-Err "Client config not found: $configPath"
    Log-AdminEvent "MCP install failed: config not found at $configPath" -Level "ERROR"
    New-AdminIssue -Title "MCP client config not found" -Category "mcp" -Tags @("mcp","config","install")
    exit 1
}

# Backup config
if (-not $NoBackup) {
    $backupDir = Join-Path (Split-Path $configPath -Parent) "backups"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $backupPath = Join-Path $backupDir ("claude_desktop_config.{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $configPath $backupPath
    Write-Info "Backup created: $backupPath"
    Log-AdminEvent "MCP config backed up to $backupPath" -Level "INFO"
}

# Load config
try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $config.mcpServers) {
        $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{}
    }
}
catch {
    Write-Err "Failed to parse client config: $_"
    Log-AdminEvent "MCP install failed: invalid config JSON - $_" -Level "ERROR"
    New-AdminIssue -Title "Invalid MCP client config JSON" -Category "mcp" -Tags @("mcp","config","json")
    exit 1
}

# Build server entry
$serverEntry = @{ command = $Command; args = $Args }
if ($Env.Keys.Count -gt 0) { $serverEntry.env = $Env }

# Add/update server
if ($config.mcpServers.PSObject.Properties.Name -contains $Name) {
    Write-Warn "Server '$Name' already exists. Overwriting."
    $config.mcpServers.$Name = $serverEntry
    Log-AdminEvent "MCP server '$Name' updated (overwritten)" -Level "WARN"
} else {
    $config.mcpServers | Add-Member -NotePropertyName $Name -NotePropertyValue $serverEntry
    Log-AdminEvent "MCP server '$Name' added to $Client" -Level "INFO"
}

# Save config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
Write-Info "Client config updated: $configPath"

# Determine install method and package
$installMethod = "custom"
$package = $null
if ($Command -eq "npx") {
    $installMethod = "npx"
    if ($Args -contains "-y") {
        $idx = [Array]::IndexOf($Args, "-y")
        if ($idx -ge 0 -and $idx + 1 -lt $Args.Length) { $package = $Args[$idx + 1] }
    } elseif ($Args.Length -gt 0) {
        $package = $Args[0]
    }
} elseif ($Command -eq "node") {
    $installMethod = "local-clone"
}

# Update registry
if (-not $registry.servers.$Name) {
    $registry.servers | Add-Member -NotePropertyName $Name -NotePropertyValue (@{})
}

$registry.servers.$Name.serverId = $Name
$registry.servers.$Name.name = $Name
$registry.servers.$Name.package = $package
$registry.servers.$Name.installMethod = $installMethod
$registry.servers.$Name.command = $Command
$registry.servers.$Name.args = $Args
$registry.servers.$Name.env = $Env
if (-not $registry.servers.$Name.clients) { $registry.servers.$Name.clients = @{} }
$registry.servers.$Name.clients.$Client = @{ installed = $true; status = "pending"; toolCount = 0 }
$registry.servers.$Name.lastVerified = (Get-Date).ToString("o")

if (-not ($registry.PSObject.Properties.Name -contains "syncHistory")) {
    $registry | Add-Member -NotePropertyName "syncHistory" -NotePropertyValue @()
}
$registry.syncHistory += @{ date = (Get-Date).ToString("o"); action = "install"; server = $Name; client = $Client; details = "Installed via $installMethod" }
$registry.lastUpdated = (Get-Date).ToString("o")

$registry | ConvertTo-Json -Depth 20 | Set-Content $registryPath
Write-Info "Registry updated: $registryPath"

# Log successful install
Log-AdminEvent "MCP server '$Name' installed for $Client via $installMethod" -Level "OK"

# Restart client if requested
if (-not $NoRestart -and $Client -eq "claude-desktop") {
    Write-Info "Restarting Claude Desktop..."
    $claudeProcess = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
    if ($claudeProcess) { Stop-Process -Name "Claude" -Force; Start-Sleep 2 }
    $claudeExe = "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
    if (Test-Path $claudeExe) {
        Start-Process $claudeExe
        Write-Info "Claude Desktop restarted"
        Log-AdminEvent "Claude Desktop restarted after MCP install" -Level "INFO"
    } else {
        Write-Warn "Claude Desktop executable not found. Restart manually."
        Log-AdminEvent "Claude Desktop not found for restart" -Level "WARN"
    }
}

Write-Host "Done." -ForegroundColor Green
