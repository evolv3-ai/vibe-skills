# Admin Routing Guide

> **Routing authority lives in `skills/admin/SKILL.md`** (the "Task Qualification" and
> "Task Routing" tables). This file covers only the mechanics that run *before* routing:
> environment detection and the admin-environment check. The current model is two skills —
> **admin** (local machine) and **devops** (remote servers/cloud).

## Contents
- Environment Detection (Run First)
- Admin Environment Check
- Handoff Protocol

---

## Environment Detection (Run First)

Before any routing logic, detect the execution environment — it sets `$ADMIN_ROOT`:

```bash
if grep -qi microsoft /proc/version 2>/dev/null; then
    ENV="wsl"
    ADMIN_ROOT="/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/.admin"
elif [[ "$OS" == "Windows_NT" || -n "$MSYSTEM" ]]; then
    ENV="windows-gitbash"
    ADMIN_ROOT="$HOME/.admin"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    ENV="macos"
    ADMIN_ROOT="$HOME/.admin"
else
    ENV="linux"
    ADMIN_ROOT="$HOME/.admin"
fi
echo "Detected: ENV=$ENV, ADMIN_ROOT=$ADMIN_ROOT"
```

| Session Started From | ENV | Key Indicator | ADMIN_ROOT example |
|---------------------|-----|---------------|--------------------|
| WSL terminal | `wsl` | `/proc/version` has "microsoft" | `/mnt/c/Users/Owner/.admin` |
| Windows (PowerShell/CMD/Terminal) | `windows-gitbash` | `$OS=Windows_NT` | `/c/Users/Owner/.admin` |
| Native Linux | `linux` | no Microsoft, no `Windows_NT` | `/home/user/.admin` |
| macOS | `macos` | `uname -s` = "Darwin" | `/Users/user/.admin` |

**Shell rules**: Claude Code runs bash even on Windows (Git Bash/MINGW). To run PowerShell,
invoke `pwsh.exe -Command "..."` rather than emitting PowerShell syntax directly. `/mnt/c/`
paths only resolve in WSL; in Git Bash use `C:/` or `/c/`. (Full shell vs platform model:
`references/shell-detection.md`.)

---

## Admin Environment Check

After detecting the environment, confirm the admin environment exists before routing:

1. `$ADMIN_ROOT` directory exists
2. `$ADMIN_ROOT/.env` exists
3. `$ADMIN_ROOT/logs/` exists
4. `$ADMIN_ROOT/profiles/` exists

If any check fails, run the setup flow in `references/profile-gate.md` (detect platform →
create directory structure → generate `.env` → create device profile). Do this first:
logging and profile history depend on `logs/` and `profiles/`, and sub-skills read
`$ADMIN_ROOT/.env`, so late setup runs tasks without proper state.

---

## Handoff Protocol

When a task needs a different context (e.g. a Windows-only operation while you're in WSL):

1. **Log it**:
   ```bash
   log_admin_event "HANDOFF: task requires $target_context (current=$ENV)" "WARN"
   ```
2. **Give a concrete next step**: "Open Windows Terminal / PowerShell", or "Run `wsl -d Ubuntu-24.04`".
3. **Tag for tracking**: `[REQUIRES-WINADMIN]` (must run on the Windows side) or
   `[REQUIRES-WSL-ADMIN]` (must run inside WSL).

For *remote* server/cloud work, hand off to the **devops** skill (it works from any context).
