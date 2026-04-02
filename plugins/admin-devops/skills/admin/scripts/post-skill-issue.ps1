#Requires -Version 5.1
<#
.SYNOPSIS
    Escalates a local admin issue file to a GitHub Issue on evolv3-ai/vibe-skills.
.DESCRIPTION
    Only for skill-level bugs requiring code changes to the plugin itself.
    Parses the local issue file, builds a compact GitHub Issue body (Context +
    Symptoms only), checks for duplicates, requires operator confirmation, then
    posts via `gh issue create`. Updates the local file with the GitHub URL.
    Falls back gracefully if gh is unavailable.
.PARAMETER IssuePath
    Path to the local issue markdown file (e.g. C:\Users\Owner\.admin\issues\issue_20260401_bad_flag.md)
.EXAMPLE
    .\post-skill-issue.ps1 -IssuePath "$env:USERPROFILE\.admin\issues\issue_20260401_bad_flag.md"
.EXAMPLE
    .\post-skill-issue.ps1 (Get-ChildItem "$env:USERPROFILE\.admin\issues\*.md" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$IssuePath
)

$GithubRepo = "evolv3-ai/vibe-skills"

# ---------------------------------------------------------------------------
# Import logging
# ---------------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogScript = Join-Path $ScriptDir "Log-AdminEvent.ps1"
if (Test-Path $LogScript) {
    . $LogScript
} else {
    # Stub if Log-AdminEvent.ps1 not in same dir
    function Log-AdminEvent {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Resolve-AdminRoot {
    if ($env:ADMIN_ROOT) { return $env:ADMIN_ROOT }
    $Satellite = Join-Path $HOME ".admin\.env"
    if (Test-Path $Satellite) {
        $Line = Get-Content $Satellite | Where-Object { $_ -match "^ADMIN_ROOT=" } | Select-Object -First 1
        if ($Line) { return ($Line -replace "^ADMIN_ROOT=", "").Trim() }
    }
    return Join-Path $HOME ".admin"
}

# Extract a YAML frontmatter field value
function Get-FrontmatterField {
    param([string]$Field, [string]$Content)
    $FmBlock = [regex]::Match($Content, "(?s)^---\n(.+?)\n---")
    if (-not $FmBlock.Success) { return "" }
    $FM = $FmBlock.Groups[1].Value
    $Match = [regex]::Match($FM, "(?m)^${Field}:\s*(.+)$")
    if ($Match.Success) {
        return $Match.Groups[1].Value.Trim().Trim('"').Trim("'")
    }
    return ""
}

# Extract a markdown section body (## Header … next ## Header)
function Get-SectionBody {
    param([string]$SectionName, [string]$Content)
    $Pattern = "(?s)##\s+${SectionName}\s*\n(.*?)(?=\n##\s|\z)"
    $Match = [regex]::Match($Content, $Pattern)
    if ($Match.Success) {
        return $Match.Groups[1].Value.Trim()
    }
    return ""
}

# Determine component type from file text
function Get-ComponentType {
    param([string]$Text)
    if ($Text -match "agents/") { return "agent" }
    if ($Text -match "commands/") { return "command" }
    return "skill"
}

# Extract the most likely affected file path
function Get-AffectedFile {
    param([string]$Text)
    $Match = [regex]::Match($Text, "plugins/admin-devops/[^\s`""'`)]+")
    if ($Match.Success) { return $Match.Value }
    $Match = [regex]::Match($Text, "(skills|agents|commands)/[^\s`""'`)\n]+(\.md|\.sh|\.ps1|\.ts|\.py)")
    if ($Match.Success) { return $Match.Value }
    return "(see issue body)"
}

# Map platform field to GitHub label
function Get-PlatformLabel {
    param([string]$Platform, [string]$FullText)
    $HasSh  = $FullText -match '\.sh'
    $HasPs1 = $FullText -match '\.ps1'
    if ($HasSh -and $HasPs1) { return "cross-platform" }
    switch -Wildcard ($Platform) {
        "windows" { return "windows" }
        "wsl"     { return "linux"   }
        "linux"   { return "linux"   }
        "macos"   { return "linux"   }
        default   { return "linux"   }
    }
}

# Update or insert a YAML frontmatter field in an issue file
function Set-FrontmatterField {
    param([string]$Field, [string]$Value, [string]$FilePath)
    $Content = Get-Content -Path $FilePath -Raw
    if ($Content -match "(?m)^${Field}:") {
        $Content = $Content -replace "(?m)^${Field}:.*", "${Field}: ${Value}"
    } else {
        # Insert before the closing --- of frontmatter (index-based to target the second ---)
        $Lines = $Content -split "`n"
        $CloseIdx = -1
        $Seen = 0
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i].Trim() -eq "---") {
                $Seen++
                if ($Seen -eq 2) { $CloseIdx = $i; break }
            }
        }
        if ($CloseIdx -ge 0) {
            $NewLines = $Lines[0..($CloseIdx-1)] + "${Field}: ${Value}" + $Lines[$CloseIdx..($Lines.Count-1)]
            $Content = $NewLines -join "`n"
        } else {
            $Content += "`n${Field}: ${Value}"
        }
    }
    Set-Content -Path $FilePath -Value $Content -Encoding UTF8 -NoNewline
}

