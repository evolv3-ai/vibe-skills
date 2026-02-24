# add-mcp-server.ps1
# Add an MCP server to Claude Desktop configuration
# Usage: .\scripts\add-mcp-server.ps1 -Name "server-name" -Command "node" -Args @("path/to/server.js")

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [string]$Command,

    [Parameter(Mandatory=$true)]
    [string[]]$Args,

    [hashtable]$Env,

    [switch]$Disabled,

    [switch]$NoBackup,

    [switch]$NoRestart
)

# Configuration
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$backupDir = "$env:APPDATA\Claude\backups"

Write-Host "`n=== Add MCP Server ===" -ForegroundColor Cyan
Write-Host "Server: $Name" -ForegroundColor Gray

# Verify config exists
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Claude Desktop config not found at $configPath" -ForegroundColor Red
    Write-Host "Is Claude Desktop installed?" -ForegroundColor Yellow
    exit 1
}

# Create backup
if (-not $NoBackup) {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $backupPath = "$backupDir\claude_desktop_config.$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item $configPath $backupPath
    Write-Host "Backup created: $backupPath" -ForegroundColor Green
}

# Read current config
try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Failed to parse config file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

# Ensure mcpServers object exists
if (-not $config.mcpServers) {
    $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{}
}

# Check if server already exists
if ($config.mcpServers.PSObject.Properties.Name -contains $Name) {
    Write-Host "WARNING: Server '$Name' already exists. Overwriting." -ForegroundColor Yellow
}

# Build server entry
$serverEntry = @{
    command = $Command
    args = $Args
}

if ($Env) {
    $serverEntry.env = $Env
}

if ($Disabled) {
    $serverEntry.disabled = $true
}

# Add or update server
if ($config.mcpServers.PSObject.Properties.Name -contains $Name) {
    $config.mcpServers.$Name = $serverEntry
} else {
    $config.mcpServers | Add-Member -NotePropertyName $Name -NotePropertyValue $serverEntry
}

# Save config
try {
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    Write-Host "Config updated successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to save config" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

# Display result
Write-Host "`nServer configuration:" -ForegroundColor Cyan
$config.mcpServers.$Name | ConvertTo-Json -Depth 5

# Restart Claude Desktop
if (-not $NoRestart) {
    Write-Host "`nRestarting Claude Desktop..." -ForegroundColor Yellow

    $claudeProcess = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
    if ($claudeProcess) {
        Stop-Process -Name "Claude" -Force
        Start-Sleep 2
    }

    $claudeExe = "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
    if (Test-Path $claudeExe) {
        Start-Process $claudeExe
        Write-Host "Claude Desktop restarted" -ForegroundColor Green
    } else {
        Write-Host "Claude Desktop executable not found. Please restart manually." -ForegroundColor Yellow
    }
}

Write-Host "`nDone!" -ForegroundColor Green
Write-Host "Verify server is available in Claude Desktop tools." -ForegroundColor Gray
