# diagnose-mcp.ps1
# Comprehensive MCP server diagnostic tool
# Collects all information needed for troubleshooting MCP issues
# Usage: .\scripts\diagnose-mcp.ps1 [-ServerName "server-name"] [-OutputFile "report.md"]

param(
    [string]$ServerName,          # Specific server to diagnose (optional)
    [string]$OutputFile,          # Save report to file (optional)
    [switch]$Verbose,             # Show extra details
    [switch]$Json                 # Output as JSON instead of markdown
)

$ErrorActionPreference = "Continue"
$report = @()
$issues = @()
$warnings = @()

function Add-Section {
    param([string]$Title, [string]$Content)
    $script:report += "`n## $Title`n"
    $script:report += $Content
}

function Add-Issue {
    param([string]$Issue, [string]$Fix)
    $script:issues += @{ Issue = $Issue; Fix = $Fix }
}

function Add-Warning {
    param([string]$Warning)
    $script:warnings += $Warning
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-SafeContent {
    param([string]$Path)
    if (Test-Path $Path) {
        Get-Content $Path -Raw -ErrorAction SilentlyContinue
    } else {
        "[File not found: $Path]"
    }
}

# =============================================================================
# Header
# =============================================================================
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$report += "# MCP Diagnostic Report"
$report += "`nGenerated: $timestamp"
$report += "`nDevice: $env:COMPUTERNAME"
$report += "`nUser: $env:USERNAME"

if ($ServerName) {
    $report += "`nTarget Server: $ServerName"
}

# =============================================================================
# 1. System Environment
# =============================================================================
$envInfo = @"

| Component | Value |
|-----------|-------|
| OS | $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption) |
| OS Version | $([Environment]::OSVersion.Version) |
| PowerShell | $($PSVersionTable.PSVersion) |
| PowerShell Edition | $($PSVersionTable.PSEdition) |
| Current Directory | $(Get-Location) |

"@
Add-Section "System Environment" $envInfo

# =============================================================================
# 2. Node.js Environment
# =============================================================================
$nodeSection = "`n"

# Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVersion = & node --version 2>&1
    $nodePath = $nodeCmd.Source
    $nodeSection += "| Node.js Version | $nodeVersion |`n"
    $nodeSection += "| Node.js Path | ``$nodePath`` |`n"
} else {
    $nodeSection += "| Node.js | **NOT FOUND** |`n"
    Add-Issue "Node.js not found in PATH" "Install Node.js: winget install OpenJS.NodeJS.LTS"
}

# npm
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    $npmVersion = & npm --version 2>&1
    $npmPath = $npmCmd.Source
    $npmGlobalPath = & npm root -g 2>&1
    $nodeSection += "| npm Version | $npmVersion |`n"
    $nodeSection += "| npm Path | ``$npmPath`` |`n"
    $nodeSection += "| npm Global Modules | ``$npmGlobalPath`` |`n"
} else {
    $nodeSection += "| npm | **NOT FOUND** |`n"
    Add-Issue "npm not found in PATH" "Ensure Node.js is properly installed"
}

# npx
$npxCmd = Get-Command npx.cmd -ErrorAction SilentlyContinue
if ($npxCmd) {
    $nodeSection += "| npx.cmd Path | ``$($npxCmd.Source)`` |`n"
} else {
    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
        $nodeSection += "| npx Path | ``$($npxCmd.Source)`` |`n"
        Add-Warning "Using 'npx' instead of 'npx.cmd' - may cause issues on Windows"
    } else {
        $nodeSection += "| npx | **NOT FOUND** |`n"
        Add-Issue "npx not found" "Reinstall Node.js or check PATH"
    }
}

Add-Section "Node.js Environment" "| Component | Value |`n|-----------|-------|`n$nodeSection"

# =============================================================================
# 3. PATH Analysis
# =============================================================================
$pathSection = "`n### User PATH (Registry)`n``````"
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$userPath -split ';' | ForEach-Object { $pathSection += "`n$_" }
$pathSection += "`n```````n"

$pathSection += "`n### Session PATH`n``````"
$relevantPaths = $env:PATH -split ';' | Where-Object {
    $_ -match 'node|npm|Program Files|scoop|AppData'
}
$relevantPaths | ForEach-Object { $pathSection += "`n$_" }
$pathSection += "`n```````n"

# Check npm in PATH
$npmInPath = $env:PATH -split ';' | Where-Object { $_ -like "*npm*" }
if (-not $npmInPath) {
    Add-Issue "npm global path not in PATH" "Add $env:APPDATA\npm to User PATH"
}

Add-Section "PATH Analysis" $pathSection

# =============================================================================
# 4. Claude Desktop Configuration
# =============================================================================
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$configSection = "`n"

