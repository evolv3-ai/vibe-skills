#Requires -Version 5.1
<#
.SYNOPSIS
    Remove an MCP server for a specific client and update the registry.
.DESCRIPTION
    Removes server from client config and updates the central MCP registry.
    Logs all operations and creates issues on failures.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

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

if (-not (Test-Path $registryPath)) {
    Write-Err "Registry not found: $registryPath"
    Log-AdminEvent "MCP remove failed: registry not found" -Level "ERROR"
    New-AdminIssue -Title "MCP registry not found for remove" -Category "mcp" -Tags @("mcp","registry","remove")
    exit 1
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

if (-not $registry.clients.$Client) {
    Write-Err "Unknown client: $Client"
    Log-AdminEvent "MCP remove failed: unknown client '$Client'" -Level "ERROR"
    exit 1
}

$configPath = $registry.clients.$Client.configPath
if (-not $configPath -or $configPath -eq "") {
    switch ($Client) {
        "claude-desktop" { $configPath = "$env:APPDATA\Claude\claude_desktop_config.json" }
        default { $configPath = $null }
    }
}

if (-not $configPath) {
    Write-Err "No config path for client: $Client"
    Log-AdminEvent "MCP remove failed: no config path for '$Client'" -Level "ERROR"
    exit 1
}

if (-not (Test-Path $configPath)) {
    Write-Err "Client config not found: $configPath"
    Log-AdminEvent "MCP remove failed: config not found at $configPath" -Level "ERROR"
    exit 1
}

# Backup config
if (-not $NoBackup) {
    $backupDir = Join-Path (Split-Path $configPath -Parent) "backups"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $backupPath = Join-Path $backupDir ("claude_desktop_config.{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $configPath $backupPath
    Write-Info "Backup created: $backupPath"
    Log-AdminEvent "MCP config backed up before remove" -Level "INFO"
}

# Load config
$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $config.mcpServers) { Write-Warn "No mcpServers in config." }

if ($config.mcpServers -and $config.mcpServers.PSObject.Properties.Name -contains $Name) {
    $config.mcpServers.PSObject.Properties.Remove($Name)
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    Write-Info "Removed '$Name' from client config"
    Log-AdminEvent "MCP server '$Name' removed from $Client config" -Level "INFO"
} else {
    Write-Warn "Server '$Name' not found in client config"
    Log-AdminEvent "MCP server '$Name' not found in $Client config" -Level "WARN"
}

# Update registry
if ($registry.servers.$Name) {
    if ($registry.servers.$Name.clients -and $registry.servers.$Name.clients.$Client) {
        $registry.servers.$Name.clients.$Client.installed = $false
        $registry.servers.$Name.clients.$Client.status = "removed"
    }

    # If no clients remain installed, remove server entry
    $anyInstalled = $false
    if ($registry.servers.$Name.clients) {
        foreach ($c in $registry.servers.$Name.clients.PSObject.Properties) {
            if ($c.Value.installed) { $anyInstalled = $true }
        }
    }
    if (-not $anyInstalled) {
        $registry.servers.PSObject.Properties.Remove($Name)
        Log-AdminEvent "MCP server '$Name' removed from registry (no clients)" -Level "INFO"
    }
}

if (-not ($registry.PSObject.Properties.Name -contains "syncHistory")) {
    $registry | Add-Member -NotePropertyName "syncHistory" -NotePropertyValue @()
}
$registry.syncHistory += @{ date = (Get-Date).ToString("o"); action = "remove"; server = $Name; client = $Client; details = "Removed from $Client" }
$registry.lastUpdated = (Get-Date).ToString("o")

$registry | ConvertTo-Json -Depth 20 | Set-Content $registryPath
Write-Info "Registry updated: $registryPath"

# Log successful removal
Log-AdminEvent "MCP server '$Name' removed from $Client" -Level "OK"

if (-not $NoRestart -and $Client -eq "claude-desktop") {
    Write-Info "Restarting Claude Desktop..."
    $claudeProcess = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
    if ($claudeProcess) { Stop-Process -Name "Claude" -Force; Start-Sleep 2 }
    $claudeExe = "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
    if (Test-Path $claudeExe) {
        Start-Process $claudeExe
        Write-Info "Claude Desktop restarted"
        Log-AdminEvent "Claude Desktop restarted after MCP remove" -Level "INFO"
    } else {
        Write-Warn "Claude Desktop executable not found. Restart manually."
        Log-AdminEvent "Claude Desktop not found for restart" -Level "WARN"
    }
}

Write-Host "Done." -ForegroundColor Green
