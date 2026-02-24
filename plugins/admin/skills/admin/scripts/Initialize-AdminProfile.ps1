#Requires -Version 5.1
<#
.SYNOPSIS
    Initialize a new device profile for Admin Suite v3.0
.DESCRIPTION
    Detects system info, installed tools, and user preferences to create
    a comprehensive device profile for context-aware assistance.
.PARAMETER Force
    Overwrite existing profile
.PARAMETER Minimal
    Create minimal profile (skip tool detection)
.EXAMPLE
    .\Initialize-AdminProfile.ps1
.EXAMPLE
    .\Initialize-AdminProfile.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Minimal
)

$ErrorActionPreference = "Continue"

# Colors
function Write-Status { param([string]$Msg) Write-Host "[*] $Msg" -ForegroundColor Cyan }
function Write-OK { param([string]$Msg) Write-Host "[+] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "[!] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "[-] $Msg" -ForegroundColor Red }

# Setup paths
$AdminRoot = Join-Path $HOME ".admin"
$ProfilesDir = Join-Path $AdminRoot "profiles"
$LogsDir = Join-Path $AdminRoot "logs"
$DeploymentsDir = Join-Path $AdminRoot "deployments"
$DeviceName = $env:COMPUTERNAME
$ProfilePath = Join-Path $ProfilesDir "$DeviceName.json"

Write-Host "`n=== Admin Suite Profile Initializer ===" -ForegroundColor Cyan
Write-Host "Device: $DeviceName"
Write-Host "Profile: $ProfilePath`n"

# Check existing
if ((Test-Path $ProfilePath) -and -not $Force) {
    Write-Warn "Profile already exists: $ProfilePath"
    Write-Host "Use -Force to overwrite"
    return
}

# Create directories
Write-Status "Creating directory structure..."
@($AdminRoot, $ProfilesDir, $LogsDir, $DeploymentsDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-OK "Created: $_"
    }
}

# Detect system info
Write-Status "Detecting system information..."
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)

$device = @{
    name = $DeviceName
    platform = "windows"
    shell = "powershell"
    user = $env:USERNAME
    os = $os.Caption
    osVersion = $os.Version
    architecture = $env:PROCESSOR_ARCHITECTURE
    cpu = $cpu.Name
    cores = $cpu.NumberOfCores
    threads = $cpu.NumberOfLogicalProcessors
    ram = "$ram GB"
    timezone = (Get-TimeZone).Id
    initialized = (Get-Date).ToString("o")
    lastUpdated = (Get-Date).ToString("o")
}
Write-OK "System: $($device.os), $($device.cpu), $($device.ram) RAM"

# Detect paths
Write-Status "Detecting key paths..."
$paths = @{
    adminRoot = $AdminRoot -replace '\\', '/'
    deviceProfile = $ProfilePath -replace '\\', '/'
    logs = $LogsDir -replace '\\', '/'
    claudeConfig = "$env:APPDATA/Claude/claude_desktop_config.json" -replace '\\', '/'
    claudeSkills = $null
    mcpServers = $null
    sshKeys = "$HOME/.ssh" -replace '\\', '/'
    projects = "D:/"
    dropbox = $null
    npmGlobal = "$env:APPDATA/npm" -replace '\\', '/'
    pythonVenvs = "$HOME/.venvs" -replace '\\', '/'
}

# Check for Dropbox
$dropboxPaths = @("$HOME/Dropbox", "N:/Dropbox", "D:/Dropbox")
foreach ($dp in $dropboxPaths) {
    if (Test-Path $dp) {
        $paths.dropbox = $dp -replace '\\', '/'
        Write-OK "Found Dropbox: $($paths.dropbox)"
        break
    }
}

# Helper to check command
function Test-Command {
    param([string]$Name)
    try { 
        $cmd = Get-Command $Name -ErrorAction Stop
        return @{ present = $true; path = $cmd.Source -replace '\\', '/' }
    } catch { 
        return @{ present = $false; path = $null }
    }
}

# Helper to get version
function Get-ToolVersion {
    param([string]$Cmd, [string]$Args = "--version")
    try {
        $output = & $Cmd $Args 2>&1 | Select-Object -First 1
        if ($output -match '[\d]+\.[\d]+\.?[\d]*') {
            return $Matches[0]
        }
        return $output.ToString().Trim()
    } catch {
        return $null
    }
}

