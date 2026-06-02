---
name: update
description: Update installed tools/packages using profile preferences — a single app, everything, or all packages for one manager (scoop/winget/apt/brew/choco)
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - Task
argument-hint: "[tool-name | --all | --scoop | --winget | --apt | --brew | --choco | --npm]"
---

# /update Command

Update already-installed software to newer versions using the user's preferred package
manager. Mirrors `/install`, but upgrades rather than installs. Three scopes:

- **Single app** — `/update <tool>` (e.g. `/update node`)
- **All apps** — `/update --all` (every detected manager)
- **All of one manager** — `/update --scoop | --winget | --apt | --brew | --choco | --npm`

Uses the same **subagent pipeline** as `/install`: tool-installer → verify-agent → docs-agent.

## Pipeline Overview

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  /update     │ ──→ │ tool-installer│ ──→ │verify-agent│ ──→ docs-agent (log)
│  (this cmd)  │     │  (upgrade)   │     │ (verify)   │
└─────────────┘     └──────────────┘     └────────────┘
   Profile gate        memory_query →       Store results
   + scope prompt      Run upgrade          to SimpleMem
                       commands
```

## Step 1: Profile Gate

Load the profile to get user preferences. **HALT if no profile exists.**

**Bash (WSL/Linux/macOS):**
```bash
result=$("${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh")
if [[ $(echo "$result" | jq -r '.exists') != "true" ]]; then
    echo "No profile found. Run /setup-profile first."
    exit 1
fi
```

**PowerShell (Windows):**
```powershell
$result = pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/Test-AdminProfile.ps1" | ConvertFrom-Json
if (-not $result.exists) {
    Write-Host "No profile found. Run /setup-profile first."
    exit 1
}
```

## Step 2: Determine Update Scope

Parse the argument:

| Argument | Scope |
|----------|-------|
| `<tool-name>` | Update that single package via the manager that owns it |
| `--all` | Update everything across every package manager present on this machine |
| `--scoop` / `--winget` / `--choco` / `--apt` / `--brew` / `--npm` | Update all packages for that one manager |
| (none) | Use TUI to ask scope |

If no argument is provided, ask: **"What would you like to update?"**

| Option | Description |
|--------|-------------|
| A single tool | Name the package to upgrade |
| Everything | Update all packages across all managers |
| One package manager | Update all packages for scoop / winget / apt / brew / choco / npm |

When scope is "everything" or a whole manager, **show the planned commands and the list of
packages that will change, and confirm before running** (upgrades can pull breaking versions).

## Step 3: Memory Recall (if SimpleMem available)

Before executing, if `memory_query` is present, query for past experience:

```
memory_query: "What happened last time I updated {tool|manager} on {platform}?"
```

Surface relevant gotchas (e.g. "last node upgrade required rebuilding native modules"). If
SimpleMem is unavailable, skip silently.

## Step 4: Execute Pipeline

### 4A: Single Tool

**Stage 1 — tool-installer agent** (Task tool). Provide: tool name, profile path, the
manager that owns it (from `profile.tools.{tool}.installedVia`, else the preferred manager),
platform. tool-installer will:
1. Confirm the tool is installed and read its current version
2. Run the upgrade command for the owning manager (table below)
3. Return: old version → new version, manager, whether anything changed

| Manager | Update one | Update all |
|---------|-----------|-----------|
| winget | `winget upgrade --id <id> -e` | `winget upgrade --all` |
| scoop | `scoop update <package>` | `scoop update *` |
| choco | `choco upgrade <package> -y` | `choco upgrade all -y` |
| brew | `brew upgrade <formula>` | `brew update && brew upgrade` |
| apt | `sudo apt install --only-upgrade -y <pkg>` | `sudo apt update && sudo apt upgrade -y` |
| npm | `npm install -g <pkg>@latest` | `npm update -g` |
| pip/uv | `uv pip install --upgrade <pkg>` (or `pip install --upgrade <pkg>`) | upgrade outdated from `uv pip list --outdated` |

> For scoop/winget/brew, refresh the source first (`scoop update`, `winget source update`,
> `brew update`) so version metadata is current before upgrading.

**Stage 2 — verify-agent**: confirm the binary still works and report the new version
(verification mode: post-update). For major version bumps, run the tool's smoke test.

**Stage 3 — docs-agent**: log `[OK] Updated {tool} {old}→{new} via {manager}` (or `[ERROR]`),
update `profile.tools.{tool}.version`/`lastChecked`, and create an issue if verify failed.

### 4B: All Packages for One Manager

1. Refresh the manager's source (see note above).
2. List what will change (`winget upgrade`, `scoop status`, `apt list --upgradable`,
   `brew outdated`, `choco outdated`, `npm outdated -g`) and show it to the user.
3. On confirmation, run the "Update all" command via tool-installer.
4. verify-agent spot-checks a couple of critical tools (those in `profile.capabilities`).
5. docs-agent logs the batch and updates affected `profile.tools` entries.

### 4C: Everything (`--all`)

Run 4B for each package manager present on the machine, in this order — system first, then
language managers: **apt/brew → scoop/winget/choco → npm → pip/uv**. Report per-manager
results; continue past a manager that fails and note which one broke.

## Step 5: Memory Store (if SimpleMem available)

```
memory_add:
  speaker: "admin:tool-installer"
  content: "Updated {tool|manager|all} on {DEVICE} ({platform}). {old→new versions}. Result: {success/failure}. {gotchas}"
```

## Step 6: Report

```
Update Complete: scoop (all)
══════════════════════════════

  Refreshed:   scoop buckets + manifests
  Upgraded:    ripgrep 14.1.0 → 14.1.1, fd 10.1.0 → 10.2.0, jq 1.7 → 1.7.1
  Unchanged:   git, 7zip (already current)
  Verified:    ✅ rg, fd, jq run
  Logged:      ~/.admin/logs/operations.log
  Profile:     Updated 3 tool versions
```

Or on failure:

```
Update Failed: node (npm)
══════════════════════════

  Update:      ✅ node 18.19.0 → 20.11.0
  Verify:      ❌ A global package's native module no longer loads
    Fix:       npm rebuild -g <package>

  Issue created: issue_20260601_node_native_module
  Logged:      ~/.admin/logs/operations.log
```

## Error Handling

- **Tool not installed**: report it and offer to `/install` instead.
- **Already current**: report the current version; nothing to do.
- **Pinned/held package**: respect the hold (`apt-mark`, `scoop hold`); report and ask before overriding.
- **Permission denied**: suggest the elevated command (`sudo`, admin shell).
- **Breaking major bump**: surface the version jump and confirm before proceeding when scope is "all".
- **Pipeline stage failed**: skip subsequent stages, report where it broke.

## Examples

```
/update node                 # single tool
/update --all                # everything, every manager
/update --scoop              # all scoop packages
/update --winget             # all winget packages
/update --apt                # all apt packages
/update                      # interactive mode (TUI scope prompt)
```
