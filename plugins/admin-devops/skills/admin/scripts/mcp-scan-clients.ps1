#Requires -Version 5.1
<#
.SYNOPSIS
    Scan for MCP client configs and update the registry.
.DESCRIPTION
    Detects known MCP clients, parses configs (when possible), and normalizes
    server entries into the central registry at $ADMIN_ROOT\registries\mcp-registry.json.
#>

[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Write-Info { param([string]$Msg) if (-not $Quiet) { Write-Host "[INFO] $Msg" -ForegroundColor Cyan } }
function Write-Warn { param([string]$Msg) if (-not $Quiet) { Write-Host "[WARN] $Msg" -ForegroundColor Yellow } }
function Write-Err  { param([string]$Msg) if (-not $Quiet) { Write-Host "[ERR]  $Msg" -ForegroundColor Red } }

$adminRoot = if ($env:ADMIN_ROOT) { $env:ADMIN_ROOT } else { Join-Path $HOME ".admin" }
$registryDir = Join-Path $adminRoot "registries"
$registryPath = Join-Path $registryDir "mcp-registry.json"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path (Split-Path -Parent $scriptDir) "templates\mcp-registry.json"

if (-not (Test-Path $registryDir)) { New-Item -ItemType Directory -Path $registryDir -Force | Out-Null }

if (-not (Test-Path $registryPath)) {
    if (Test-Path $templatePath) {
        Copy-Item $templatePath $registryPath
    } else {
        Write-Err "Registry template not found: $templatePath"
        return
    }
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

# Known clients
$clients = @{
    "claude-desktop" = @{ name = "Claude Desktop"; configPath = "$env:APPDATA\Claude\claude_desktop_config.json"; format = "claude-desktop-v1" }
    "cursor" = @{ name = "Cursor"; configPath = "$HOME\.cursor\mcp.json"; format = "cursor-mcp-v1" }
    "claude-code" = @{ name = "Claude Code CLI"; configPath = "$HOME\.claude\settings.json"; format = "claude-code-v1" }
}

$now = (Get-Date).ToString("o")

foreach ($key in $clients.Keys) {
    if (-not $registry.clients.$key) {
        $registry.clients | Add-Member -NotePropertyName $key -NotePropertyValue (@{})
    }

    $cfg = $clients[$key]
    $detected = Test-Path $cfg.configPath

    $registry.clients.$key.name = $cfg.name
    $registry.clients.$key.detected = $detected
    $registry.clients.$key.configPath = if ($detected) { $cfg.configPath } else { "" }
    $registry.clients.$key.configFormat = $cfg.format
    $registry.clients.$key.lastScanned = $now
}

# Parse Claude Desktop config if present
if ($registry.clients.'claude-desktop'.detected -and (Test-Path $registry.clients.'claude-desktop'.configPath)) {
    try {
        $cfg = Get-Content $registry.clients.'claude-desktop'.configPath -Raw | ConvertFrom-Json
        if ($cfg.mcpServers) {
            foreach ($prop in $cfg.mcpServers.PSObject.Properties) {
                $serverId = $prop.Name
                $server = $prop.Value

                if (-not $registry.servers.$serverId) {
                    $registry.servers | Add-Member -NotePropertyName $serverId -NotePropertyValue (@{})
                }

                $registry.servers.$serverId.serverId = $serverId
                $registry.servers.$serverId.command = $server.command
                $registry.servers.$serverId.args = $server.args
                $registry.servers.$serverId.env = $server.env

                if (-not $registry.servers.$serverId.clients) {
                    $registry.servers.$serverId.clients = @{}
                }
                $registry.servers.$serverId.clients.'claude-desktop' = @{
                    installed = $true
                    status = "unknown"
                    toolCount = 0
                }
                $registry.servers.$serverId.lastVerified = $now
            }
        }
    } catch {
        Write-Warn "Failed to parse Claude Desktop config: $($_.Exception.Message)"
    }
}

$registry.lastUpdated = $now

$registry | ConvertTo-Json -Depth 20 | Set-Content $registryPath

$detectedCount = ($registry.clients.PSObject.Properties | Where-Object { $_.Value.detected }).Count
if ($detectedCount -eq 0) {
    Write-Warn "No MCP clients detected. Registry initialized at $registryPath"
} else {
    Write-Info "Detected $detectedCount MCP client(s). Registry updated at $registryPath"
}