# Detect package managers
Write-Status "Detecting package managers..."
$packageManagers = @{}

$pmChecks = @(
    @{ name = "scoop"; cmd = "scoop"; verArgs = "--version" },
    @{ name = "winget"; cmd = "winget"; verArgs = "--version" },
    @{ name = "npm"; cmd = "npm"; verArgs = "--version" },
    @{ name = "pip"; cmd = "pip"; verArgs = "--version" },
    @{ name = "uv"; cmd = "uv"; verArgs = "--version" },
    @{ name = "cargo"; cmd = "cargo"; verArgs = "--version" },
    @{ name = "chocolatey"; cmd = "choco"; verArgs = "--version" }
)

foreach ($pm in $pmChecks) {
    $check = Test-Command $pm.cmd
    $packageManagers[$pm.name] = @{
        present = $check.present
        version = if ($check.present) { Get-ToolVersion $pm.cmd $pm.verArgs } else { $null }
        path = $check.path
        location = $null
        lastChecked = (Get-Date).ToString("o")
        preferred = $false
    }
    if ($check.present) {
        Write-OK "$($pm.name): $($packageManagers[$pm.name].version)"
    }
}

# Set preferred based on what's installed
if ($packageManagers.scoop.present) { $packageManagers.scoop.preferred = $true }
elseif ($packageManagers.winget.present) { $packageManagers.winget.preferred = $true }

if ($packageManagers.uv.present) { $packageManagers.uv.preferred = $true }
elseif ($packageManagers.pip.present) { $packageManagers.pip.preferred = $true }

if ($packageManagers.npm.present) { $packageManagers.npm.preferred = $true }

# Detect tools
$tools = @{}

if (-not $Minimal) {
    Write-Status "Detecting installed tools..."
    
    $toolChecks = @(
        @{ name = "git"; cmd = "git"; verArgs = "--version" },
        @{ name = "node"; cmd = "node"; verArgs = "--version" },
        @{ name = "python"; cmd = "python"; verArgs = "--version" },
        @{ name = "uv"; cmd = "uv"; verArgs = "--version" },
        @{ name = "docker"; cmd = "docker"; verArgs = "--version" },
        @{ name = "ssh"; cmd = "ssh"; verArgs = "-V" },
        @{ name = "terraform"; cmd = "terraform"; verArgs = "--version" },
        @{ name = "go"; cmd = "go"; verArgs = "version" },
        @{ name = "rustc"; cmd = "rustc"; verArgs = "--version" },
        @{ name = "cargo"; cmd = "cargo"; verArgs = "--version" },
        @{ name = "bun"; cmd = "bun"; verArgs = "--version" },
        @{ name = "code"; cmd = "code"; verArgs = "--version" },
        @{ name = "claude"; cmd = "claude"; verArgs = "--version" }
    )
    
    foreach ($tool in $toolChecks) {
        $check = Test-Command $tool.cmd
        if ($check.present) {
            $tools[$tool.name] = @{
                present = $true
                version = Get-ToolVersion $tool.cmd $tool.verArgs
                installedVia = "unknown"
                path = $check.path
                shimPath = $null
                configPath = $null
                lastChecked = (Get-Date).ToString("o")
                installStatus = "working"
                notes = $null
            }
            Write-OK "$($tool.name): $($tools[$tool.name].version)"
        }
    }
    
    # Add notes for key tools
    if ($tools.uv) {
        $tools.uv.notes = "PREFERRED Python package manager. Use instead of pip."
    }
}

# Detect preferences
Write-Status "Setting preferences..."
$preferences = @{
    python = @{
        manager = if ($packageManagers.uv.present) { "uv" } else { "pip" }
        reason = if ($packageManagers.uv.present) { "Fast, modern, replaces pip+venv" } else { "Default" }
    }
    node = @{
        manager = "npm"
        reason = "Default Node.js package manager"
    }
    packages = @{
        manager = if ($packageManagers.scoop.present) { "scoop" } 
                  elseif ($packageManagers.winget.present) { "winget" } 
                  else { "manual" }
        reason = if ($packageManagers.scoop.present) { "Portable installs, good for dev tools" } 
                 elseif ($packageManagers.winget.present) { "Windows default" } 
                 else { "No package manager detected" }
    }
    shell = @{
        preferred = "powershell"
        profilePath = $PROFILE -replace '\\', '/'
    }
    editor = if ($tools.code) { "vscode" } else { "notepad" }
    terminal = "Windows Terminal"
}

