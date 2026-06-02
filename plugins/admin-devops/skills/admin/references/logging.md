# Centralized Logging System

Unified logging across all admin operations, via the shared `log-admin-event.sh` (bash) and
`Log-AdminEvent.ps1` (PowerShell) helpers in `scripts/`.

## Log Files

Entries are appended under `$ADMIN_ROOT/logs/<file>`. The default file is `operations.log`;
pass a different file name (3rd bash arg / `-LogFile`) to route an entry:

| Log file | Purpose |
|----------|---------|
| `operations.log` (default) | General operations |
| `installations.log` | Software installs/updates |
| `system-changes.log` | Config/PATH/registry changes |
| `handoffs.log` | Cross-platform handoffs |

## Log Entry Format

```
[ISO8601] [DEVICE] [PLATFORM] [LEVEL] message
```

Example:
```
[2026-06-01T14:30:15-05:00] [DELTABOT] [wsl] [OK] Installed git via apt
[2026-06-01T14:31:00-05:00] [DELTABOT] [windows] [ERROR] Python installation failed
```

**Levels**: `INFO` (default), `WARN`, `ERROR`, `OK`. The device name and platform are filled
in automatically by the helper (from the satellite `.env` / detection).

## Bash (WSL / Linux / macOS)

```bash
source scripts/log-admin-event.sh
log_admin_event "Installed ripgrep via apt"                 # level defaults to INFO
log_admin_event "MCP server failed to start" "ERROR"
log_admin_event "Installed git 2.47 via apt" "OK" "installations.log"
```

Signature: `log_admin_event MESSAGE [LEVEL] [LOGFILE]`.

## PowerShell (Windows)

```powershell
pwsh -NoProfile -File "scripts/Log-AdminEvent.ps1" -Message "Installed git via winget" -Level OK
pwsh -NoProfile -File "scripts/Log-AdminEvent.ps1" -Message "Updated PATH in registry" -Level OK -LogFile system-changes.log
```

Or dot-source and call `Log-AdminEvent -Message <m> [-Level <INFO|WARN|ERROR|OK>] [-LogFile <file>]`.

**Note**: the helper takes only `-Message`, `-Level`, and `-LogFile` (bash: message, level,
log-file). There are no `-Tool`/`-Action`/`-Status`/`-Details`/category parameters — encode any
such detail in the message string.

## Conventions

- Log every operation; route installs/changes/handoffs to their matching log file.
- Be specific: include version numbers, file paths, and command details in the message.
- Use the correct level (`OK` completed, `ERROR` failed, `WARN` needs attention).
- Logs are append-only.
