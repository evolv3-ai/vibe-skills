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

**Script path resolution**: When Claude Code loads this file, it provides the full
path. All `scripts/` references below are relative to this file's directory.
Derive `SKILL_DIR` from this file's path and prepend it when running scripts
(e.g., if loaded from `/path/to/skills/admin/SKILL.md`, run `/path/to/skills/admin/scripts/test-admin-profile.sh`).

---

## Profile Gate — Mandatory First Step

Check for a profile before any operation. No profile means no preferences, no logging path, no state.

**Bash (WSL/Linux/macOS):**
```bash
scripts/test-admin-profile.sh
```

**PowerShell (Windows):**
```powershell
pwsh -NoProfile -File "scripts/Test-AdminProfile.ps1"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...","platform":"..."}`

If `exists: false` — stop and run the TUI setup interview before proceeding.
Full details: `references/profile-gate.md` (discovery, TUI interview, create commands, troubleshooting).

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
