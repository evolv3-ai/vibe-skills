<#
Session-Scout.ps1
Shows recent Claude Code (Windows + WSL), Claude Desktop, and OpenCode (Windows) sessions,
including best-effort working directory / project path.

Usage:
  pwsh -ExecutionPolicy Bypass -File .\Session-Scout.ps1
  pwsh -ExecutionPolicy Bypass -File .\Session-Scout.ps1 -Top 20
  pwsh -ExecutionPolicy Bypass -File .\Session-Scout.ps1 -Csv                # writes to default location
  pwsh -ExecutionPolicy Bypass -File .\Session-Scout.ps1 -File 'D:\out.csv'  # writes to specified path
#>

[CmdletBinding()]
param(
  [int]$Top = 12,
  [switch]$Csv,
  [string]$File
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Try-ExtractPathFromText([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

  # Common fields that may appear in session jsonl lines
  $patterns = @(
    '(?i)"(cwd|working_dir|workingDir|projectRoot|project_root|repoRoot|repo_root|path|directory)"\s*:\s*"([^"]+)"',
    '(?i)\bdirectory=([A-Za-z]:\\[^ \r\n"]+)',
    '(?i)\bcwd=([A-Za-z]:\\[^ \r\n"]+)'
  )

  foreach ($p in $patterns) {
    $m = [regex]::Match($Text, $p)
    if ($m.Success) {
      $path = $m.Groups[$m.Groups.Count - 1].Value
      # Unescape JSON-escaped backslashes
      $path = $path -replace '\\\\', '\'
      return $path
    }
  }
  return $null
}

function Decode-ClaudeProjectSlug([string]$Slug) {
  # Claude Code encodes paths like "D--admin" for "D:\admin"
  # Pattern: Drive letter, double-dash, then path segments separated by single dash
  if ($Slug -match '^([A-Za-z])--(.+)$') {
    $drive = $Matches[1]
    $rest = $Matches[2] -replace '-', [IO.Path]::DirectorySeparatorChar
    return "${drive}:$([IO.Path]::DirectorySeparatorChar)$rest"
  }
  return $null
}

function Get-ClaudeCodeWindowsRecentSessions([int]$TopN) {
  $projectsDir = Join-Path $env:USERPROFILE ".claude\projects"
  $out = @()
  if (-not (Test-Path -LiteralPath $projectsDir)) { return $out }

  # Changed: *.jsonl instead of chat_*.jsonl (naming convention changed)
  # Exclude agent-*.jsonl (subagent sessions) to focus on main sessions
  $allFiles = Get-ChildItem -LiteralPath $projectsDir -Recurse -File -Filter "*.jsonl" |
    Where-Object { $_.Name -notmatch '^agent-' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First ($TopN * 6)

  $seen = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($f in $allFiles) {
    if ($out.Count -ge $TopN) { break }

    $projectSlug = Split-Path $f.DirectoryName -Leaf

    $head = $null
    try { $head = (Get-Content -LiteralPath $f.FullName -TotalCount 140 -Encoding UTF8) -join "`n" } catch {}
    $bestPath = Try-ExtractPathFromText $head

    # If no path found in content, try decoding the project slug
    if (-not $bestPath) {
      $bestPath = Decode-ClaudeProjectSlug $projectSlug
    }

    # Dedupe by project folder + hour bucket
    $key = "$projectSlug|$($f.LastWriteTime.ToString('yyyy-MM-dd HH'))"
    if ($seen.Add($key)) {
      # Extract session ID (UUID) from filename
      $sessionId = if ($f.BaseName -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        $f.BaseName
      } else { $null }

      $out += [pscustomobject]@{
        Tool        = "Claude Code (Windows)"
        When        = $f.LastWriteTime
        ProjectPath = $bestPath
        Project     = $projectSlug
        SessionId   = $sessionId
      }
    }
  }

  $out | Sort-Object When -Descending | Select-Object -First $TopN
}

function Get-WSLDistros {
  # wsl.exe -l -q outputs UTF-16LE with null bytes between chars
  # We need to strip those out to get clean distro names
  $raw = & wsl.exe -l -q 2>$null
  if (-not $raw) { return @() }

  # Join array, remove null chars, split on newlines, trim, filter empties
  $joined = ($raw -join "`n") -replace "`0", ""
  $distros = $joined -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch 'docker-desktop' }
  return @($distros)
}

function Get-ClaudeCodeWSLRecentSessions([int]$TopN) {
  $out = @()

  # List distros (with proper UTF-16LE handling)
  $distros = Get-WSLDistros
  if ($distros.Count -eq 0) { return $out }

  foreach ($d in $distros) {
    $limit = [Math]::Max(10, $TopN * 6)

    # Simple bash: just get epoch, path, and first cwd line - process in PowerShell
    $lines = @()
    try {
      $lines = & wsl.exe -d $d -e bash -c "find ~/.claude/projects -type f -name '*.jsonl' ! -name 'agent-*.jsonl' -printf '%T@\t%p\n' 2>/dev/null | sort -nr | head -n $limit" 2>$null
    } catch {
      continue
    }

    $seen = New-Object "System.Collections.Generic.HashSet[string]"
    foreach ($ln in $lines) {
      if (-not $ln) { continue }
      $parts = $ln -split "`t", 2
      if ($parts.Count -lt 2) { continue }

      $epoch = [double]$parts[0]
      $fp = $parts[1]

      $projSlug = Split-Path (Split-Path $fp -Parent) -Leaf
      $fname = Split-Path $fp -Leaf

      # Try to extract path from first 100 lines of file
      $path = $null
      try {
        # Use simple grep to find cwd line, then parse in PowerShell
        $cwdLine = & wsl.exe -d $d -e bash -c "head -n 100 '$fp' 2>/dev/null | grep -o 'cwd.*' | head -1" 2>$null
        # Match cwd":"path" (grep output starts mid-json)
        if ($cwdLine -match 'cwd"\s*:\s*"([^"]+)"') {
          $path = $Matches[1]
        }
      } catch {}

      # Decode WSL path slug if no path extracted (e.g., -home-wsladmin-dev-foo -> /home/wsladmin/dev/foo)
      if (-not $path -and $projSlug -match '^-') {
        $path = $projSlug -replace '^-', '/' -replace '-', '/'
      }

      # Dedupe by project folder + hour bucket
      $when = (Get-Date "1970-01-01Z").ToUniversalTime().AddSeconds([Math]::Floor($epoch)).ToLocalTime()
      $key = "$projSlug|$($when.ToString('yyyy-MM-dd HH'))"
      if (-not $seen.Add($key)) { continue }

      # Extract session ID (UUID) from filename
      $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fname)
      $sessionId = if ($baseName -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        $baseName
      } else { $null }

      $out += [pscustomobject]@{
        Tool        = "Claude Code (WSL:$d)"
        When        = $when
        ProjectPath = $path
        Project     = $projSlug
        SessionId   = $sessionId
      }

      if ($out.Count -ge $TopN) { break }
    }
    if ($out.Count -ge $TopN) { break }
  }

  $out | Sort-Object When -Descending | Select-Object -First $TopN
}

function Get-ClaudeDesktopWindowsRecentSessions([int]$TopN) {
  # Claude Desktop stores data under %APPDATA%\Claude
  $out = @()
  $roots = @(
    (Join-Path $env:APPDATA "Claude"),
    (Join-Path $env:LOCALAPPDATA "Claude"),
    (Join-Path $env:LOCALAPPDATA "Anthropic"),
    (Join-Path $env:APPDATA "Anthropic")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

  $candidates = @()
  foreach ($r in $roots) {
    try {
      # Look for DB / JSON / log artifacts that could represent sessions
      $candidates += Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
          $_.Name -match '(?i)(chat|conversation|transcript|history|session|messages)' -and
          $_.Extension -match '(?i)\.(json|jsonl|txt|log|sqlite|db)$'
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First ($TopN * 2)
    } catch {}
  }

  $seen = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($f in ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First $TopN)) {
    $key = "$($f.DirectoryName)|$($f.LastWriteTime.ToString('yyyy-MM-dd HH'))"
    if ($seen.Add($key)) {
      $out += [pscustomobject]@{
        Tool        = "Claude Desktop"
        When        = $f.LastWriteTime
        ProjectPath = $null
        Project     = (Split-Path $f.DirectoryName -Leaf)
        SessionId   = $f.BaseName
      }
    }
  }
  $out
}

function Get-OpenCodeWindowsRecentSessions([int]$TopN) {
  $root   = Join-Path $env:USERPROFILE ".local\share\opencode"
  $logDir = Join-Path $root "log"
  $out = @()

  if (-not (Test-Path -LiteralPath $logDir)) { return $out }

  $logs = Get-ChildItem -LiteralPath $logDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 15

  # Dedupe by (log file + directory) to avoid duplicate rows
  $seen = New-Object "System.Collections.Generic.HashSet[string]"

  foreach ($lf in $logs) {
    if ($out.Count -ge $TopN) { break }

    $content = $null
    try { $content = Get-Content -LiteralPath $lf.FullName -Raw -Encoding UTF8 } catch {}
    if (-not $content) { continue }

    $matches = [regex]::Matches($content, '(?i)\bdirectory=([A-Za-z]:\\[^ \r\n"]+)')

    # Collect unique directories from this log file
    $dirsInLog = @()
    foreach ($m in ($matches | Select-Object -Last 10)) {
      $dir = $m.Groups[1].Value
      $key = "$($lf.Name)|$dir"
      if ($seen.Add($key)) {
        $dirsInLog += $dir
      }
    }

    # Multiple dirs in same log = Desktop, single = CLI
    $toolType = if ($dirsInLog.Count -gt 1) { "OpenCode Desktop" } else { "OpenCode CLI" }

    # Extract session ID from log filename (e.g., 2026-01-23T021016 from 2026-01-23T021016.log)
    $sessionId = $lf.BaseName

    foreach ($dir in $dirsInLog) {
      if ($out.Count -ge $TopN) { break }

      $out += [pscustomobject]@{
        Tool        = $toolType
        When        = $lf.LastWriteTime
        ProjectPath = $dir
        Project     = $null
        SessionId   = $sessionId
      }
    }
  }

  $out | Sort-Object When -Descending | Select-Object -First $TopN
}

function Get-OpenCodeWSLRecentSessions([int]$TopN) {
  $out = @()

  $distros = Get-WSLDistros
  if ($distros.Count -eq 0) { return $out }

  foreach ($d in $distros) {
    # Simple bash: get log files with timestamps
    $logLines = @()
    try {
      $logLines = & wsl.exe -d $d -e bash -c "find ~/.local/share/opencode/log -type f -name '*.log' -printf '%T@\t%p\n' 2>/dev/null | sort -nr | head -n 15" 2>$null
    } catch {
      continue
    }

    $seen = New-Object "System.Collections.Generic.HashSet[string]"
    foreach ($logLn in $logLines) {
      if (-not $logLn) { continue }
      $parts = $logLn -split "`t", 2
      if ($parts.Count -lt 2) { continue }

      $epoch = [double]$parts[0]
      $fp = $parts[1]
      $fname = Split-Path $fp -Leaf

      # Extract directory= paths from log file
      $dirLines = @()
      try {
        $dirLines = & wsl.exe -d $d -e bash -c "grep -oE 'directory=(/[^ ]+)' '$fp' 2>/dev/null | sed 's/directory=//' | sort -u | tail -10" 2>$null
      } catch {
        continue
      }

      # Collect unique directories from this log file
      $dirsInLog = @()
      foreach ($dir in $dirLines) {
        if (-not $dir) { continue }
        $dir = $dir.Trim()
        $key = "$fname|$dir"
        if ($seen.Add($key)) {
          $dirsInLog += $dir
        }
      }

      # Multiple dirs in same log = Desktop, single = CLI
      $toolType = if ($dirsInLog.Count -gt 1) { "OpenCode Desktop (WSL:$d)" } else { "OpenCode CLI (WSL:$d)" }

      $when = (Get-Date "1970-01-01Z").ToUniversalTime().AddSeconds([Math]::Floor($epoch)).ToLocalTime()

      # Extract session ID from log filename
      $sessionId = [System.IO.Path]::GetFileNameWithoutExtension($fname)

      foreach ($dir in $dirsInLog) {
        if ($out.Count -ge $TopN) { break }

        $out += [pscustomobject]@{
          Tool        = $toolType
          When        = $when
          ProjectPath = $dir
          Project     = $null
          SessionId   = $sessionId
        }
      }
      if ($out.Count -ge $TopN) { break }
    }
    if ($out.Count -ge $TopN) { break }
  }

  $out | Sort-Object When -Descending | Select-Object -First $TopN
}

# ---- Run ----
$claudeWin    = Get-ClaudeCodeWindowsRecentSessions -TopN $Top
$claudeWsl    = Get-ClaudeCodeWSLRecentSessions -TopN $Top
$claudeDesk   = Get-ClaudeDesktopWindowsRecentSessions -TopN ([Math]::Min(8, $Top))
$opencodeWin  = Get-OpenCodeWindowsRecentSessions -TopN $Top
$opencodeWsl  = Get-OpenCodeWSLRecentSessions -TopN $Top

$all = @($claudeWin + $claudeWsl + $claudeDesk + $opencodeWin + $opencodeWsl) | Sort-Object When -Descending | Select-Object -First $Top

if (-not $all -or $all.Count -eq 0) {
  Write-Host "No session artifacts found in expected default locations."
  Write-Host ""
  Write-Host "Expected locations:"
  Write-Host "  Claude Code (Windows): $env:USERPROFILE\.claude\projects\*\*.jsonl"
  Write-Host "  Claude Code (WSL):     ~/.claude/projects/*/*.jsonl (inside each distro)"
  Write-Host "  Claude Desktop:        $env:APPDATA\Claude"
  Write-Host "  OpenCode (Windows):    $env:USERPROFILE\.local\share\opencode\log"
  Write-Host "  OpenCode (WSL):        ~/.local/share/opencode/log (inside each distro)"
  exit 0
}

# Output: CSV file or console table
if ($Csv -or $File) {
  # Determine output path
  $outPath = $File
  if ([string]::IsNullOrWhiteSpace($outPath)) {
    # Default location: ~/.admin/logs/session-scout-YYYY-MM-DD.csv
    $defaultDir = Join-Path $env:USERPROFILE ".admin\logs"
    if (-not (Test-Path -LiteralPath $defaultDir)) {
      New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
    }
    $timestamp = (Get-Date).ToString('yyyy-MM-dd')
    $outPath = Join-Path $defaultDir "session-scout-$timestamp.csv"
  }

  $all |
    Select-Object Tool, When, ProjectPath, Project, SessionId |
    Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8

  Write-Host "Wrote $($all.Count) sessions to: $outPath"
} else {
  $all |
    Select-Object Tool, When, ProjectPath, Project, SessionId |
    Format-Table -AutoSize

  Write-Host ""
  Write-Host "Quick checks if sessions are missing:"
  Write-Host "  Windows Claude Code:  dir `$env:USERPROFILE\.claude\projects -Recurse -Filter *.jsonl | measure"
  Write-Host "  WSL Claude Code:      wsl -e bash -lc 'find ~/.claude/projects -name *.jsonl 2>/dev/null | wc -l'"
}
