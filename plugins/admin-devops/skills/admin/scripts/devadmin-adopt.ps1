<#
.SYNOPSIS
    Read-only shape detection for /admin-devops:adopt-devadmin (Windows-native seats).

.DESCRIPTION
    Detects the local (filesystem + profile + local-issue) half of a host's devadmin
    adoption state on a Windows-native seat (workspace D:\devadmin). The Linear half
    (project/label/seat/ledger) is checked by the command via MCP — this script never
    touches the network and never mutates. Emits a single JSON object matching the
    bash sibling (devadmin-adopt.sh) so the command consumes either identically.

.PARAMETER Pretty
    Emit indented JSON (default is already indented; kept for parity with the shell flag).

.EXAMPLE
    pwsh -NoProfile -File devadmin-adopt.ps1
#>
[CmdletBinding()]
param([switch]$Pretty)

$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot   = Split-Path -Parent $ScriptDir              # ...\skills\admin
$TemplateDir = Join-Path $SkillRoot 'assets\devadmin'
$Satellite   = Join-Path $env:USERPROFILE '.admin\.env'

function Read-EnvVar([string]$Name, [string]$File) {
    if (-not (Test-Path -LiteralPath $File)) { return '' }
    $line = Select-String -LiteralPath $File -Pattern "^$([regex]::Escape($Name))=" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $line) { return '' }
    return ($line.Line -replace "^$([regex]::Escape($Name))=", '')
}

function Get-HostSlug([string]$Device) {
    $d = $Device.ToLower()
    switch -Regex ($d) {
        '^wopr3'           { return 'wopr3' }
        '^(delta|deltabot)'{ return 'delta' }
        '^(casa|casaten)'  { return 'casa' }
        default            { return ($d -replace '[^a-z0-9]', '') }
    }
}

# --- resolve profile (read-only) -------------------------------------------
$AdminRoot = if ($env:ADMIN_ROOT)   { $env:ADMIN_ROOT }   else { Read-EnvVar 'ADMIN_ROOT'   $Satellite }
$Device    = if ($env:ADMIN_DEVICE) { $env:ADMIN_DEVICE } else { Read-EnvVar 'ADMIN_DEVICE' $Satellite }
$Platform  = if ($env:ADMIN_PLATFORM){ $env:ADMIN_PLATFORM } else { Read-EnvVar 'ADMIN_PLATFORM' $Satellite }
if (-not $AdminRoot) { $AdminRoot = Join-Path $env:USERPROFILE '.admin' }
if (-not $Device)    { $Device    = $env:COMPUTERNAME }
if (-not $Platform)  { $Platform  = 'windows' }

$ProfilePath   = Join-Path $AdminRoot ("profiles\{0}.json" -f $Device)
$ProfileExists = Test-Path -LiteralPath $ProfilePath
$Slug          = Get-HostSlug $Device
$HostLabel     = "host:$Slug"
$IssuesDir     = Join-Path $AdminRoot 'issues'

# Windows-native always uses the native template + D:\devadmin workspace.
$TemplateKind  = 'native'
$TemplateFile  = Join-Path $TemplateDir 'CLAUDE.md.native.template'
$Workspace     = 'D:\devadmin'
$SuggestedCode = "$Slug-claude-cli"

# --- workspace + CLAUDE.md shape -------------------------------------------
$WsExists       = Test-Path -LiteralPath $Workspace
$WsClaude       = Join-Path $Workspace 'CLAUDE.md'
$WsClaudeExists = Test-Path -LiteralPath $WsClaude

function Get-ShapeVersion([string]$File) {
    if (-not (Test-Path -LiteralPath $File)) { return '' }
    $m = Select-String -LiteralPath $File -Pattern 'Template shape version: (\d+)' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $m) { return '' }
    return $m.Matches[0].Groups[1].Value
}

$TemplateShape = Get-ShapeVersion $TemplateFile
if (-not $TemplateShape) { $TemplateShape = 'unknown' }
$WsShape = ''
$WsStale = 'unknown'
if ($WsClaudeExists) {
    $WsShape = Get-ShapeVersion $WsClaude
    if (-not $WsShape)                  { $WsStale = 'true' }   # no marker = pre-template shape
    elseif ($WsShape -eq $TemplateShape){ $WsStale = 'false' }
    else                                { $WsStale = 'true' }
}

# --- retired-path scan (read-only) -----------------------------------------
$RetiredCandidates = @(
    'D:\admin-native', 'D:\devops-native', 'D:\admin', 'D:\_admin', 'D:\admin-test',
    'D:\devadmin-old', 'C:\admin-native'
)
$RetiredFound = @()
foreach ($p in $RetiredCandidates) { if (Test-Path -LiteralPath $p) { $RetiredFound += $p } }
foreach ($g in (Get-ChildItem -Path 'D:\' -Filter 'admin-test*' -Directory -ErrorAction SilentlyContinue)) {
    if ($RetiredFound -notcontains $g.FullName) { $RetiredFound += $g.FullName }
}

# --- local issue census -----------------------------------------------------
$Total = 0; $Open = 0; $Resolved = 0
if (Test-Path -LiteralPath $IssuesDir) {
    $files = Get-ChildItem -LiteralPath $IssuesDir -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match '^(ISSUE-.*|issue_.*)\.md$' }
    foreach ($f in $files) {
        $Total++
        $statusLine = Select-String -LiteralPath $f.FullName -Pattern '^status:' -ErrorAction SilentlyContinue | Select-Object -First 1
        $st = ''
        if ($statusLine) { $st = ($statusLine.Line -replace '^status:\s*', '').Trim() }
        if ($st -match '^(resolved|closed|done)$') { $Resolved++ } else { $Open++ }
    }
}

# --- assemble JSON ----------------------------------------------------------
$result = [ordered]@{
    host               = $Device
    hostSlug           = $Slug
    hostLabel          = $HostLabel
    platform           = $Platform
    suggestedAgentCode = $SuggestedCode
    profile            = [ordered]@{ exists = [bool]$ProfileExists; path = $ProfilePath; adminRoot = $AdminRoot }
    workspace          = [ordered]@{
        path     = $Workspace
        exists   = [bool]$WsExists
        claudeMd = [ordered]@{ exists = [bool]$WsClaudeExists; shapeVersion = $WsShape; stale = $WsStale }
    }
    template           = [ordered]@{ kind = $TemplateKind; file = $TemplateFile; shapeVersion = $TemplateShape }
    retiredPaths       = @($RetiredFound)
    localIssues        = [ordered]@{ dir = $IssuesDir; total = $Total; open = $Open; resolved = $Resolved }
    placeholders       = [ordered]@{
        HOST             = $Device
        HOST_SLUG        = $Slug
        HOST_LABEL       = $HostLabel
        AGENT_CODE       = $SuggestedCode
        PLATFORM         = $Platform
        WORKSPACE_PATH   = $Workspace
        ADMIN_ROOT       = $AdminRoot
        LOCAL_ISSUES_DIR = $IssuesDir
        GENERATED        = (Get-Date -Format 'yyyy-MM-dd')
    }
}

$result | ConvertTo-Json -Depth 6