$configSection += "| Item | Value |`n|------|-------|`n"
$configSection += "| Config Path | ``$configPath`` |`n"
$configSection += "| Config Exists | $(Test-Path $configPath) |`n"

if (Test-Path $configPath) {
    $configFile = Get-Item $configPath
    $configSection += "| Config Size | $($configFile.Length) bytes |`n"
    $configSection += "| Last Modified | $($configFile.LastWriteTime) |`n"

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $serverCount = ($config.mcpServers.PSObject.Properties | Measure-Object).Count
        $configSection += "| MCP Servers Count | $serverCount |`n"
        $configSection += "| JSON Valid | Yes |`n"

        $configSection += "`n### Configured MCP Servers`n"
        $configSection += "| Server | Command | Status |`n|--------|---------|--------|`n"

        foreach ($server in $config.mcpServers.PSObject.Properties) {
            $name = $server.Name
            $cmd = $server.Value.command
            $disabled = if ($server.Value.disabled) { "Disabled" } else { "Enabled" }
            $configSection += "| $name | ``$cmd`` | $disabled |`n"
        }
    } catch {
        $configSection += "| JSON Valid | **NO - PARSE ERROR** |`n"
        Add-Issue "Config file is not valid JSON" "Check for syntax errors in config"
        $configSection += "`n**Parse Error:** $($_.Exception.Message)`n"
    }
} else {
    Add-Issue "Claude Desktop config not found" "Is Claude Desktop installed?"
}

Add-Section "Claude Desktop Configuration" $configSection

# =============================================================================
# 5. Specific Server Diagnosis (if requested)
# =============================================================================
if ($ServerName -and (Test-Path $configPath)) {
    $serverSection = "`n"

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $server = $config.mcpServers.$ServerName

        if ($server) {
            $serverSection += "### Server Configuration`n``````json`n"
            $serverSection += ($server | ConvertTo-Json -Depth 5)
            $serverSection += "`n```````n"

            # Verify command exists
            $serverSection += "`n### Command Verification`n"
            $cmd = $server.command
            $cmdExists = Test-CommandExists $cmd

            if (-not $cmdExists) {
                # Try as path
                $cmdExists = Test-Path $cmd
            }

            $serverSection += "| Check | Result |`n|-------|--------|`n"
            $serverSection += "| Command | ``$cmd`` |`n"
            $serverSection += "| Command Exists | $cmdExists |`n"

            if (-not $cmdExists) {
                Add-Issue "Command '$cmd' not found" "Verify the executable path exists"
            }

            # Verify args (file paths)
            if ($server.args) {
                $serverSection += "`n### Arguments Verification`n"
                $serverSection += "| Argument | Is Path | Exists |`n|----------|---------|--------|`n"

                foreach ($arg in $server.args) {
                    $isPath = $arg -match '^[A-Za-z]:[\\/]' -or $arg -match '^/' -or $arg -match '\.(js|mjs|ts)$'
                    $exists = if ($isPath) { Test-Path $arg } else { "N/A" }
                    $serverSection += "| ``$arg`` | $isPath | $exists |`n"

                    if ($isPath -and -not (Test-Path $arg)) {
                        Add-Issue "Path in args does not exist: $arg" "Check file path is correct"
                    }
                }
            }

            # Check environment variables
            if ($server.env) {
                $serverSection += "`n### Environment Variables`n"
                $serverSection += "| Variable | Set | Value Preview |`n|----------|-----|---------------|`n"

                foreach ($envVar in $server.env.PSObject.Properties) {
                    $name = $envVar.Name
                    $value = $envVar.Value
                    $preview = if ($value.Length -gt 20) { $value.Substring(0, 20) + "..." } else { $value }
                    # Mask sensitive values
                    if ($name -match 'KEY|TOKEN|SECRET|PASSWORD') {
                        $preview = "[REDACTED]"
                    }
                    $isSet = $value -and $value.Length -gt 0
                    $serverSection += "| $name | $isSet | $preview |`n"

                    if (-not $isSet) {
                        Add-Warning "Environment variable $name appears empty"
                    }
                }
            }

        } else {
            $serverSection += "**Server '$ServerName' not found in configuration**`n"
            Add-Issue "Server not found" "Check server name spelling"
        }
    } catch {
        $serverSection += "Error analyzing server: $($_.Exception.Message)`n"
    }

    Add-Section "Server Diagnosis: $ServerName" $serverSection
}

# =============================================================================
# 6. MCP Directory Analysis
# =============================================================================
$mcpRoot = "D:/mcp"
$mcpSection = "`n"

$mcpSection += "| Check | Result |`n|-------|--------|`n"
$mcpSection += "| MCP Root | ``$mcpRoot`` |`n"
$mcpSection += "| Directory Exists | $(Test-Path $mcpRoot) |`n"

