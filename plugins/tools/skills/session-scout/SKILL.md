---
name: session-scout
description: |
  Discover and list recent AI coding sessions across Claude Code, Claude Desktop, and OpenCode on Windows, macOS, and Linux. Scripts extract project paths, session IDs, and timestamps from session artifacts. PowerShell for Windows, Bash for macOS/Linux.

  Use when: finding recent coding sessions, reviewing AI session history, exporting session logs to CSV, troubleshooting missing sessions, or auditing Claude Code/OpenCode usage across environments.
---

# Session Scout

**Status**: Production Ready
**Last Updated**: 2026-02-13
**Dependencies**: PowerShell 7+ (Windows) or Bash 4+ (macOS/Linux)

---

## Quick Start (1 Minute)

### 1. Run the Script

**macOS / Linux:**
```bash
# Show recent sessions (default: top 12)
~/.claude/skills/session-scout/scripts/session-scout.sh

# Show more sessions
~/.claude/skills/session-scout/scripts/session-scout.sh --top 20
```

**Windows (PowerShell):**
```powershell
# Show recent sessions (default: top 12)
pwsh -ExecutionPolicy Bypass -File ~/.claude/skills/session-scout/scripts/Session-Scout.ps1

# Show more sessions
pwsh -ExecutionPolicy Bypass -File ~/.claude/skills/session-scout/scripts/Session-Scout.ps1 -Top 20
```

**Output columns:**
- **Tool** - Claude Code (Windows/WSL), Claude Desktop, OpenCode CLI/Desktop
- **When** - Last activity timestamp
- **ProjectPath** - Working directory path
- **Project** - Project slug/identifier
- **SessionId** - UUID (Claude Code) or timestamp (OpenCode)

### 2. Export to CSV

**macOS / Linux:**
```bash
# Export to default location (~/.admin/logs/session-scout-YYYY-MM-DD.csv)
~/.claude/skills/session-scout/scripts/session-scout.sh --csv

# Export to custom path
~/.claude/skills/session-scout/scripts/session-scout.sh --file ~/exports/sessions.csv
```

**Windows (PowerShell):**
```powershell
# Export to default location (~/.admin/logs/session-scout-YYYY-MM-DD.csv)
pwsh -ExecutionPolicy Bypass -File ~/.claude/skills/session-scout/scripts/Session-Scout.ps1 -Csv

# Export to custom path
pwsh -ExecutionPolicy Bypass -File ~/.claude/skills/session-scout/scripts/Session-Scout.ps1 -File "D:\exports\sessions.csv"
```

---

## What It Discovers

### Claude Code Sessions
- **Windows**: `%USERPROFILE%\.claude\projects\*\*.jsonl`
- **WSL/Linux**: `~/.claude/projects/*/*.jsonl`
- **macOS**: `~/.claude/projects/*/*.jsonl`
- Extracts: cwd, project slug, session UUID

### Claude Desktop Sessions
- **Windows**: `%APPDATA%\Claude` and `%LOCALAPPDATA%\Claude`
- **macOS**: `~/Library/Application Support/Claude/` and `~/Library/Application Support/Anthropic/`
- **Linux**: `~/.config/Claude/` and `~/.config/Anthropic/`
- Looks for: chat, conversation, transcript, history files

### OpenCode Sessions
- **Windows**: `%USERPROFILE%\.local\share\opencode\log\*.log`
- **macOS/Linux**: `~/.local/share/opencode/log/*.log`
- Differentiates: Desktop (multiple dirs) vs CLI (single dir)

---

## Critical Rules

### Always Do

- **Windows**: Run with `pwsh` (PowerShell 7+), not Windows PowerShell 5.1
- **Windows**: Use `-ExecutionPolicy Bypass` when running directly
- **macOS/Linux**: Use `session-scout.sh` (requires Bash 4+ for associative arrays)
- Check WSL is running if WSL sessions are missing (Windows only)

### Never Do

- Don't modify session `.jsonl` files directly
- Don't assume all sessions have extractable paths (some may show empty)
- Don't run the PowerShell script from inside WSL (use the Bash script instead)

---

## Known Issues Prevention

This skill prevents **3** documented issues:

