#Requires -Version 5.1
<#
.SYNOPSIS
    Regenerates AGENTS.md from template
.DESCRIPTION
    Copies the AGENTS.md template to ADMIN_ROOT/AGENTS.md.
    Run this after updating the template or to refresh the file.
.EXAMPLE
    .\Update-AgentsMd.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir

# Import logging helper
. (Join-Path $ScriptDir "Log-AdminEvent.ps1")

function Write-OK { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

# Resolve ADMIN_ROOT
$AdminRoot = $env:ADMIN_ROOT
if (-not $AdminRoot) {
    $AdminRoot = Join-Path $HOME ".admin"
}

if (-not (Test-Path $AdminRoot)) {
    Write-Host "[ERROR] ADMIN_ROOT not found: $AdminRoot" -ForegroundColor Red
    Write-Host "Run Setup-Interview.ps1 first to create the admin structure." -ForegroundColor Yellow
    exit 1
}

# Copy template
$AgentsMdTemplate = Join-Path $SkillRoot "templates\AGENTS.md"
$AgentsMdPath = Join-Path $AdminRoot "AGENTS.md"

if (-not (Test-Path $AgentsMdTemplate)) {
    Write-Host "[ERROR] Template not found: $AgentsMdTemplate" -ForegroundColor Red
    exit 1
}

Copy-Item $AgentsMdTemplate $AgentsMdPath -Force
Write-OK "AGENTS.md updated: $AgentsMdPath"

Log-AdminEvent "AGENTS.md regenerated" -Level "INFO"