# Add a tag to the tags array in frontmatter
function Add-IssueTag {
    param([string]$Tag, [string]$FilePath)
    $Content = Get-Content -Path $FilePath -Raw
    if ($Content -match [regex]::Escape($Tag)) { return }  # already present
    if ($Content -match "(?m)^tags:\s*\[\]") {
        $Content = $Content -replace "(?m)^tags:\s*\[\]", "tags: [`"$Tag`"]"
    } elseif ($Content -match "(?m)^tags:\s*\[") {
        $Content = $Content -replace "(?m)^tags:\s*\[", "tags: [`"$Tag`", "
    }
    Set-Content -Path $FilePath -Value $Content -Encoding UTF8 -NoNewline
}

# Graceful fallback when gh unavailable
function Invoke-GhFallback {
    param([string]$FilePath, [string]$Reason)
    $Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    Write-Host "[WARN] gh CLI unavailable ($Reason). Marking issue for later escalation." -ForegroundColor Yellow

    $Content = Get-Content -Path $FilePath -Raw
    $Content = $Content -replace "(?m)^status:.*", "status: needs-escalation"
    Set-Content -Path $FilePath -Value $Content -Encoding UTF8 -NoNewline

    Add-IssueTag -Tag "pending-github" -FilePath $FilePath

    if (-not (Get-Content $FilePath -Raw).Contains("## Escalation Status")) {
        $Note = @"

## Escalation Status

GitHub escalation pending — gh CLI unavailable or unauthenticated at $Timestamp.
Reason: $Reason

To escalate manually when gh is available:
  post-skill-issue.ps1 -IssuePath "$FilePath"
"@
        Add-Content -Path $FilePath -Value $Note -Encoding UTF8
    }

    Log-AdminEvent -Message "Skill issue marked needs-escalation (gh unavailable): $(Split-Path -Leaf $FilePath)" -Level "WARN"
    Write-Host "[WARN] Issue updated with needs-escalation status." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Validate input
if (-not (Test-Path $IssuePath)) {
    Write-Host "[ERROR] Issue file not found: $IssuePath" -ForegroundColor Red
    exit 2
}

$FileContent = Get-Content -Path $IssuePath -Raw

# Parse frontmatter
$IssueId  = Get-FrontmatterField -Field "id"       -Content $FileContent
$Device   = Get-FrontmatterField -Field "device"   -Content $FileContent
$Platform = Get-FrontmatterField -Field "platform" -Content $FileContent
$Category = Get-FrontmatterField -Field "category" -Content $FileContent
$Tags     = Get-FrontmatterField -Field "tags"     -Content $FileContent

if (-not $IssueId) {
    Write-Host "[ERROR] Could not parse issue ID from frontmatter: $IssuePath" -ForegroundColor Red
    exit 2
}

# Extract body sections
$ContextText  = Get-SectionBody -SectionName "Context"  -Content $FileContent
$SymptomsText = Get-SectionBody -SectionName "Symptoms" -Content $FileContent

# Fallback section names (older issue formats)
if (-not $ContextText)  { $ContextText  = Get-SectionBody -SectionName "Problem"     -Content $FileContent }
if (-not $ContextText)  { $ContextText  = Get-SectionBody -SectionName "Description" -Content $FileContent }
if (-not $ContextText)  { $ContextText  = "(No context section found — see local issue file)" }
if (-not $SymptomsText) { $SymptomsText = "(No symptoms section found — see local issue file)" }

# Detect component and platform
$Component     = Get-ComponentType  -Text $FileContent
$AffectedFile  = Get-AffectedFile   -Text $FileContent
$PlatformLabel = Get-PlatformLabel  -Platform $Platform -FullText $FileContent
$ComponentName = if ($AffectedFile -ne "(see issue body)") { Split-Path -Leaf $AffectedFile } else { $IssueId }

# Build title
$Title = Get-FrontmatterField -Field "title" -Content $FileContent
if (-not $Title) {
    $H1Match = [regex]::Match($FileContent, "(?m)^#\s+(.+)$")
    if ($H1Match.Success) { $Title = $H1Match.Groups[1].Value.Trim() }
}
if (-not $Title) { $Title = "Skill bug: $IssueId" }
if ($Title -notmatch "skill.bug|skill bug") { $Title = "[skill-bug] $Title" }

# Check gh availability
$GhPath = Get-Command gh -ErrorAction SilentlyContinue
if (-not $GhPath) {
    Invoke-GhFallback -FilePath $IssuePath -Reason "gh not found in PATH"
    exit 0
}

$AuthCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Invoke-GhFallback -FilePath $IssuePath -Reason "gh not authenticated (run: gh auth login)"
    exit 0
}

