---
name: admin
description: |
  Local machine administration for Windows, WSL, macOS, Linux. Install tools, check
  if software is installed, manage packages, configure dev environments. Works with
  winget, scoop, brew, apt, npm, pip, uv. Profile-aware: adapts to your preferences.

  Use when: install 7zip, is git installed, clone repo, check if node installed,
  add to PATH, configure MCP servers, manage dev tools, set up environment.

  NOT for: VPS, cloud servers, remote infrastructure → use devops skill.
---

# Admin - Local Machine Companion (Alpha)

**Script paths**: All paths below are relative to this skill's base directory.
Prepend the base directory shown above when running scripts (e.g., `{base}/scripts/test-admin-profile.sh`).

---

## 🛑 PROFILE GATE — MANDATORY FIRST STEP

**HALT. You MUST check for a profile before ANY operation. This is non-negotiable.**

### Step 1: Check Satellite .env

The fastest check is whether `~/.admin/.env` exists. This satellite file is created
during setup and contains bootstrap vars (`ADMIN_ROOT`, `ADMIN_DEVICE`, `ADMIN_PLATFORM`)
plus per-device preference vars (`ADMIN_PKG_MGR`, `ADMIN_WIN_PKG_MGR`, etc.).

**Bash (WSL/Linux/macOS):**
```bash
scripts/test-admin-profile.sh
```

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "scripts/Test-AdminProfile.ps1"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...","platform":"..."}`

### Step 2: If `exists: false` → HALT AND RUN SETUP

**DO NOT CONTINUE with the user's task. You must create a profile first.**

Use the TUI interview below to gather preferences, then call the setup script.

---

## 🎤 TUI Setup Interview (Agent-Driven)

When profile does not exist, ask these questions using your TUI capabilities (e.g., `AskUserQuestion`).

### Q1: Storage Location (Required)

Ask: **"Will you use Admin on a single device or multiple devices?"**

| Option | Description |
|--------|-------------|
| Single device (Recommended) | Local storage at `~/.admin`. Simple, no sync needed. |
| Multiple devices | Cloud-synced folder (Dropbox, OneDrive, NAS). Profiles shared across machines. |

If "Multiple devices" selected, follow up: **"Enter the path to your cloud-synced folder"**
- Examples: `C:\Users\You\Dropbox\.admin`, `~/Dropbox/.admin`, `N:\Shared\.admin`

### Q2: Tool Preferences (Optional)

Ask: **"Set tool preferences now, or use defaults?"**

If yes, ask each (platform-aware):
- **Package manager (Linux-side):** apt (default on WSL/Linux) / brew (default on macOS) / dnf / pacman
- **Windows package manager (WSL only):** winget (default) / scoop / choco / none
- **Package manager (Windows native):** winget (default) / scoop / choco
- **Python manager:** uv (default) / pip / conda / poetry
- **Node manager:** npm (default) / pnpm / yarn / bun
- **Default shell:** pwsh (default on Windows) / bash (default on Linux) / zsh (default on macOS) / fish

### Q3: Inventory Scan (Optional)

Ask: **"Run a quick inventory scan to detect installed tools?"**
- Yes: Scans for git, node, python, docker, ssh, etc. and records versions
- No: Creates minimal profile, tools detected on first use

---

## 🔧 Create Profile (After Interview)

Pass the user's answers to the setup script.

**PowerShell:**
```powershell
pwsh -NoProfile -File "scripts/New-AdminProfile.ps1" `
  -AdminRoot "C:/Users/You/.admin" `
  -PkgMgr "winget" `
  -PyMgr "uv" `
  -NodeMgr "npm" `
  -ShellDefault "pwsh" `
  -RunInventory
```

**Bash:**
```bash
scripts/new-admin-profile.sh \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "brew" \
  --py-mgr "uv" \
  --node-mgr "npm" \
  --shell-default "zsh" \
  --run-inventory
```

**Bash (WSL with Windows path + dual package managers):**
```bash
scripts/new-admin-profile.sh \
  --admin-root "N:\Dropbox\08_Admin" \
  --multi-device \
  --pkg-mgr "apt" \
  --win-pkg-mgr "winget" \
  --run-inventory
```

Add `-MultiDevice` (PowerShell) or `--multi-device` (Bash) if user selected multi-device setup.

### After Profile Created

1. Verify: Re-run `Test-AdminProfile.ps1` or `test-admin-profile.sh` → should return `exists: true`
2. Load profile: See `references/profile-gate.md` for load commands
3. **Now** proceed with the user's original task

---

## CRITICAL: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `assets/` within a skill.
- Store live secrets in `~/.admin/.env` and reference from there.

## Vault: Encrypted Secrets (age)

