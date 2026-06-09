# Platform CLI Correction Rules

Cross-platform CLI mistakes that occur regardless of which skill you're operating in. Importable by other skills that need bash/PowerShell/Windows-Linux interop guidance.

## JSON in curl on Windows (ISSUE-0007)

WRONG - Inline JSON with curl in PowerShell (escaping nightmare):
```powershell
curl -X POST https://api.example.com/endpoint `
  -H "Content-Type: application/json" `
  -d '{"key": "value", "nested": {"a": 1}}'
# Fails: single quotes not supported in PowerShell, backslash escaping breaks
```

RIGHT - Write a .ps1 script with ConvertTo-Json:
```powershell
# api-call.ps1
$body = @{
    key = "value"
    nested = @{ a = 1 }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "https://api.example.com/endpoint" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```
Then run: `pwsh -NoProfile -File api-call.ps1`

## PowerShell Inline in Bash Tool (ISSUE-0009)

WRONG - Complex PowerShell commands inline via pwsh -Command:
```bash
pwsh -Command "Get-ChildItem -Path 'C:\Users' | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } | ForEach-Object { Write-Host \"$($_.Name) - $($_.Length)\" }"
# Fails: nested quotes, dollar signs, and escaping break across shell boundaries
```

RIGHT - Write a .ps1 file first, then execute it:
```bash
# Write the script
cat > /tmp/task.ps1 << 'PSEOF'
Get-ChildItem -Path 'C:\Users' |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
    ForEach-Object { Write-Host "$($_.Name) - $($_.Length)" }
PSEOF

# Run it
pwsh -NoProfile -File /tmp/task.ps1
```

Simple one-liners are fine inline: `pwsh -Command "Get-Date"`
The threshold: if it has **nested quotes, pipes, or variable expansion**, write a .ps1 file.

## `del` Does Not Exist in Bash (ISSUE-0010)

WRONG - Using `del` to delete files (Windows cmd.exe habit):
```bash
del /tmp/old-file.txt
# Fails: "del: command not found" — Bash tool runs bash, not cmd.exe
```

RIGHT - Use `rm` in Bash:
```bash
rm /tmp/old-file.txt
rm -f /tmp/old-file.txt    # suppress "no such file" errors
rm -rf /tmp/old-dir/       # recursive directory removal
```

Other Windows-to-Bash command translations:
| Windows (cmd/PS) | Bash equivalent |
|-------------------|-----------------|
| `del` / `Remove-Item` | `rm` |
| `copy` / `Copy-Item` | `cp` |
| `move` / `Move-Item` | `mv` |
| `dir` / `Get-ChildItem` | `ls` |
| `type` / `Get-Content` | `cat` |
| `cls` / `Clear-Host` | `clear` |

## PowerShell Parameter Names (Bonus)

WRONG - Using hallucinated parameters:
```powershell
Log-AdminEvent -Message "Installed git" -Tool "winget" -Action "install" -Details "v2.43"
# Fails: -Tool, -Action, -Details do not exist on Log-AdminEvent
```

RIGHT - Only use documented parameters:
```powershell
Log-AdminEvent -Message "Installed git via winget v2.43" -Level "INFO"
# Only -Message and -Level are valid parameters
```

Always check function signatures with `Get-Help <CmdletName> -Parameter *` before using unfamiliar parameters.

## grep/pipefail Crash on Optional Config Vars (GitHub #22, #23)

WRONG - Reading optional vars with `grep` under `set -eo pipefail`:
```bash
set -eo pipefail
VALUE=$(grep "^OPTIONAL_KEY=" "$ENV_FILE" | head -1 | cut -d'=' -f2-)
# Crashes: grep exits 1 when key is missing; pipefail propagates it and set -e kills the script.
# Appears as an unexplained crash — the script "dies for no reason" when a var is simply absent.
```

RIGHT - Add `|| true` to grep calls for optional vars:
```bash
set -eo pipefail
VALUE=$(grep "^OPTIONAL_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- || true)
```

Also: when creating a config file read by another script via grep+pipefail, include ALL keys the reader expects — even empty-value optional ones. Missing keys cause grep to exit 1 and crash the reader.

## Dead File References in Bash Conditional Blocks (GitHub #13)

WRONG - Referencing a script file that doesn't exist in an `if [[ -f ]]` block:
```bash
local setup_script="${SCRIPT_DIR}/setup-interview.sh"
if [[ -f "$setup_script" ]]; then
    bash "$setup_script"
else
    echo -e "${RED}[ERROR]${NC} Setup script not found: $setup_script"
    return 1
fi
# Fails silently: the file doesn't exist, so every run hits the error branch.
# No parse error, no warning — just a runtime "failure" that's actually a stale reference.
```

RIGHT - Reference only files that actually exist, or provide a useful non-error fallback:
```bash
if [[ -f "${SCRIPT_DIR}/setup-interview.sh" ]]; then
    bash "${SCRIPT_DIR}/setup-interview.sh"
else
    echo -e "${CYAN}[INFO]${NC} No profile found. Run /setup-profile to create one."
    return 0
fi
```

Verify every file path in a conditional block actually exists on disk before committing. Dead path references aren't caught by bash syntax checks — only runtime testing reveals them.

## Script Permissions in WSL/Git (GitHub #18)

WRONG - Committing a script without execute permission:
```bash
# File committed as mode 644 (WSL default for new files)
./scripts/load-profile.sh
# Fails: Permission denied — the file is not executable
```

RIGHT - Always `chmod +x` before committing any script:
```bash
chmod +x scripts/*.sh scripts/*.ps1
git add scripts/
git commit -m "fix: ensure all scripts are executable"
```

Git preserves file modes from the committer's filesystem. WSL defaults new files to `644`. Verify before every commit:
```bash
find scripts/ -type f \( -name "*.sh" -o -name "*.ps1" \) ! -perm /111
# Any output means a non-executable script — run chmod +x on each
```
