# Admin-DevOps + Library: System Guide

How the admin-devops plugin, The Library, device profiles, and Infisical work together to manage local machines, remote infrastructure, and agent deployments across devices.

## Contents

- [System Overview](#system-overview)
- [Three Planes](#three-planes)
- [Profile Schema (v4.1)](#profile-schema-v41)
- [The Library](#the-library)
- [Secrets Architecture](#secrets-architecture)
- [MCP Server Management](#mcp-server-management)
- [Bootstrap Workflow](#bootstrap-workflow)
- [Consumer Types and Targeting](#consumer-types-and-targeting)
- [Slash Commands](#slash-commands)
- [Scripts Reference](#scripts-reference)
- [Agent Roster](#agent-roster)
- [Renderer Pipeline](#renderer-pipeline)
- [Daily Operations](#daily-operations)
- [Troubleshooting](#troubleshooting)

---

## System Overview

The system distributes three things to three types of devices:

| What | How | Where it lives |
|------|-----|----------------|
| **Skills, agents, prompts, MCP servers** | The Library (library.yaml catalog + git) | `evolv3ai/library` repo (private) |
| **Device config, bindings, consumer identity** | Profile Sync (DEVICE.json + git) | `$ADMIN_ROOT/profiles/` |
| **Secret values** | Infisical (3 projects by trust boundary) | Infisical Cloud, vault fallback |

The admin-devops plugin provides the skills, agents, and commands. The Library catalogs them. The profile tracks what's installed on each device. Infisical stores the secrets. Three renderers bridge catalog → device runtime.

```
The Library (catalog)
    ↓ /library use
Profile (bindings)
    ↓ render-runtime.sh / render-mcp-config.sh
Generated runtime files (.env, .mcp.json, AGENTS.md)
```

---

## Three Planes

### Plane 1: The Library

**Repo:** `evolv3ai/library` (private)
**Install path:** `~/.claude/skills/library/`
**Key files:** `library.yaml` (catalog), `library.json` (auto-generated JSON companion)

The Library is the universal catalog of all agentics. It tracks what exists, where it comes from, what it needs, and what devices it targets. It does NOT track what's installed — that's the profile's job.

Currently catalogs: 13 skills, 7 agents, 7 prompts, 3 MCP servers from admin-devops.

Commands: `/library use`, `/library add`, `/library list`, `/library sync`, `/library push`, `/library remove`, `/library search`

### Plane 2: Device Profiles

**Repo:** `admin-profiles` (private, synced via `sync-profile.sh`)
**Location:** `$ADMIN_ROOT/profiles/DEVICE.json`
**Schema:** v4.1

Each device has a JSON profile that tracks: hardware, installed tools, servers, deployments, preferences, and **bindings** (per-component secretRefs, env, install status).

Profile bindings are the install state. When `/library use simplemem` runs, the post-use hook writes `bindings.mcp.simplemem` into the profile. Reconcile reads bindings to know what's installed.

### Plane 3: Infisical

**Projects:** `admin-operator`, `admin-runtime`, `customer-*`
**Resolution:** `infisical://PROJECT/ENV/FOLDER/KEY` URIs
**Fallback:** vault.age → plaintext .env

Secrets are scoped by trust boundary. An operator workstation sees all three projects. A KASM runtime sees only its deployment folder. A customer PC sees only its customer project.

---

## Profile Schema (v4.1)

The profile JSON at `$ADMIN_ROOT/profiles/DEVICE.json` has these key sections:

### Core
- `schemaVersion`: "4.1"
- `device`: name, platform, shell, cpu, ram, architecture
- `tools`: installed development tools with version, path, status
- `packageManagers`: apt, npm, uv, etc. with preferred flags
- `preferences`: python manager, node manager, package manager, shell
- `servers[]`: managed remote servers with IPs, SSH keys, roles
- `deployments{}`: Coolify, KASM deployments with status

### v4.1 Additions
- `bindings`: per-component install state and secret references
- `consumer`: device type (workstation/runtime/customer-pc) and trust boundary
- `access`: which Infisical projects and folders this device can reach
- `secretsConfig`: backend (infisical/vault/env), fallback, multi-project flag
- `generated`: paths to rendered output files

### Bindings Model

```json
{
  "bindings": {
    "mcp": {
      "simplemem": {
        "secretRefs": { "SIMPLEMEM_TOKEN": "infisical://admin-operator/prod/shared/SIMPLEMEM_TOKEN" },
        "status": "active",
        "installedAt": "2026-03-17T00:00:00Z",
        "installPolicy": "library"
      }
    },
    "skill": {
      "admin": { "status": "active", "installPolicy": "plugin" }
    }
  }
}
```

Every `/library use` writes a binding — even for entries with no secrets. The profile's `bindings` map IS the install state. No separate tracking file.

**installPolicy values:**
- `library` — The Library manages this (copies files, resolves secrets)
- `plugin` — Claude Code plugin system manages files; Library only writes bindings
- `manual` — Documentation only, user manages

**status values:**
- `active` — Working, rendered
- `pending` — Installed but not yet rendered (secrets unresolved)
- `disabled` — Intentionally turned off
- `error` — Resolution failed

---

## The Library

### Catalog Structure

`library.yaml` has four sections:

```yaml
library:
  skills:     # SKILL.md-based capabilities
  agents:     # Agent definitions (subagents)
  prompts:    # Slash commands
  mcp:        # MCP server configurations
```

Each entry has:
- `name`, `description`, `source` (GitHub URL or local path)
- `requires` — typed dependencies: `skill:admin`, `agent:tool-installer`, `mcp:simplemem`
- `targets` — which consumer types: `[workstation, runtime, customer-pc]`
- `trustBoundary` — minimum trust level: `operator`, `runtime`, `customer`
- `installPolicy` — `library`, `plugin`, or `manual`

MCP entries additionally have:
- `type` — `stdio`, `streamable-http`, or `sse`
- `command` + `args` (stdio) or `url` (http/sse)
- `requiredSecrets` — map of secret names to `{description, defaultUri}`
- `env` — static (non-secret) environment variables

### library.json

Auto-generated JSON companion committed alongside library.yaml. Regenerated after every catalog change:

```bash
python3 -c "import yaml,json; json.dump(yaml.safe_load(open('library.yaml')),open('library.json','w'),indent=2)"
```

All downstream bash scripts read `library.json` with `jq`. No YAML parsing at runtime.

### Post-Use Hook

After `/library use` completes, the Library checks for a hook at `hooks/post-use.sh` or `$ADMIN_POST_USE_HOOK`. The hook (provided by admin-devops as `library-post-use-hook.sh`) writes bindings into the device profile. This keeps the Library generic.

---

## Secrets Architecture

### 4-Layer Model

```
Layer 1: Age key (~/.age/key.txt) — root of trust, never leaves device
  → Layer 2: Vault ($ADMIN_ROOT/vault.age) — bootstrap creds + offline fallback
    → Layer 3: Infisical Cloud (3 projects) — live secrets, scoped by trust
      → Layer 4: Generated runtime ($ADMIN_ROOT/generated/) — pre-resolved .env files
```

### 3 Infisical Projects

| Project | Trust Boundary | Contents |
|---------|---------------|----------|
| `admin-operator` | Operator | Provider API keys, LLM tokens, Cloudflare, Mattermost, Google creds |
| `admin-runtime` | Runtime | Agent bot tokens (lia/shane/terra/taco/picoclaw), deployment passwords |
| `customer-*` | Customer | Per-customer OpenClaw config, workspace, Google ADC |

### URI Format

```
infisical://PROJECT_SLUG/ENVIRONMENT/FOLDER.../KEY
```

Examples:
```
infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN
infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN
infisical://customer-larrysinteriors/prod/apps/openclaw/GATEWAY_TOKEN
```

### Fallback Chain

Every secret lookup follows this order:
1. **Generated file** (`generated/.env`) — pre-rendered, no network needed
2. **Infisical** — live lookup via CLI
3. **Vault** — age-encrypted local file
4. **Plaintext .env** — last resort

### Secret Resolution Scripts

```bash
# Resolve a single URI
resolve-secret-ref.sh "infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN"

# Multi-project secrets CLI
secrets --project admin-operator --path /providers/hetzner HCLOUD_TOKEN

# Legacy (works via fallback chain)
secrets HCLOUD_TOKEN
```

---

## MCP Server Management

MCP servers are cataloged in The Library and rendered to client config files.

### Lifecycle

1. **Catalog:** MCP entry in `library.yaml` with transport type, secrets, targets
2. **Install:** `/library use simplemem` → post-use hook writes binding to profile
3. **Render:** `render-mcp-config.sh` reads library.json + profile bindings → writes `~/.claude/.mcp.json`
4. **Diagnose:** `diagnose-mcp.sh` checks health (binary exists, URL reachable, config valid)

### Transport Types

| Type | Config Fields | Example |
|------|--------------|---------|
| `stdio` | `command`, `args`, `env` | npx-based MCP servers (Airtable, Zapier) |
| `streamable-http` | `url`, `headers` | Cloud-hosted (simplemem) |
| `sse` | `url`, `headers` | Self-hosted SSE (Infisical MCP) |

### Render MCP Config

```bash
render-mcp-config.sh                    # Render all eligible configs
render-mcp-config.sh --dry-run          # Preview without writing
render-mcp-config.sh --skip-unresolvable # Write even if secrets fail (for bootstrap)
render-mcp-config.sh --post-verify      # Run diagnose after render
```

The renderer:
1. Reads library.json MCP entries
2. Filters by consumer type and trust boundary
3. Resolves secrets from profile bindings via `resolve-secret-ref.sh`
4. Merges into `~/.claude/.mcp.json` (preserves non-library entries)
5. Backs up before writing

---

## Bootstrap Workflow

One-command setup for a fresh machine: `/bootstrap`

### Sequence

```
1. Detect environment (local or --remote user@host)
2. Install Claude Code (if missing)
3. Install The Library (git clone to ~/.claude/skills/library/)
4. Create profile (/setup-profile --headless) ← MUST come before reconcile
5. Reconcile (reconcile-library.sh --json) → what this device needs
6. /library use for each needed entry → hook writes bindings
7. render-runtime.sh --skip-unresolvable → generated/.env
8. render-mcp-config.sh --skip-unresolvable → MCP client configs
9. generate-agents-md.sh → ~/.claude/AGENTS.md
10. Verify (test-admin-profile.sh)
```

The `--skip-unresolvable` flag allows bootstrap to complete before Infisical is configured. Unresolved secrets are marked as `pending`. Configure Infisical and re-run renderers without the flag to activate.

### Headless Mode

```bash
/bootstrap --headless                         # Local, all defaults
/bootstrap --headless --pkg-mgr apt           # Override package manager
/bootstrap --remote root@kasm-htz-02 --headless  # Remote via SSH
```

---

## Consumer Types and Targeting

### Three Consumer Types

| Type | Trust Boundary | Gets | Example |
|------|---------------|------|---------|
| `workstation` | `operator` | All skills, all projects, full access | WOPR3 |
| `runtime` | `runtime` | admin skill, deployment-scoped secrets | kasm-hetzner-02 |
| `customer-pc` | `customer` | admin + openclaw, customer project only | Larry's PC |

### How Targeting Works

Library entries declare `targets: [workstation, runtime]` and `trustBoundary: operator`.

`reconcile-library.sh` reads the profile's `consumer.type` and `consumer.trustBoundary`, then computes:
- **Should install:** targets match, not yet bound
- **Installed:** binding exists with active/pending status
- **Not eligible:** target or trust mismatch

Trust hierarchy: `operator` ≥ `runtime` ≥ `customer`. An operator device can access anything. A runtime device can only access entries with trustBoundary `runtime` or `customer`.

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/bootstrap` | One-command setup for fresh machines (local or remote) |
| `/setup-profile` | Create/reconfigure device profile (TUI or `--headless`) |
| `/install` | Install tools, clone repos, run custom installers |
| `/provision` | Provision new cloud server (6 providers) |
| `/deploy` | Deploy application (Coolify, KASM) to server |
| `/server-status` | Show server inventory from profile |
| `/troubleshoot` | Track, diagnose, resolve issues |
| `/library use` | Pull skill/agent/prompt/MCP from catalog |
| `/library list` | Show catalog with install status |
| `/library add` | Register new entry in catalog |
| `/library sync` | Re-pull all installed items |
| `/library search` | Find entries by keyword |

---

## Scripts Reference

### Secrets

| Script | Purpose |
|--------|---------|
| `secrets` / `secrets.ps1` | Multi-backend secrets CLI (`--project`, `--path` for multi-project) |
| `resolve-secret-ref.sh` / `.ps1` | Parse `infisical://` URIs, resolve with vault fallback |
| `render-secret-file.sh` / `.ps1` | Decode base64 credential blob to file |

### Renderers

| Script | Purpose |
|--------|---------|
| `render-runtime.sh` / `.ps1` | Resolve profile bindings → `generated/.env` + `compat.env` |
| `render-mcp-config.sh` | Library MCP entries → `~/.claude/.mcp.json` |
| `generate-agents-md.sh` | Profile + library → `~/.claude/AGENTS.md` (passive context) |

### Library Integration

| Script | Purpose |
|--------|---------|
| `reconcile-library.sh` | Compare catalog vs profile bindings → should/installed/not-eligible |
| `library-post-use-hook.sh` | Post-install binding writer (called by Library after `/library use`) |
| `diagnose-mcp.sh` | Standalone MCP health checker (read-only) |

### Profile Management

| Script | Purpose |
|--------|---------|
| `test-admin-profile.sh` | Profile gate (mandatory first step) |
| `new-admin-profile.sh` / `.ps1` | Create v4.1 profile with bindings, consumer, .gitignore |
| `load-profile.sh` / `.ps1` | Load profile, `get_binding()` helper, accepts v3.0/4.0/4.1 |
| `sync-profile.sh` / `.ps1` | GitHub repo sync (pull if stale, push if changed) |
| `log-admin-event.sh` | Operation logging |

### Infisical Migration (one-time)

| Script | Purpose |
|--------|---------|
| `infisical-bootstrap.sh` | Create Infisical projects + folder hierarchy |
| `migrate-secrets-phase2.sh` | Move operator secrets → admin-operator |
| `migrate-secrets-phase3.sh` | Move agent secrets → admin-runtime + update profile |
| `migrate-secrets-phase4.sh` | Move deployment secrets |
| `migrate-secrets-phase5.sh` | Move JSON credential files |

---

## Agent Roster

| Agent | Model | Role |
|-------|-------|------|
| `tool-installer` | sonnet | Autonomous tool installation using profile preferences |
| `verify-agent` | sonnet | System health verification (post-install, post-provision, post-deploy) |
| `profile-validator` | haiku | Read-only profile validation and consistency checks |
| `docs-agent` | haiku | Structured file I/O for profiles, issues, logs |
| `ops-bot` | sonnet | Multi-step admin operations (migrations, bulk config) |
| `server-provisioner` | sonnet | Cloud VM provisioning across 6 providers |
| `deployment-coordinator` | sonnet | End-to-end app deployment (Coolify, KASM) |

---

## Renderer Pipeline

After bindings exist in the profile, three renderers produce runtime files:

```
Profile bindings   → render-runtime.sh     → $ADMIN_ROOT/generated/.env
                                            $ADMIN_ROOT/generated/compat.env

Library catalog    → render-mcp-config.sh  → ~/.claude/.mcp.json
 + Profile bindings

Profile + Library  → generate-agents-md.sh → ~/.claude/AGENTS.md
                                             $ADMIN_ROOT/generated/AGENTS.md
```

All renderers support `--dry-run`. `render-runtime.sh` and `render-mcp-config.sh` support `--skip-unresolvable` for bootstrap.

Generated files are gitignored (`$ADMIN_ROOT/.gitignore` created by `new-admin-profile.sh`).

---

## Daily Operations

### Install a tool
```
/install docker
```
Tool-installer agent reads profile preferences → installs via apt/brew/winget → verify-agent checks → docs-agent logs.

### Provision a server
```
/provision hetzner
```
TUI interview for region/size/purpose → server-provisioner creates VM → profile updated with new server entry.

### Add a new MCP server to the catalog
```
/library add
```
Provide: name, description, transport type (stdio/http/sse), url/command, secrets needed. Library writes to library.yaml, regenerates library.json, commits and pushes.

### Install an MCP server on this device
```
/library use simplemem
```
Library runs post-use hook → hook writes binding to profile → run `render-mcp-config.sh` to activate.

### Check what's installed vs what should be
```bash
reconcile-library.sh
```
Compares library catalog against profile bindings. Shows what's installed, what's missing, what's not eligible for this consumer type.

### Check MCP server health
```bash
diagnose-mcp.sh
```
Reads `~/.claude/.mcp.json`, checks each server's health (binary exists, URL reachable, config valid).

### Sync skills across devices
```
/library sync
```
Re-pulls all installed items from their sources. For plugin-managed entries, skips file copy. Updates bindings timestamps.

### Render runtime after Infisical changes
```bash
render-runtime.sh        # Resolve all secretRefs → generated/.env
render-mcp-config.sh     # Resolve MCP secrets → .mcp.json
generate-agents-md.sh    # Rebuild passive context
```

---

## Troubleshooting

### Profile not found
```bash
test-admin-profile.sh
# If exists: false → run /setup-profile
```

### Secrets not resolving
```bash
secrets --status                    # Check backend, auth, paths
resolve-secret-ref.sh --quiet URI   # Test specific URI
render-runtime.sh --dry-run         # See what would resolve
```

### MCP server not working
```bash
diagnose-mcp.sh                    # Check all servers
diagnose-mcp.sh --server simplemem # Check one
```

### Library catalog out of sync
```bash
cd ~/.claude/skills/library && git pull   # Pull latest catalog
reconcile-library.sh                      # Compare against profile
```

### Reconcile shows "should install" for plugin entries
The plugin is installed but no binding exists yet. Run `/library use <name>` to create the binding, or the post-use hook will create it.

### Bootstrap fails on secret resolution
Use `--skip-unresolvable`. Configure Infisical later, then re-run renderers without the flag.

### Generated files contain stale secrets
Re-run the renderers:
```bash
render-runtime.sh && render-mcp-config.sh && generate-agents-md.sh
```
