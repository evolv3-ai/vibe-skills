#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a new Admin issue file
.DESCRIPTION
    Creates a new issue markdown file in $ADMIN_ROOT/issues/ with YAML frontmatter.
    Also logs the creation to operations.log.
.PARAMETER Title
    The issue title (becomes slug in filename)
.PARAMETER Category
    Issue category: troubleshoot, install, devenv, mcp, skills, devops
.PARAMETER Tags
    Optional array of tags
.EXAMPLE
    New-AdminIssue -Title "Audio driver not detected" -Category troubleshoot -Tags @("audio","driver")
.EXAMPLE
    New-AdminIssue "Node install failed" "install" @("node","npm")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Title,

    [Parameter(Mandatory, Position = 1)]
    [ValidateSet("troubleshoot", "install", "devenv", "mcp", "skills", "devops")]
    [string]$Category,

    [Parameter(Position = 2)]
    [string[]]$Tags = @()
)

# Import logging function
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "Log-AdminEvent.ps1")

function New-AdminIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet("troubleshoot", "install", "devenv", "mcp", "skills", "devops")]
        [string]$Category,

        [Parameter(Position = 2)]
        [string[]]$Tags = @()
    )

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    # Ensure issues directory exists
    $IssuesDir = Join-Path $AdminRoot "issues"
    if (-not (Test-Path $IssuesDir)) {
        $null = New-Item -ItemType Directory -Path $IssuesDir -Force
    }

    # Generate ID components
    $Now = Get-Date
    $Timestamp = $Now.ToString("yyyyMMdd_HHmmss")
    $IsoTimestamp = $Now.ToString("yyyy-MM-ddTHH:mm:sszzz")

    # Create slug from title
    $Slug = $Title.ToLower() -replace '[^a-z0-9]+', '_' -replace '^_|_$', ''
    if ($Slug.Length -gt 30) {
        $Slug = $Slug.Substring(0, 30) -replace '_$', ''
    }

    # Build ID and filename
    $IssueId = "issue_${Timestamp}_${Slug}"
    $FileName = "${IssueId}.md"
    $FilePath = Join-Path $IssuesDir $FileName

    # Get device info
    $DeviceName = $env:COMPUTERNAME
    $Platform = "windows"

    # Format tags for YAML
    $TagsYaml = if ($Tags.Count -gt 0) {
        "[" + ($Tags | ForEach-Object { "`"$_`"" }) -join ", " + "]"
    } else {
        "[]"
    }

    # Build issue content
    $Content = @"
---
id: $IssueId
device: $DeviceName
platform: $Platform
status: open
category: $Category
tags: $TagsYaml
created: $IsoTimestamp
updated: $IsoTimestamp
related_logs:
  - logs/operations.log
---

# $Title

## Context


## Symptoms


## Hypotheses


## Actions Taken


## Resolution


## Verification


## Next Action

"@

    # Write file
    Set-Content -Path $FilePath -Value $Content -Encoding UTF8

    # Log the creation
    Log-AdminEvent "Issue created: $IssueId" -Level "INFO"

    Write-Host "[OK] Issue created: $FilePath" -ForegroundColor Green

    return $FilePath
}

# If script is run directly with parameters, execute the function
if ($Title) {
    New-AdminIssue -Title $Title -Category $Category -Tags $Tags
}