Secrets can be encrypted at rest using [age encryption](https://age-encryption.org/). When `ADMIN_VAULT=enabled` in `~/.admin/.env`, `load-profile.sh` and `Load-Profile.ps1` decrypt `$ADMIN_ROOT/vault.age` instead of reading plaintext `.env`.

**Setup**: `age-keygen -o ~/.age/key.txt` then `secrets --encrypt $ADMIN_ROOT/.env`

**CLI (Bash)**: `secrets KEYNAME` | `secrets --list` | `eval $(secrets -s)` | `secrets --edit`

**CLI (PowerShell)**: `secrets.ps1 KEY` | `secrets.ps1 -List` | `secrets.ps1 -Source` | `secrets.ps1 -Status`

**Feature flag**: `ADMIN_VAULT=enabled|disabled` in satellite `~/.admin/.env`. Falls back to plaintext when disabled or deps missing.

**Cross-platform**: Bash (`scripts/secrets`), PowerShell (`scripts/secrets.ps1`), TypeScript (`scripts/admin-vault.ts` with `age-encryption` npm).

**Migration**: Run `scripts/migrate-to-vault.sh` (Linux/WSL) or `scripts/migrate-to-vault.ps1` (Windows).

**Guide**: `references/vault-guide.md`

## Architecture

### Ecosystem Map

```
admin (core)
  ├── 9 satellite skills: devops, oci, hetzner, contabo, digital-ocean, vultr, linode, coolify, kasm
  ├── 6 agents: profile-validator, docs-agent, verify-agent, tool-installer, mcp-bot, ops-bot
  ├── Profile system: ~/.admin/.env (satellite) → $ADMIN_ROOT/profiles/*.json
  ├── Vault: $ADMIN_ROOT/vault.age (age-encrypted secrets)
  └── SimpleMem: Long-term memory across sessions (graceful degradation)
```

### Data Flow

```
Satellite .env (bootstrap)  →  profile.json (device config)  →  Agent decisions
        ↓                              ↓                              ↓
  ADMIN_ROOT, DEVICE,          tools, servers, prefs,          SimpleMem storage
  PLATFORM, VAULT flag         capabilities, history           (speaker convention)
```

- **Satellite `.env`** (`~/.admin/.env`): Per-device bootstrap. Points to `ADMIN_ROOT`.
- **Root `.env`** (`$ADMIN_ROOT/.env`): Manifest (all keys visible, secrets in vault).
- **Profile JSON** (`$ADMIN_ROOT/profiles/{DEVICE}.json`): Full device config.
- **Vault** (`$ADMIN_ROOT/vault.age`): Encrypted secrets, decrypted at runtime.

### Agent Roster

| Agent | Model | Role | Tools |
|-------|-------|------|-------|
| profile-validator | haiku | JSON validation, read-only health check | Read, Bash, Glob |
| docs-agent | haiku | File I/O documentation updates | Read, Write, Glob, Grep |
| verify-agent | sonnet | System health checks, no Write | Read, Bash, Glob, Grep |
| tool-installer | sonnet | Install software per profile prefs | Read, Write, Bash, AskUserQuestion |
| mcp-bot | sonnet | MCP server diagnostics and config | Read, Write, Bash, Glob, Grep |
| ops-bot | sonnet | Multi-step operations (migration, import, bulk config) | Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion |

All agents use SimpleMem graceful degradation and profile gate as first step.
Details: `references/agent-teams.md`, `references/memory-integration.md`

### Satellite Dependency Graph

```
admin (core) ─── required by all satellites
  │
  ├── devops ─── required by provider + app skills
  │     │
  │     ├── oci, hetzner, contabo, digital-ocean, vultr, linode
  │     │        (provision servers)
  │     │              │
  │     └── coolify, kasm
  │           (deploy apps TO provisioned servers)
  │
  └── Profile system provides: server inventory, SSH keys, credentials (via vault)
```

- **admin**: Core profile, logging, tool installation. Required by everything.
- **devops**: Server inventory, SSH, deployment coordination. Required by all infrastructure.
- **Provider skills** (oci, hetzner, etc.): Provision VMs. Independent of each other.
- **App skills** (coolify, kasm): Deploy TO servers. Require a provisioned server from a provider skill.

## Task Qualification (MANDATORY)
- If the task involves **remote servers/VPS/cloud**, stop and hand off to **devops**.
- If the task is **local machine administration**, continue.
- If ambiguous, ask a clarifying question before proceeding.

## Task Routing

| Task | Reference |
|------|-----------|
| Install tool/package | references/{platform}.md |
| Windows administration | references/windows.md |
| WSL administration | references/wsl.md |
| macOS/Linux admin | references/unix.md |
| MCP server management | references/mcp.md |
| Skill registry | references/skills-registry.md |
| Memory integration | references/memory-integration.md |
| **Remote servers/cloud** | **→ Use devops skill** |

## Profile-Aware Adaptation (Always Check Preferences)

- Python: `preferences.python.manager` (uv/pip/conda/poetry)
- Node: `preferences.node.manager` (npm/pnpm/yarn/bun)
- Packages: `preferences.packages.manager` (scoop/winget/choco/brew/apt)

Never suggest install commands without checking preferences first.

## Package Installation Workflow (All Platforms)

1. Detect environment (Windows/WSL/Linux/macOS)
2. Load profile via profile gate
3. Check if tool already installed (`profile.tools`)
4. Use preferred package manager
5. Log the operation

## Logging (MANDATORY)

Log every operation with the shared helpers.

**Bash** — params: `MESSAGE` `LEVEL` (INFO|WARN|ERROR|OK):
```bash
source scripts/log-admin-event.sh
log_admin_event "Installed ripgrep" "OK"
```

**PowerShell** — params: `-Message` `-Level` (INFO|WARN|ERROR|OK):
```powershell
pwsh -NoProfile -File "scripts/Log-AdminEvent.ps1" -Message "Installed ripgrep" -Level OK
```

**Note**: There are no `-Tool`, `-Action`, `-Status`, or `-Details` parameters. Use `-Message` with a descriptive string.

## Scripts / References

- Core scripts: `scripts/` (profile, logging, issues, AGENTS.md)
- MCP scripts: `scripts/mcp-*`
- Skills registry scripts: `scripts/skills-*`
- References: `references/*.md`

---

## Quick Pointers

- Cross-platform guidance: `references/cross-platform.md`
- Shell detection: `references/shell-detection.md`
- Device profiles: `references/device-profiles.md`
- PowerShell tips: `references/powershell-commands.md`