### Issue #1: UUID-based Filenames Not Found
**Error**: No sessions found despite active Claude Code usage
**Why It Happens**: Claude Code changed from `chat_*.jsonl` to UUID-based filenames
**Prevention**: Script uses `*.jsonl` pattern (excluding `agent-*.jsonl`)

### Issue #2: WSL Distro Names with Null Bytes
**Error**: WSL sessions not detected, distro names show as `U b u n t u`
**Why It Happens**: `wsl.exe -l -q` outputs UTF-16LE with null bytes
**Prevention**: `Get-WSLDistros` function strips null bytes properly

### Issue #3: OpenCode Desktop vs CLI Confusion
**Error**: All OpenCode sessions showing as same type
**Why It Happens**: Desktop opens multiple projects, CLI opens one
**Prevention**: Script detects pattern - multiple dirs = Desktop, single = CLI

---

## Parameters Reference

**PowerShell (Session-Scout.ps1):**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Top` | int | 12 | Maximum sessions to display |
| `-Csv` | switch | - | Export to default path: `~/.admin/logs/session-scout-YYYY-MM-DD.csv` |
| `-File` | string | - | Export to specified CSV path |

**Bash (session-scout.sh):**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--top`, `-t` | int | 12 | Maximum sessions to display |
| `--csv` | flag | - | Export to default path: `~/.admin/logs/session-scout-YYYY-MM-DD.csv` |
| `--file`, `-f` | string | - | Export to specified CSV path |

---

## Session Storage Locations

```
Claude Code (Windows):
  %USERPROFILE%\.claude\projects\{project-slug}\{uuid}.jsonl

Claude Code (macOS/Linux):
  ~/.claude/projects/{project-slug}/{uuid}.jsonl

Claude Desktop (Windows):
  %APPDATA%\Claude\
  %LOCALAPPDATA%\Claude\

Claude Desktop (macOS):
  ~/Library/Application Support/Claude/
  ~/Library/Application Support/Anthropic/

Claude Desktop (Linux):
  ~/.config/Claude/
  ~/.config/Anthropic/

OpenCode (Windows):
  %USERPROFILE%\.local\share\opencode\log\{timestamp}.log

OpenCode (macOS/Linux):
  ~/.local/share/opencode/log/{timestamp}.log
```

---

## Troubleshooting

### Problem: No sessions found
**Solution**: Check expected locations manually:
```bash
# macOS / Linux
find ~/.claude/projects -name '*.jsonl' 2>/dev/null | wc -l
```
```powershell
# Windows
dir $env:USERPROFILE\.claude\projects -Recurse -Filter *.jsonl | measure
```

### Problem: WSL sessions not appearing (Windows only)
**Solution**: Ensure WSL is running and distros are accessible:
```powershell
wsl -l -q
```

### Problem: ProjectPath shows as empty
**Solution**: Path extraction is best-effort. The session file may not contain a cwd field in the first 100 lines.

---

## Example Output

```
Tool                            When                 ProjectPath                    Project              SessionId
----                            ----                 -----------                    -------              ---------
Claude Code (Windows)           1/26/2026 5:39:03 PM D:\admin                       D--admin             bdeb38c1-98a8-...
Claude Code (WSL:Ubuntu-24.04)  1/26/2026 1:47:28 PM /home/wsladmin/dev/vibe-skills -home-wsladmin-dev-v 3cd316dc-c168-...
OpenCode CLI                    1/26/2026 5:30:37 PM D:\rlm-project                                      2026-01-26T203036
OpenCode Desktop                1/26/2026 1:53:00 PM D:\wireframe-kit                                    2026-01-26T190547
Claude Desktop                  1/26/2026 10:10:18 AM                               sentry               session
```

---

## Complete Setup Checklist

**macOS / Linux:**
- [ ] Bash 4+ installed (`bash --version`)
- [ ] Script is executable (`chmod +x session-scout.sh`)
- [ ] At least one Claude Code/OpenCode session exists to test

**Windows:**
- [ ] PowerShell 7+ installed (`pwsh --version`)
- [ ] WSL2 installed (for WSL session discovery)
- [ ] At least one Claude Code/OpenCode session exists to test
