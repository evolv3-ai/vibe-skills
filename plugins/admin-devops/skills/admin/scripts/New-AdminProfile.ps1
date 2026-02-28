#Requires -Version 5.1
<#
.SYNOPSIS
    Create a new Admin profile (non-interactive, parameter-driven)
.DESCRIPTION
    Creates the Admin profile and directory structure based on provided parameters.
    Designed to be called by an AI agent after gathering preferences via TUI.
    No interactive prompts - all options passed as parameters.
.PARAMETER AdminRoot
    Path to the .admin directory. Default: $HOME/.admin
.PARAMETER MultiDevice
    Switch to indicate multi-device setup (cloud-synced storage)
.PARAMETER PkgMgr
    Preferred package manager: winget, scoop, choco, brew, apt. Default: winget (Windows), brew (macOS), apt (Linux)
.PARAMETER PyMgr
    Preferred Python manager: uv, pip, conda, poetry. Default: uv
.PARAMETER NodeMgr
    Preferred Node manager: npm, pnpm, yarn, bun. Default: npm
.PARAMETER ShellDefault
    Default shell: pwsh, powershell, bash, zsh. Default: pwsh
.PARAMETER RunInventory
    Switch to run tool inventory scan
.PARAMETER Force
    Overwrite existing profile
.EXAMPLE
    .\New-AdminProfile.ps1 -RunInventory
    Creates profile with defaults and runs inventory scan
.EXAMPLE
    .\New-AdminProfile.ps1 -AdminRoot "D:\Dropbox\.admin" -MultiDevice -PkgMgr scoop -PyMgr uv
    Creates multi-device profile with custom preferences
#>

[CmdletBinding()]
param(
    [string]$AdminRoot,
    [switch]$MultiDevice,
    [ValidateSet("winget", "scoop", "choco", "brew", "apt")]
    [string]$PkgMgr,
    [ValidateSet("uv", "pip", "conda", "poetry")]
    [string]$PyMgr = "uv",
    [ValidateSet("npm", "pnpm", "yarn", "bun")]
    [string]$NodeMgr = "npm",
    [ValidateSet("pwsh", "powershell", "bash", "zsh")]
    [string]$ShellDefault = "pwsh",
    [switch]$RunInventory,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Output helpers
function Write-Section { param([string]$Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Cyan }
function Write-Info { param([string]$Msg) Write-Host "[i] $Msg" -ForegroundColor Gray }
function Write-OK { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "[!] $Msg" -ForegroundColor Yellow }

# Resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $SkillRoot "VERSION"
$EnvTemplate = Join-Path $SkillRoot "templates\.env.template"

# Read admin skill version
$AdminSkillVersion = "0.1.0"
if (Test-Path $VersionFile) {
    $AdminSkillVersion = (Get-Content $VersionFile -First 1).Trim()
}

# Read sibling skill VERSION files for skillVersions tracking
$SkillsRoot = Split-Path -Parent $SkillRoot
$SiblingSkills = @("admin", "devops", "oci", "hetzner", "contabo", "digital-ocean", "vultr", "linode", "coolify", "kasm")
$SkillVersions = [ordered]@{}
foreach ($skillName in $SiblingSkills) {
    $siblingVersionFile = Join-Path $SkillsRoot "$skillName\VERSION"
    if (Test-Path $siblingVersionFile) {
        $SkillVersions[$skillName] = (Get-Content $siblingVersionFile -First 1).Trim()
    } else {
        $SkillVersions[$skillName] = "unknown"
    }
}

# Set defaults based on platform
if (-not $AdminRoot) {
    $AdminRoot = Join-Path $HOME ".admin"
}

if (-not $PkgMgr) {
    # Detect platform and set default
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $PkgMgr = "winget"
    } elseif ($IsMacOS) {
        $PkgMgr = "brew"
    } else {
        $PkgMgr = "apt"
    }
}

$DeviceName = $env:COMPUTERNAME
if (-not $DeviceName) {
    $DeviceName = (hostname).Trim()
}

$ProfilePath = Join-Path $AdminRoot "profiles\$DeviceName.json"

Write-Section "New Admin Profile"
Write-Host "Device:     $DeviceName"
Write-Host "AdminRoot:  $AdminRoot"
Write-Host "MultiDevice: $MultiDevice"

# Check existing profile
if ((Test-Path $ProfilePath) -and -not $Force) {
    Write-Warn "Profile already exists: $ProfilePath"
    Write-Host "Use -Force to overwrite" -ForegroundColor Yellow

    # Return JSON for agent consumption
    @{
        success = $false
        error = "profile_exists"
        path = $ProfilePath
        message = "Profile already exists. Use -Force to overwrite."
    } | ConvertTo-Json -Compress
    exit 1
}

# Create directory structure
Write-Section "Creating Directories"
$dirs = @(
    $AdminRoot,
    (Join-Path $AdminRoot "profiles"),
    (Join-Path $AdminRoot "logs"),
    (Join-Path $AdminRoot "logs\devices"),
    (Join-Path $AdminRoot "issues"),
    (Join-Path $AdminRoot "registries"),
    (Join-Path $AdminRoot "config"),
    (Join-Path $AdminRoot "backups"),
    (Join-Path $AdminRoot "scripts"),
    (Join-Path $AdminRoot "inbox")
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
        Write-OK "Created: $dir"
    }
}