if (Test-Path $mcpRoot) {
    $mcpDirs = Get-ChildItem $mcpRoot -Directory -ErrorAction SilentlyContinue
    $mcpSection += "| Subdirectories | $($mcpDirs.Count) |`n"

    $mcpSection += "`n### Installed MCP Servers (Local)`n"
    $mcpSection += "| Directory | Has dist/ | Has node_modules/ | Has package.json |`n"
    $mcpSection += "|-----------|-----------|-------------------|------------------|`n"

    foreach ($dir in $mcpDirs) {
        $hasDist = Test-Path "$($dir.FullName)/dist"
        $hasNodeModules = Test-Path "$($dir.FullName)/node_modules"
        $hasPackageJson = Test-Path "$($dir.FullName)/package.json"
        $mcpSection += "| $($dir.Name) | $hasDist | $hasNodeModules | $hasPackageJson |`n"

        if ($hasPackageJson -and -not $hasNodeModules) {
            Add-Warning "$($dir.Name): Has package.json but no node_modules - run npm install"
        }
        if ($hasPackageJson -and -not $hasDist) {
            Add-Warning "$($dir.Name): Has package.json but no dist - run npm run build"
        }
    }
}

Add-Section "MCP Directory Analysis" $mcpSection

# =============================================================================
# 7. Process Information
# =============================================================================
$processSection = "`n"

# Claude Desktop process
$claudeProcess = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
$processSection += "### Claude Desktop Process`n"
$processSection += "| Property | Value |`n|----------|-------|`n"

if ($claudeProcess) {
    $processSection += "| Running | Yes |`n"
    $processSection += "| PID | $($claudeProcess.Id) |`n"
    $processSection += "| Memory (MB) | $([math]::Round($claudeProcess.WorkingSet64 / 1MB, 2)) |`n"
    $processSection += "| Start Time | $($claudeProcess.StartTime) |`n"
} else {
    $processSection += "| Running | **No** |`n"
    Add-Warning "Claude Desktop is not running"
}

# Node processes (potential MCP servers)
$nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue
$processSection += "`n### Node.js Processes (Potential MCP Servers)`n"

if ($nodeProcesses) {
    $processSection += "| PID | Memory (MB) | Command Line |`n|-----|-------------|--------------|`n"

    foreach ($proc in $nodeProcesses) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
            $cmdLineShort = if ($cmdLine -and $cmdLine.Length -gt 80) { $cmdLine.Substring(0, 80) + "..." } else { $cmdLine }
            $mem = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $processSection += "| $($proc.Id) | $mem | ``$cmdLineShort`` |`n"
        } catch {
            $processSection += "| $($proc.Id) | N/A | [Access Denied] |`n"
        }
    }
} else {
    $processSection += "No Node.js processes running.`n"
}

Add-Section "Process Information" $processSection

# =============================================================================
# 8. Claude Desktop Logs
# =============================================================================
$logsSection = "`n"
$claudeLogDir = "$env:APPDATA\Claude\logs"

$logsSection += "| Check | Result |`n|-------|--------|`n"
$logsSection += "| Log Directory | ``$claudeLogDir`` |`n"
$logsSection += "| Directory Exists | $(Test-Path $claudeLogDir) |`n"

if (Test-Path $claudeLogDir) {
    $logFiles = Get-ChildItem $claudeLogDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $logsSection += "| Log Files | $($logFiles.Count) |`n"

    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles[0]
        $logsSection += "| Latest Log | ``$($latestLog.Name)`` |`n"
        $logsSection += "| Latest Log Modified | $($latestLog.LastWriteTime) |`n"

        # Get last 20 lines of latest log
        $logsSection += "`n### Recent Log Entries (Last 20 lines)`n``````"
        $logContent = Get-Content $latestLog.FullName -Tail 20 -ErrorAction SilentlyContinue
        if ($logContent) {
            $logContent | ForEach-Object { $logsSection += "`n$_" }
        } else {
            $logsSection += "`n[Log file empty or inaccessible]"
        }
        $logsSection += "`n```````n"

        # Look for MCP-related errors
        $mcpErrors = Get-Content $latestLog.FullName -ErrorAction SilentlyContinue |
                     Select-String -Pattern "mcp|MCP|spawn|ENOENT|error|Error" -Context 0,2 |
                     Select-Object -Last 10

        if ($mcpErrors) {
            $logsSection += "`n### MCP-Related Log Entries`n``````"
            $mcpErrors | ForEach-Object { $logsSection += "`n$($_.Line)" }
            $logsSection += "`n```````n"
        }
    }
} else {
    $logsSection += "`nLog directory not found.`n"
}