Write-OK "Python: $($preferences.python.manager)"
Write-OK "Packages: $($preferences.packages.manager)"

# Detect WSL
Write-Status "Detecting WSL..."
$wsl = $null
try {
    $wslOutput = wsl --list --verbose 2>&1
    if ($LASTEXITCODE -eq 0 -and $wslOutput -notmatch "not recognized") {
        $wsl = @{
            present = $true
            version = (wsl --version 2>&1 | Select-String "WSL version" | ForEach-Object { $_ -replace '.*:\s*', '' })
            defaultDistro = $null
            configFile = "$HOME/.wslconfig" -replace '\\', '/'
            resourceLimits = @{}
            distributions = @{}
        }
        
        # Parse distros
        $wslOutput -split "`n" | Where-Object { $_ -match '^\s*\*?\s*(\S+)\s+(Running|Stopped)\s+(\d+)' } | ForEach-Object {
            if ($_ -match '^\s*(\*)?\s*(\S+)\s+(Running|Stopped)\s+(\d+)') {
                $isDefault = $Matches[1] -eq '*'
                $distroName = $Matches[2]
                if ($isDefault) { $wsl.defaultDistro = $distroName }
                $wsl.distributions[$distroName] = @{
                    default = $isDefault
                    tools = @{}
                }
            }
        }
        Write-OK "WSL: $($wsl.defaultDistro)"
    }
} catch {
    Write-Warn "WSL not available"
}

# Detect Docker
Write-Status "Detecting Docker..."
$docker = $null
if ($tools.docker) {
    $docker = @{
        present = $true
        version = $tools.docker.version
        installedVia = "Docker Desktop"
        backend = if ($wsl) { "WSL2" } else { "Hyper-V" }
        path = $tools.docker.path
        configPath = "$HOME/.docker" -replace '\\', '/'
    }
    Write-OK "Docker: $($docker.version) ($($docker.backend))"
}

# MCP placeholder
$mcp = @{
    configFile = $paths.claudeConfig
    servers = @{}
}

# Capabilities
$capabilities = @{
    canRunPowershell = $true
    canRunBash = [bool]$wsl
    hasWsl = [bool]$wsl
    hasDocker = [bool]$docker
    hasSsh = [bool]$tools.ssh
    hasGit = [bool]$tools.git
    canAccessNetwork = $true
    canAccessDropbox = [bool]$paths.dropbox
    mcpEnabled = Test-Path $paths.claudeConfig
}

# Build profile
$profile = [ordered]@{
    schemaVersion = "3.0"
    device = $device
    paths = $paths
    packageManagers = $packageManagers
    tools = $tools
    preferences = $preferences
    wsl = $wsl
    docker = $docker
    mcp = $mcp
    servers = @()
    deployments = @{}
    issues = @{ current = @(); resolved = @() }
    history = @(
        @{
            date = (Get-Date).ToString("o")
            action = "profile_create"
            tool = "Initialize-AdminProfile"
            method = "auto-detect"
            status = "success"
            details = "Initial profile creation"
        }
    )
    capabilities = $capabilities
}

# Save profile
Write-Status "Saving profile..."
$profile | ConvertTo-Json -Depth 10 | Set-Content $ProfilePath -Encoding UTF8
Write-OK "Profile saved: $ProfilePath"

# Summary
Write-Host "`n=== Profile Summary ===" -ForegroundColor Cyan
Write-Host "Device:      $($device.name) ($($device.platform))"
Write-Host "Tools:       $($tools.Count) detected"
Write-Host "Preferences:"
Write-Host "  Python:    $($preferences.python.manager)"
Write-Host "  Node:      $($preferences.node.manager)"
Write-Host "  Packages:  $($preferences.packages.manager)"
Write-Host "Capabilities:"
$capList = @()
if ($capabilities.hasWsl) { $capList += "WSL" }
if ($capabilities.hasDocker) { $capList += "Docker" }
if ($capabilities.mcpEnabled) { $capList += "MCP" }
if ($capabilities.canAccessDropbox) { $capList += "Dropbox" }
Write-Host "  $($capList -join ', ')"

Write-Host "`n[+] Profile initialized successfully!" -ForegroundColor Green
Write-Host "Next: Load with '. scripts/Load-Profile.ps1; Load-AdminProfile -Export'"
