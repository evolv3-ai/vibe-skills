# PowerShell Commands Reference

Quick reference for PowerShell equivalents of common Bash commands used in admin skills.

## Contents
- Directory Operations
- File Operations
- Environment Variables
- String Operations
- Path Construction
- Conditionals
- Loops
- Command Output Capture
- JSON Operations
- Date/Time
- Process Management
- Network
- Admin-Specific Commands
- Related Files

---

## Directory Operations

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Create directory | `mkdir -p path` | `New-Item -ItemType Directory -Force -Path path` |
| List files | `ls -la` | `Get-ChildItem` or `dir` |
| Change directory | `cd path` | `Set-Location path` or `cd path` |
| Current directory | `pwd` | `Get-Location` or `pwd` |
| Remove directory | `rm -rf path` | `Remove-Item -Recurse -Force path` |

## File Operations

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Read file | `cat file` | `Get-Content file` |
| Read first N lines | `head -n 20 file` | `Get-Content file -Head 20` |
| Read last N lines | `tail -n 20 file` | `Get-Content file -Tail 20` |
| Write to file | `echo "text" > file` | `Set-Content file -Value "text"` |
| Append to file | `echo "text" >> file` | `Add-Content file -Value "text"` |
| Copy file | `cp src dest` | `Copy-Item src dest` |
| Move file | `mv src dest` | `Move-Item src dest` |
| Delete file | `rm file` | `Remove-Item file` |
| Check if exists | `[[ -f file ]]` | `Test-Path file` |

## Environment Variables

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Read variable | `$VAR` or `${VAR}` | `$env:VAR` |
| Set (session) | `export VAR=value` | `$env:VAR = "value"` |
| Home directory | `$HOME` | `$env:USERPROFILE` |
| Hostname | `$(hostname)` | `$env:COMPUTERNAME` |
| Username | `$USER` | `$env:USERNAME` |
| Temp directory | `$TMPDIR` or `/tmp` | `$env:TEMP` |

## String Operations

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Print text | `echo "text"` | `Write-Output "text"` |
| Variable in string | `"Hello $name"` | `"Hello $name"` |
| Concatenate | `"$a$b"` | `"$a$b"` or `$a + $b` |
| Substring | `${str:0:5}` | `$str.Substring(0,5)` |
| Replace | `${str//old/new}` | `$str -replace 'old','new'` |

## Path Construction

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Join paths | `"$HOME/.admin"` | `Join-Path $env:USERPROFILE '.admin'` |
| Multiple segments | `"$HOME/a/b/c"` | `Join-Path $env:USERPROFILE 'a' 'b' 'c'` |
| Path separator | `/` | `\` (use Join-Path) |

## Conditionals

**Bash:**
```bash
if [[ -f "$file" ]]; then
    echo "exists"
elif [[ -d "$dir" ]]; then
    echo "is directory"
else
    echo "not found"
fi
```

**PowerShell:**
```powershell
if (Test-Path $file -PathType Leaf) {
    Write-Output "exists"
} elseif (Test-Path $dir -PathType Container) {
    Write-Output "is directory"
} else {
    Write-Output "not found"
}
```

## Loops

**Bash:**
```bash
for item in "${array[@]}"; do
    echo "$item"
done
```

**PowerShell:**
```powershell
foreach ($item in $array) {
    Write-Output $item
}
# Or pipeline style:
$array | ForEach-Object { Write-Output $_ }
```

## Command Output Capture

**Bash:**
```bash
result=$(some_command)
```

**PowerShell:**
```powershell
$result = some_command
```

## JSON Operations

**Bash (with jq):**
```bash
# Read JSON
cat file.json | jq '.key'

# Create JSON
jq -n --arg name "$name" '{ "name": $name }' > file.json
```

**PowerShell:**
```powershell
# Read JSON
$data = Get-Content file.json | ConvertFrom-Json
$data.key

# Create JSON
@{ name = $name } | ConvertTo-Json | Set-Content file.json

# Pretty print with depth
$data | ConvertTo-Json -Depth 10 | Set-Content file.json
```

## Date/Time

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Current ISO8601 | `date -Iseconds` | `Get-Date -Format 'o'` |
| Custom format | `date +"%Y-%m-%d"` | `Get-Date -Format 'yyyy-MM-dd'` |
| Timestamp | `date +%s` | `[DateTimeOffset]::Now.ToUnixTimeSeconds()` |

## Process Management

| Operation | Bash | PowerShell |
|-----------|------|------------|
| List processes | `ps aux` | `Get-Process` |
| Kill by name | `pkill name` | `Stop-Process -Name name` |
| Kill by PID | `kill PID` | `Stop-Process -Id PID` |
| Background job | `command &` | `Start-Job { command }` |

## Network

| Operation | Bash | PowerShell |
|-----------|------|------------|
| Download file | `curl -O url` | `Invoke-WebRequest url -OutFile file` |
| HTTP GET | `curl url` | `Invoke-RestMethod url` |
| Check port | `nc -z host port` | `Test-NetConnection host -Port port` |

## Admin-Specific Commands

### Logging Function

**Bash:**
```bash
log_admin() {
    local level="$1" message="$2"
    echo "[$(date -Iseconds)] [$level] $message" >> "$HOME/.admin/logs/operations.log"
}
```

**PowerShell:**
```powershell
function Write-AdminLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'o'
    $logPath = Join-Path $env:USERPROFILE '.admin\logs\operations.log'
    Add-Content $logPath -Value "[$timestamp] [$Level] $Message"
}
```

### Profile Creation

**Bash:**
```bash
cat > "$HOME/.admin/profiles/$(hostname).json" << EOF
{
    "deviceInfo": {
        "name": "$(hostname)",
        "platform": "wsl",
        "user": "$USER",
        "lastUpdated": "$(date -Iseconds)"
    }
}
EOF
```

**PowerShell:**
```powershell
$profile = @{
    deviceInfo = @{
        name = $env:COMPUTERNAME
        platform = 'windows'
        user = $env:USERNAME
        lastUpdated = (Get-Date -Format 'o')
    }
}
$profilePath = Join-Path $env:USERPROFILE ".admin\profiles\$env:COMPUTERNAME.json"
$profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath
```

## Related Files

- `admin/SKILL.md` - Main skill with dual-mode commands
- `admin/references/shell-detection.md` - How shell detection works
- `admin/references/first-run-setup.md` - First-run setup guide