# Duplicate check
Write-Host "[INFO] Checking for duplicate issues on $GithubRepo..." -ForegroundColor Cyan
$ExistingTitles = gh issue list --repo $GithubRepo --label "skill-bug" --state open --json title --jq ".[].title" 2>/dev/null

if ($ExistingTitles -contains $IssueId -or ($ExistingTitles | Where-Object { $_ -match [regex]::Escape($IssueId) })) {
    Write-Host "[WARN] Duplicate found — $IssueId is already posted on GitHub. Skipping." -ForegroundColor Yellow
    Log-AdminEvent -Message "Skill issue already on GitHub (duplicate): $IssueId" -Level "INFO"
    exit 0
}

$ComponentMatches = $ExistingTitles | Where-Object { $_ -match [regex]::Escape($ComponentName) }
if ($ComponentMatches -and $ComponentName -ne $IssueId) {
    Write-Host "[WARN] A similar issue for '$ComponentName' already exists:" -ForegroundColor Yellow
    $ComponentMatches | ForEach-Object { Write-Host "  - $_" }
    $Confirm = Read-Host "Post anyway? (y/N)"
    if ($Confirm -ne "y" -and $Confirm -ne "Y") {
        Write-Host "Skipping."
        exit 0
    }
}

# Build issue body
$Body = @"
## Skill Bug Report

**Local Issue ID:** ``$IssueId``
**Device:** $Device
**Platform:** $Platform
**Affected Component:** ${Component}: ``$ComponentName``
**Affected File:** ``$AffectedFile``

## Context
$ContextText

## Symptoms
$SymptomsText

---
*Full investigation record in local issue file ``$IssueId``. This issue was auto-generated by the admin-devops escalation workflow.*
"@

$Labels = "skill-bug,${Component},${PlatformLabel},needs-triage"

# Display summary and confirm
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  Skill Bug Escalation" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  Repo:       $GithubRepo"
Write-Host "  Title:      $Title"
Write-Host "  Component:  ${Component}: $ComponentName"
Write-Host "  Platform:   $PlatformLabel"
Write-Host "  Labels:     $Labels"
Write-Host "  Local ID:   $IssueId"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host ""

$Confirm = Read-Host "Post to GitHub Issues on ${GithubRepo}? (y/N)"
if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Host "Escalation cancelled. Issue remains local."
    Log-AdminEvent -Message "Skill issue escalation declined by operator: $IssueId" -Level "INFO"
    exit 0
}

# Post to GitHub
Write-Host "[INFO] Posting to $GithubRepo..." -ForegroundColor Cyan

# Write body to temp file to avoid escaping issues in CLI
$TempBody = [System.IO.Path]::GetTempFileName() + ".md"
Set-Content -Path $TempBody -Value $Body -Encoding UTF8

try {
    $IssueUrl = gh issue create `
        --repo $GithubRepo `
        --title $Title `
        --body-file $TempBody `
        --label $Labels 2>&1

    if ($IssueUrl -match "^https://github.com/") {
        Write-Host "[OK] Issue posted: $IssueUrl" -ForegroundColor Green

        # Update local file
        Set-FrontmatterField -Field "github_issue_url" -Value $IssueUrl -FilePath $IssuePath
        $IsoTimestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
        $Content = Get-Content -Path $IssuePath -Raw
        $Content = $Content -replace "(?m)^updated:.*", "updated: $IsoTimestamp"
        Set-Content -Path $IssuePath -Value $Content -Encoding UTF8 -NoNewline

        Log-AdminEvent -Message "Skill issue escalated to GitHub: $IssueId → $IssueUrl" -Level "OK"
        Write-Host "[OK] Local issue updated with GitHub URL." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] gh issue create returned unexpected output:" -ForegroundColor Red
        Write-Host $IssueUrl -ForegroundColor Red
        Invoke-GhFallback -FilePath $IssuePath -Reason "gh issue create returned unexpected output"
    }
} finally {
    if (Test-Path $TempBody) { Remove-Item $TempBody -Force }
}
