# Update-SkillsRegistry.ps1
# Add or update a skill entry in the central registry
# Logs all operations and creates issues on failures

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,

    [Parameter(Mandatory=$true)]
    [string]$Source,

    [string]$Version = "1.0.0",

    [ValidateSet("plugin", "symlink", "copy", "rules-file")]
    [string]$InstallMethod = "plugin",

    [string]$Bundle = "",

    [string[]]$Clients = @("claude-code"),

    [ValidateSet("active", "inactive", "removed", "pending")]
    [string]$Status = "active",

    [string]$Notes = ""
)

# Import shared helpers from admin skill
$adminScriptsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "admin\scripts"
. (Join-Path $adminScriptsDir "Log-AdminEvent.ps1")
. (Join-Path $adminScriptsDir "New-AdminIssue.ps1")

# Load admin profile to get registry path
$profilePath = if ($env:ADMIN_PROFILE_PATH) {
    $env:ADMIN_PROFILE_PATH
} else {
    "$env:USERPROFILE\.admin\profiles\$env:COMPUTERNAME.json"
}

if (-not (Test-Path $profilePath)) {
    Write-Error "Admin profile not found at $profilePath. Run admin skill first."
    Log-AdminEvent "Skills registry update failed: profile not found" -Level "ERROR"
    New-AdminIssue -Title "Admin profile not found for skills registry" -Category "skills" -Tags @("skills","registry","profile")
    exit 1
}

$AdminProfile = Get-Content $profilePath | ConvertFrom-Json

# Get or create registry path
$registryPath = if ($AdminProfile.paths.skillsRegistry) {
    $AdminProfile.paths.skillsRegistry
} else {
    "$($AdminProfile.paths.adminRoot)\registries\skills-registry.json"
}

# Initialize registry if needed
if (-not (Test-Path $registryPath)) {
    $templatePath = "$PSScriptRoot\..\templates\skills-registry.json"
    if (Test-Path $templatePath) {
        # Ensure registries directory exists
        $registryDir = Split-Path -Parent $registryPath
        if (-not (Test-Path $registryDir)) {
            New-Item -ItemType Directory -Path $registryDir -Force | Out-Null
        }
        Copy-Item $templatePath $registryPath
        Write-Host "Initialized skills registry at $registryPath" -ForegroundColor Green
        Log-AdminEvent "Skills registry initialized from template" -Level "INFO"
    } else {
        Write-Error "Registry template not found. Cannot initialize."
        Log-AdminEvent "Skills registry update failed: template not found" -Level "ERROR"
        New-AdminIssue -Title "Skills registry template not found" -Category "skills" -Tags @("skills","registry","template")
        exit 1
    }
}

# Load registry
try {
    $registry = Get-Content $registryPath | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse skills registry: $_"
    Log-AdminEvent "Skills registry update failed: invalid JSON - $_" -Level "ERROR"
    New-AdminIssue -Title "Invalid skills registry JSON" -Category "skills" -Tags @("skills","registry","json")
    exit 1
}

# Create or update skill entry
$entry = @{
    source = $Source
    version = $Version
    installDate = (Get-Date -Format "yyyy-MM-dd")
    installMethod = $InstallMethod
    bundle = $Bundle
    clients = $Clients
    status = $Status
    lastVerified = (Get-Date -Format "yyyy-MM-dd")
    notes = $Notes
}

# Ensure installedSkills exists
if (-not $registry.installedSkills) {
    $registry | Add-Member -NotePropertyName "installedSkills" -NotePropertyValue @{}
}

# Check if skill exists
if ($registry.installedSkills.PSObject.Properties.Name -contains $SkillName) {
    # Update existing
    $existing = $registry.installedSkills.$SkillName

    # Preserve install date if updating
    $entry.installDate = $existing.installDate

    # Merge clients
    $entry.clients = ($existing.clients + $Clients) | Select-Object -Unique

    $registry.installedSkills.$SkillName = $entry
    Write-Host "Updated skill: $SkillName" -ForegroundColor Yellow
    Log-AdminEvent "Skill updated: $SkillName (source: $Source)" -Level "INFO"
} else {
    # Add new
    $registry.installedSkills | Add-Member -NotePropertyName $SkillName -NotePropertyValue $entry
    Write-Host "Added skill: $SkillName" -ForegroundColor Green
    Log-AdminEvent "Skill added: $SkillName (source: $Source, method: $InstallMethod)" -Level "OK"
}

# Update timestamp
$registry.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

# Add to sync history
$historyEntry = @{
    date = (Get-Date -Format "yyyy-MM-dd")
    action = "registry-update"
    source = $Source
    changes = @("Updated $SkillName")
}

if (-not $registry.syncHistory) {
    $registry | Add-Member -NotePropertyName "syncHistory" -NotePropertyValue @()
}
$registry.syncHistory += $historyEntry

# Save
$registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath

Write-Host ""
Write-Host "Registry updated: $registryPath" -ForegroundColor Cyan
Write-Host "  Skill: $SkillName"
Write-Host "  Source: $Source"
Write-Host "  Clients: $($Clients -join ', ')"
Write-Host "  Status: $Status"
