#Requires -Version 5.1
<#
.SYNOPSIS
    Logs an admin event to the operations log
.DESCRIPTION
    Appends a timestamped, structured log entry to $ADMIN_ROOT/logs/$LogFile.
    Format: [ISO8601] [DEVICE] [PLATFORM] [LEVEL] Message
.PARAMETER Message
    The log message to record
.PARAMETER Level
    Log level: INFO, WARN, ERROR, OK (default: INFO)
.PARAMETER LogFile
    Target log file name (default: operations.log)
.EXAMPLE
    Log-AdminEvent "Installed node v22"
.EXAMPLE
    Log-AdminEvent "MCP server failed to start" -Level ERROR
.EXAMPLE
    Log-AdminEvent "Backup completed" -Level OK -LogFile backups.log
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Message,

    [ValidateSet("INFO", "WARN", "ERROR", "OK")]
    [string]$Level = "INFO",

    [string]$LogFile = "operations.log"
)

function Log-AdminEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "OK")]
        [string]$Level = "INFO",

        [string]$LogFile = "operations.log"
    )

    # Resolve ADMIN_ROOT
    $AdminRoot = $env:ADMIN_ROOT
    if (-not $AdminRoot) {
        $AdminRoot = Join-Path $HOME ".admin"
    }

    # Ensure logs directory exists
    $LogsDir = Join-Path $AdminRoot "logs"
    if (-not (Test-Path $LogsDir)) {
        $null = New-Item -ItemType Directory -Path $LogsDir -Force
    }

    # Get device info
    $DeviceName = $env:COMPUTERNAME
    $Platform = "windows"

    # Format timestamp as ISO8601
    $Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    # Build log entry
    $LogEntry = "[$Timestamp] [$DeviceName] [$Platform] [$Level] $Message"

    # Append to log file
    $LogPath = Join-Path $LogsDir $LogFile
    Add-Content -Path $LogPath -Value $LogEntry -Encoding UTF8

    # Return the entry for confirmation
    return $LogEntry
}

# If script is run directly with parameters, execute the function
if ($Message) {
    $result = Log-AdminEvent -Message $Message -Level $Level -LogFile $LogFile
    Write-Host $result -ForegroundColor $(switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Cyan" }
    })
}