# Normalize paths (forward slashes for JSON)
$AdminRootNorm = $AdminRoot -replace '\\', '/'

# Gather system info
Write-Section "Detecting System"
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)

Write-OK "OS: $($os.Caption)"
Write-OK "CPU: $($cpu.Name)"
Write-OK "RAM: $ram GB"

# Build base profile
$profile = [ordered]@{
    schemaVersion = "3.0"
    adminSkillVersion = $AdminSkillVersion
    multiDevice = [bool]$MultiDevice
    skillVersions = $SkillVersions
    device = [ordered]@{
        name = $DeviceName
        platform = "windows"
        shell = $ShellDefault
        user = $env:USERNAME
        os = $os.Caption
        osVersion = $os.Version
        architecture = $env:PROCESSOR_ARCHITECTURE
        cpu = $cpu.Name
        cores = $cpu.NumberOfCores
        threads = $cpu.NumberOfLogicalProcessors
        ram = "$ram GB"
        timezone = (Get-TimeZone).Id
        envType = "windows"
        created = (Get-Date).ToString("o")
        lastUpdated = (Get-Date).ToString("o")
    }
    paths = [ordered]@{
        adminRoot = $AdminRootNorm
        deviceProfile = "$AdminRootNorm/profiles/$DeviceName.json"
        logs = "$AdminRootNorm/logs"
        issuesDir = "$AdminRootNorm/issues"
        registries = "$AdminRootNorm/registries"
        config = "$AdminRootNorm/config"
        backups = "$AdminRootNorm/backups"
        scripts = "$AdminRootNorm/scripts"
        inbox = "$AdminRootNorm/inbox"
        mcpRegistry = "$AdminRootNorm/registries/mcp-registry.json"
        skillsRegistry = "$AdminRootNorm/registries/skills-registry.json"
        devopsRegistry = "$AdminRootNorm/registries/devops-registry.json"
    }
    packageManagers = @{}
    tools = @{}
    preferences = [ordered]@{
        packages = @{ manager = $PkgMgr }
        python = @{ manager = $PyMgr }
        node = @{ manager = $NodeMgr }
        shell = @{ default = $ShellDefault }
    }
    wsl = @{}
    docker = @{}
    mcp = @{ servers = @{} }
    servers = @()
    deployments = @{}
    issues = @{ current = @(); resolved = @() }
    history = @(
        @{
            date = (Get-Date).ToString("o")
            action = "profile_create"
            tool = "New-AdminProfile"
            method = "tui-driven"
            status = "success"
            details = "Profile created via TUI interview"
        }
    )
    capabilities = @{}
}

