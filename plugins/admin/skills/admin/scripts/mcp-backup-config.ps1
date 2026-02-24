# backup-config.ps1
# Backup Claude Desktop configuration with rotation
# Usage: .\scripts\backup-config.ps1 [-RetainCount 10] [-List] [-Restore]

param(
    [int]$RetainCount = 10,
    [switch]$List,
    [switch]$Restore,
    [string]$RestoreFile
)

# Configuration
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$backupDir = "$env:APPDATA\Claude\backups"

Write-Host "`n=== Claude Desktop Config Backup ===" -ForegroundColor Cyan

# Ensure backup directory exists
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Created backup directory: $backupDir" -ForegroundColor Green
}

# List existing backups
if ($List) {
    Write-Host "`nExisting backups:" -ForegroundColor Yellow
    $backups = Get-ChildItem "$backupDir\claude_desktop_config.*.json" | Sort-Object LastWriteTime -Descending

    if ($backups.Count -eq 0) {
        Write-Host "  No backups found" -ForegroundColor Gray
    } else {
        $i = 1
        foreach ($backup in $backups) {
            $size = [math]::Round($backup.Length / 1KB, 2)
            Write-Host "  $i. $($backup.Name) - $($backup.LastWriteTime) - ${size}KB" -ForegroundColor Gray
            $i++
        }
    }
    exit 0
}

# Restore from backup
if ($Restore) {
    $backups = Get-ChildItem "$backupDir\claude_desktop_config.*.json" | Sort-Object LastWriteTime -Descending

    if ($RestoreFile) {
        $selectedBackup = $backups | Where-Object { $_.Name -eq $RestoreFile }
    } else {
        Write-Host "`nAvailable backups:" -ForegroundColor Yellow
        $i = 1
        foreach ($backup in $backups) {
            Write-Host "  $i. $($backup.Name) - $($backup.LastWriteTime)" -ForegroundColor Gray
            $i++
        }

        $selection = Read-Host "`nEnter backup number to restore (1-$($backups.Count))"
        $selectedBackup = $backups[$selection - 1]
    }

    if (-not $selectedBackup) {
        Write-Host "ERROR: Backup not found" -ForegroundColor Red
        exit 1
    }

    # Backup current before restore
    $preRestoreBackup = "$backupDir\claude_desktop_config.pre-restore.$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item $configPath $preRestoreBackup
    Write-Host "Pre-restore backup: $preRestoreBackup" -ForegroundColor Green

    # Restore
    Copy-Item $selectedBackup.FullName $configPath
    Write-Host "Restored from: $($selectedBackup.Name)" -ForegroundColor Green

    Write-Host "`nPlease restart Claude Desktop to apply changes." -ForegroundColor Yellow
    exit 0
}

# Create new backup
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Config file not found at $configPath" -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = "$backupDir\claude_desktop_config.$timestamp.json"

Copy-Item $configPath $backupPath
Write-Host "Backup created: $backupPath" -ForegroundColor Green

# Rotate old backups
$backups = Get-ChildItem "$backupDir\claude_desktop_config.*.json" |
           Where-Object { $_.Name -notlike "*pre-restore*" } |
           Sort-Object LastWriteTime -Descending

if ($backups.Count -gt $RetainCount) {
    $toDelete = $backups | Select-Object -Skip $RetainCount

    foreach ($old in $toDelete) {
        Remove-Item $old.FullName
        Write-Host "Removed old backup: $($old.Name)" -ForegroundColor Gray
    }

    Write-Host "Retained $RetainCount most recent backups" -ForegroundColor Green
}

# Show backup summary
Write-Host "`nBackup Summary:" -ForegroundColor Cyan
$backups = Get-ChildItem "$backupDir\claude_desktop_config.*.json" | Sort-Object LastWriteTime -Descending
Write-Host "  Total backups: $($backups.Count)" -ForegroundColor Gray
Write-Host "  Latest: $($backups[0].Name)" -ForegroundColor Gray
Write-Host "  Location: $backupDir" -ForegroundColor Gray

Write-Host "`nDone!" -ForegroundColor Green
