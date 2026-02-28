# Admin Correction Rules

Rules to correct common cross-platform CLI mistakes in Claude Code.

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

## MCP HTTP Session Init Protocol (ISSUE-0008)

WRONG - Calling MCP tools directly without session initialization:
```bash
curl -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"memory_query","arguments":{"query":"test"}},"id":1}'
# Fails: server returns "Session not initialized" or similar error
```

RIGHT - Initialize session first, then use the returned Mcp-Session-Id:
```bash
# Step 1: Initialize and capture session ID
SESSION_ID=$(curl -s -D - -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"cli","version":"1.0"}},"id":1}' \
  | grep -i 'mcp-session-id' | awk '{print $2}' | tr -d '\r')

# Step 2: Call tools with session ID
curl -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"memory_query","arguments":{"query":"test"}},"id":2}'
```

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