# Optional: Run inventory scan
if ($RunInventory) {
    Write-Section "Running Inventory Scan"

    # Package managers
    $pkgManagers = @{}

    # winget
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $wingetVer = (winget --version 2>$null) -replace '^v', ''
        $pkgManagers["winget"] = @{ present = $true; version = $wingetVer; path = $wingetCmd.Source }
        Write-OK "winget: $wingetVer"
    }

    # scoop
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        $pkgManagers["scoop"] = @{ present = $true; path = $scoopCmd.Source }
        Write-OK "scoop: found"
    }

    # npm
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $npmVer = (npm --version 2>$null)
        $pkgManagers["npm"] = @{ present = $true; version = $npmVer; path = $npmCmd.Source }
        Write-OK "npm: $npmVer"
    }

    # pnpm
    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($pnpmCmd) {
        $pnpmVer = (pnpm --version 2>$null)
        $pkgManagers["pnpm"] = @{ present = $true; version = $pnpmVer; path = $pnpmCmd.Source }
        Write-OK "pnpm: $pnpmVer"
    }

    # uv
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCmd) {
        $uvVer = ((uv --version 2>$null) -split ' ')[1]
        $pkgManagers["uv"] = @{ present = $true; version = $uvVer; path = $uvCmd.Source }
        Write-OK "uv: $uvVer"
    }

    # pip
    $pipCmd = Get-Command pip -ErrorAction SilentlyContinue
    if ($pipCmd) {
        $pipVer = ((pip --version 2>$null) -split ' ')[1]
        $pkgManagers["pip"] = @{ present = $true; version = $pipVer; path = $pipCmd.Source }
        Write-OK "pip: $pipVer"
    }

    $profile.packageManagers = $pkgManagers

    # Tools
    $tools = @{}

    # git
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = ((git --version 2>$null) -split ' ')[-1]
        $tools["git"] = @{ present = $true; version = $gitVer; path = $gitCmd.Source }
        Write-OK "git: $gitVer"
    }

    # node
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = (node --version 2>$null) -replace '^v', ''
        $tools["node"] = @{ present = $true; version = $nodeVer; path = $nodeCmd.Source }
        Write-OK "node: $nodeVer"
    }

    # python
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $pythonVer = ((python --version 2>$null) -split ' ')[-1]
        $tools["python"] = @{ present = $true; version = $pythonVer; path = $pythonCmd.Source }
        Write-OK "python: $pythonVer"
    }

    # docker
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        $dockerVer = ((docker --version 2>$null) -split ' ')[2] -replace ',', ''
        $tools["docker"] = @{ present = $true; version = $dockerVer; path = $dockerCmd.Source }
        $profile.capabilities["hasDocker"] = $true
        Write-OK "docker: $dockerVer"
    }

    # wsl
    $wslCmd = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslCmd) {
        $profile.capabilities["hasWsl"] = $true
        Write-OK "wsl: available"
    }

    # ssh
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if ($sshCmd) {
        $tools["ssh"] = @{ present = $true; path = $sshCmd.Source }
        $profile.capabilities["hasSsh"] = $true
        Write-OK "ssh: available"
    }

    # claude
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $claudeVer = ((claude --version 2>$null) -split ' ')[-1] -replace '^v', ''
        $tools["claude"] = @{ present = $true; version = $claudeVer; path = $claudeCmd.Source }
        Write-OK "claude: $claudeVer"
    }

    # code (VS Code)
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) {
        $tools["code"] = @{ present = $true; path = $codeCmd.Source }
        Write-OK "code: available"
    }

    $profile.tools = $tools
}

$profile.capabilities["canRunPowershell"] = $true

# Save profile
Write-Section "Saving Profile"
$profile | ConvertTo-Json -Depth 10 | Set-Content -Path $ProfilePath -Encoding UTF8
Write-OK "Profile: $ProfilePath"

# Create/update .env (root - at ADMIN_ROOT)
$EnvFile = Join-Path $AdminRoot ".env"
if (-not (Test-Path $EnvFile) -and (Test-Path $EnvTemplate)) {
    Copy-Item $EnvTemplate $EnvFile
}
if (-not (Test-Path $EnvFile)) {
    "ADMIN_ROOT=$AdminRootNorm" | Set-Content $EnvFile -Encoding UTF8
} else {
    $lines = Get-Content $EnvFile
    if ($lines -match '^ADMIN_ROOT=') {
        $lines = $lines -replace '^ADMIN_ROOT=.*', "ADMIN_ROOT=$AdminRootNorm"
    } else {
        $lines += "ADMIN_ROOT=$AdminRootNorm"
    }
    $lines | Set-Content $EnvFile -Encoding UTF8
}

Write-OK ".env updated (ADMIN_ROOT only - device vars in satellite)"

# Set environment variables for current session
$env:ADMIN_ROOT = $AdminRoot
$env:ADMIN_DEVICE = $DeviceName
$env:ADMIN_PLATFORM = "windows"

# Copy AGENTS.md template if exists
$AgentsMdTemplate = Join-Path $SkillRoot "templates\AGENTS.md"
$AgentsMdPath = Join-Path $AdminRoot "AGENTS.md"
if (Test-Path $AgentsMdTemplate) {
    Copy-Item $AgentsMdTemplate $AgentsMdPath -Force
    Write-OK "AGENTS.md generated"
}

# Summary
Write-Section "Profile Created Successfully"
Write-Host "Profile:      $ProfilePath" -ForegroundColor Green
Write-Host "ADMIN_ROOT:   $AdminRoot" -ForegroundColor Green
Write-Host "Multi-device: $MultiDevice" -ForegroundColor $(if ($MultiDevice) { "Cyan" } else { "Gray" })
Write-Host ""
Write-Host "Preferences:" -ForegroundColor Yellow
Write-Host "  Packages: $PkgMgr"
Write-Host "  Python:   $PyMgr"
Write-Host "  Node:     $NodeMgr"
Write-Host "  Shell:    $ShellDefault"

# Output JSON for agent consumption
Write-Host ""
@{
    success = $true
    path = $ProfilePath
    adminRoot = $AdminRoot
    device = $DeviceName
    preferences = @{
        packages = $PkgMgr
        python = $PyMgr
        node = $NodeMgr
        shell = $ShellDefault
    }
} | ConvertTo-Json -Compress
