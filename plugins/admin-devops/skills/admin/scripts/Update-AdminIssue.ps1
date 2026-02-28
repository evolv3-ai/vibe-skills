#Requires -Version 5.1
<#
.SYNOPSIS
    Updates an existing Admin issue file
.DESCRIPTION
    Updates a specific section of an issue file and optionally marks it as resolved.
    Logs the update to operations.log.
.PARAMETER IssueId
    The issue ID (e.g., issue_20260201_141233_audio_driver)
.PARAMETER Section
    Section to update: context, symptoms, hypotheses, actions, resolution, verification, nextaction
.PARAMETER Content
    Content to append to the section
.PARAMETER Resolve
    If specified, marks the issue as resolved
.EXAMPLE
    Update-AdminIssue -IssueId "issue_20260201_141233_audio_driver" -Section resolution -Content "Reinstalled driver from manufacturer website"
.EXAMPLE
    Update-AdminIssue -IssueId "issue_20260201_141233_audio_driver" -Resolve
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$IssueId,

    [ValidateSet("context", "symptoms", "hypotheses", "actions", "resolution", "verification", "nextaction")]
    [string]$Section,

    [string]$Content,

    [switch]$Resolve
)

# Import logging function
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "Log-AdminEvent.ps1")

function Update-AdminIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$IssueId,

        [ValidateSet("context", "symptoms", "hypotheses", "actions", "resolution", "verification", "nextaction")]
        [string]$Section,

        [string]$Content,

        [switch]$Resolve
    )

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    # Find issue file
    $IssuesDir = Join-Path $AdminRoot "issues"
    $IssueFile = Join-Path $IssuesDir "${IssueId}.md"

    if (-not (Test-Path $IssueFile)) {
        # Try to find by partial match
        $Matches = Get-ChildItem -Path $IssuesDir -Filter "*${IssueId}*.md" -ErrorAction SilentlyContinue
        if ($Matches.Count -eq 1) {
            $IssueFile = $Matches[0].FullName
            $IssueId = $Matches[0].BaseName
        } elseif ($Matches.Count -gt 1) {
            Write-Host "[ERROR] Multiple matches found for '$IssueId':" -ForegroundColor Red
            $Matches | ForEach-Object { Write-Host "  - $($_.BaseName)" }
            return $null
        } else {
            Write-Host "[ERROR] Issue not found: $IssueId" -ForegroundColor Red
            return $null
        }
    }

    # Read current content
    $FileContent = Get-Content -Path $IssueFile -Raw

    # Update timestamp in frontmatter
    $IsoTimestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    $FileContent = $FileContent -replace '(updated:\s*)[^\r\n]+', "`$1$IsoTimestamp"

    # Update section if specified
    if ($Section -and $Content) {
        $SectionMap = @{
            "context"     = "## Context"
            "symptoms"    = "## Symptoms"
            "hypotheses"  = "## Hypotheses"
            "actions"     = "## Actions Taken"
            "resolution"  = "## Resolution"
            "verification"= "## Verification"
            "nextaction"  = "## Next Action"
        }

        $SectionHeader = $SectionMap[$Section]

        # Find section and append content
        $Pattern = "($SectionHeader\s*\n)((?:(?!^## ).*\n)*)"
        if ($FileContent -match $Pattern) {
            $ExistingContent = $Matches[2].TrimEnd()
            $NewSectionContent = if ($ExistingContent) {
                "$ExistingContent`n`n$Content`n"
            } else {
                "`n$Content`n"
            }
            $FileContent = $FileContent -replace $Pattern, "`$1$NewSectionContent`n"
        }
    }

    # Update status if resolving
    if ($Resolve) {
        $FileContent = $FileContent -replace '(status:\s*)open', '${1}resolved'
        Log-AdminEvent "Issue resolved: $IssueId" -Level "OK"
        Write-Host "[OK] Issue resolved: $IssueId" -ForegroundColor Green
    } else {
        Log-AdminEvent "Issue updated: $IssueId (section: $Section)" -Level "INFO"
        Write-Host "[OK] Issue updated: $IssueId" -ForegroundColor Green
    }

    # Write updated content
    Set-Content -Path $IssueFile -Value $FileContent -Encoding UTF8 -NoNewline

    return $IssueFile
}

# If script is run directly with parameters, execute the function
if ($IssueId) {
    Update-AdminIssue -IssueId $IssueId -Section $Section -Content $Content -Resolve:$Resolve
}