Add-Section "Claude Desktop Logs" $logsSection

# =============================================================================
# 9. Common Issues Check
# =============================================================================
$checkSection = "`n"
$checkSection += "| Check | Status | Details |`n|-------|--------|---------|`n"

# Check 1: Config file readable
$check1 = Test-Path $configPath
$checkSection += "| Config file exists | $(if($check1){'Pass'}else{'**FAIL**'}) | |`n"

# Check 2: Node in PATH
$check2 = Test-CommandExists "node"
$checkSection += "| Node.js in PATH | $(if($check2){'Pass'}else{'**FAIL**'}) | |`n"

# Check 3: npx.cmd exists (Windows specific)
$check3 = Test-CommandExists "npx.cmd"
$checkSection += "| npx.cmd available | $(if($check3){'Pass'}else{'**FAIL**'}) | Use npx.cmd on Windows |`n"

# Check 4: npm global in PATH
$check4 = $env:PATH -like "*npm*"
$checkSection += "| npm in PATH | $(if($check4){'Pass'}else{'**FAIL**'}) | |`n"

# Check 5: MCP root exists
$check5 = Test-Path $mcpRoot
$checkSection += "| MCP directory exists | $(if($check5){'Pass'}else{'Warn'}) | Optional for npx servers |`n"

# Check 6: Claude running
$check6 = $null -ne (Get-Process -Name "Claude" -ErrorAction SilentlyContinue)
$checkSection += "| Claude Desktop running | $(if($check6){'Pass'}else{'Warn'}) | |`n"

Add-Section "Quick Checks" $checkSection

# =============================================================================
# 10. Issues and Recommendations
# =============================================================================
$issueSection = "`n"

if ($issues.Count -gt 0) {
    $issueSection += "### Issues Found ($($issues.Count))`n"
    $issueSection += "| Issue | Recommended Fix |`n|-------|-----------------|`n"
    foreach ($issue in $issues) {
        $issueSection += "| $($issue.Issue) | $($issue.Fix) |`n"
    }
} else {
    $issueSection += "No critical issues found.`n"
}

if ($warnings.Count -gt 0) {
    $issueSection += "`n### Warnings ($($warnings.Count))`n"
    foreach ($warning in $warnings) {
        $issueSection += "- $warning`n"
    }
}

Add-Section "Issues and Recommendations" $issueSection

# =============================================================================
# 11. Diagnostic Commands
# =============================================================================
$cmdSection = @"

Run these commands for additional diagnosis:

### Test MCP Server Manually
``````powershell
# Test if server starts (replace with your server path)
node "D:/mcp/your-server/dist/index.js"
``````

### Check npm Global Packages
``````powershell
npm list -g --depth=0
``````

### Verify Claude CLI (if using Claude Code MCP)
``````powershell
claude --version
``````

### Reset Claude Desktop Config
``````powershell
# Backup current
Copy-Item "$env:APPDATA\Claude\claude_desktop_config.json" "$env:APPDATA\Claude\config.backup.json"

# Create minimal config
@{ mcpServers = @{} } | ConvertTo-Json | Set-Content "$env:APPDATA\Claude\claude_desktop_config.json"

# Restart Claude Desktop
Stop-Process -Name "Claude" -Force; Start-Sleep 2; Start-Process "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
``````

"@
Add-Section "Diagnostic Commands" $cmdSection

# =============================================================================
# Output Report
# =============================================================================
$finalReport = $report -join "`n"

if ($Json) {
    $jsonReport = @{
        timestamp = $timestamp
        device = $env:COMPUTERNAME
        issues = $issues
        warnings = $warnings
        # Add more structured data as needed
    } | ConvertTo-Json -Depth 10

    if ($OutputFile) {
        $jsonReport | Set-Content $OutputFile
        Write-Host "JSON report saved to: $OutputFile" -ForegroundColor Green
    } else {
        $jsonReport
    }
} else {
    if ($OutputFile) {
        $finalReport | Set-Content $OutputFile
        Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
    } else {
        $finalReport
    }
}

# Summary to console
Write-Host "`n=== MCP Diagnostic Summary ===" -ForegroundColor Cyan
Write-Host "Issues Found: $($issues.Count)" -ForegroundColor $(if($issues.Count -gt 0){"Red"}else{"Green"})
Write-Host "Warnings: $($warnings.Count)" -ForegroundColor $(if($warnings.Count -gt 0){"Yellow"}else{"Green"})

if ($issues.Count -gt 0) {
    Write-Host "`nCritical Issues:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $($issue.Issue)" -ForegroundColor Red
    }
}

Write-Host "`nFull report $(if($OutputFile){"saved to $OutputFile"}else{"output above"})" -ForegroundColor Gray
