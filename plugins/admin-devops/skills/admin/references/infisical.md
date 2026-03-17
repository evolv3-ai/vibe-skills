# Infisical Secrets Backend

Infisical Cloud replaces the age vault as the primary secrets backend for multi-device setups. The age vault remains as an offline fallback.

## Contents

- [Overview](#overview)
- [Cloud Setup](#cloud-setup)
- [CLI Installation](#cli-installation)
- [Authentication](#authentication)
- [Configuration](#configuration)
- [Migration from Vault](#migration-from-vault)
- [Daily Usage](#daily-usage)
- [MCP Server](#mcp-server)
- [Bootstrap Chain](#bootstrap-chain)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

## Overview

Three secrets backends are available, configured via `ADMIN_SECRETS_BACKEND` in `~/.admin/.env`:

| Backend | Storage | Best For | Offline |
|---------|---------|----------|---------|
| `infisical` | Infisical Cloud | Multi-device, team access, audit trail | No |
| `vault` | `$ADMIN_ROOT/vault.age` | Single device, air-gapped, offline | Yes |
| `env` | `$ADMIN_ROOT/.env` | Legacy, not recommended | Yes |

Default is `vault` for backward compatibility. The fallback chain is: infisical → vault → env.

## Cloud Setup

1. Create an account at [app.infisical.com](https://app.infisical.com)
2. Create a new project (e.g., "admin-suite")
3. Note the **Project ID** from the URL: `app.infisical.com/project/<PROJECT_ID>/secrets`
4. The default environment is `prod` — use this unless you have dev/staging separation

Secrets are organized as flat key-value pairs in the project, matching the existing vault format (e.g., `HCLOUD_TOKEN`, `CLOUDFLARE_API_TOKEN`).

## CLI Installation

**Linux/WSL:**
```bash
# apt (Debian/Ubuntu)
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt update && sudo apt install infisical

# Or via npm
npm install -g @infisical/cli
```

**macOS:**
```bash
brew install infisical/get-cli/infisical
```

**Windows:**
```powershell
scoop bucket add org https://github.com/nicholasgasior/scoop-bucket
scoop install infisical
# or: winget install Infisical.CLI
```

Verify: `infisical --version`

## Authentication

### Interactive Login (developer machines)

```bash
infisical login
```

Opens a browser for OAuth. Token is cached locally at `~/.infisical/credentials`.

### Machine Identity (CI/headless)

For automation or headless environments:

1. Create a Machine Identity in the Infisical dashboard (Settings → Machine Identities)
2. Assign it to your project with read access
3. Store the client ID and secret in the age vault (bootstrap chain)

```bash
export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="..."
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="..."
infisical login --method=universal-auth
```

The client credentials are the only secrets that need to live in the age vault — everything else is fetched from Infisical at runtime.

## Configuration

Add to `~/.admin/.env`:

```bash
ADMIN_SECRETS_BACKEND=infisical
INFISICAL_PROJECT_ID=<your-project-id>
INFISICAL_ENVIRONMENT=prod
INFISICAL_AUTH_METHOD=cli-login    # or machine-identity
```

All secrets scripts (`secrets`, `secrets.ps1`, `load-profile.sh`) read these values and route through Infisical automatically.

### Override at Runtime

```bash
# Force a specific backend for one command
secrets --backend infisical --list
secrets --backend vault HCLOUD_TOKEN
```

**PowerShell:**
```powershell
.\secrets.ps1 -Backend infisical -List
.\secrets.ps1 -Backend vault HCLOUD_TOKEN
```

## Migration from Vault

The `--migrate-to-infisical` command decrypts the vault and pushes each key to Infisical:

**Bash:**
```bash
secrets --migrate-to-infisical
```

**PowerShell:**
```powershell
.\secrets.ps1 -MigrateToInfisical
```

This will:
1. Decrypt `vault.age` using the age key
2. Push each `KEY=value` pair to the configured Infisical project/environment
3. Report success/failure per key
4. Print next steps (verify, update satellite .env, keep vault as fallback)

After migration, update `~/.admin/.env`:
```bash
ADMIN_SECRETS_BACKEND=infisical
```

Keep `vault.age` and `ADMIN_VAULT=enabled` — the vault serves as offline fallback.

## Daily Usage

Usage is identical to the vault — the `secrets` CLI routes through the active backend automatically:

```bash
secrets HCLOUD_TOKEN              # Get from current backend
secrets --list                     # List all keys
eval $(secrets -s)                 # Export all to env
secrets --status                   # Show backend status + auth
```

When Infisical is unavailable (offline, auth expired), the fallback chain kicks in:
1. Try Infisical → fails
2. Try vault (if vault.age + age key exist) → succeeds
3. Try plaintext .env (last resort)

## MCP Server

Infisical provides an official MCP server (`@infisical/mcp`) for Claude Desktop integration:

```json
{
  "mcpServers": {
    "infisical": {
      "command": "npx",
      "args": ["-y", "@infisical/mcp@latest"],
      "env": {
        "INFISICAL_UNIVERSAL_AUTH_CLIENT_ID": "...",
        "INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET": "..."
      }
    }
  }
}
```

This gives Claude direct access to secrets via MCP tools. Use the admin skill's `mcp-bot` to install and configure this.

## Bootstrap Chain

The bootstrap problem: you need credentials to access Infisical, but credentials are what Infisical stores. The solution is a two-layer architecture:

```
Layer 1: age key (local file, never leaves device)
  └── Decrypts vault.age
        └── Contains: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET
              └── Authenticates to Infisical Cloud
                    └── Returns: all other secrets (HCLOUD_TOKEN, etc.)
```

- **One local secret** (age key) unlocks **one encrypted secret** (vault with Infisical creds)
- Infisical creds unlock **all remote secrets**
- If Infisical is down, the vault still has everything as fallback

## Project Structure (3-Project Split)

Secrets are organized across 3 Infisical projects by trust boundary, with folder hierarchies:

### 1. `admin-operator` — Operator secrets (provider keys, shared services)

```
/shared/llm/              OPENROUTER_API_KEY, OPENAI_API_KEY
/shared/mattermost/       ADMIN_TOKEN, URL
/shared/sentinel/         TOKEN
/shared/                  GITHUB_TOKEN
/providers/hetzner/       HCLOUD_TOKEN
/providers/contabo/       CLIENT_SECRET, OAUTH_PASS
/providers/digitalocean/  ACCESS_TOKEN
/providers/vultr/         API_KEY
/providers/linode/        API_TOKEN
/network/cloudflare/      API_TOKEN, ZONE_ID, ACCOUNT_ID
/files/gcloud/            Base64-encoded JSON credentials
```

### 2. `admin-runtime` — Agent and deployment runtime secrets

```
/agents/lia/              MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/shane/            MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/terra/            MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/taco/             MM_BOT_TOKEN
/agents/picoclaw/         DISCORD_BOT_TOKEN, MM_BOT_TOKEN, BRAVE_API_KEY
/deployments/kasm-*/      ADMIN_PASSWORD, CF_TUNNEL_TOKEN
/deployments/nanoclaw-*/  CF_TUNNEL_TOKEN
```

### 3. `customer-*` — Per-customer projects (isolated)

```
/apps/openclaw/           Gateway config, channel tokens
/workspace/               Workspace preferences
/files/gcloud/            Customer-specific Google ADC
/local/                   Local overrides
```

Project slug → ID mapping is in `$ADMIN_ROOT/config/infisical-projects.json`.

### URI-based access

Secrets are referenced via `infisical://` URIs:

```
infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN
infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN
```

Use `resolve-secret-ref.sh` to resolve URIs, or `secrets --project admin-operator --path /providers/hetzner HCLOUD_TOKEN`.

See `references/secrets-architecture.md` for the complete 4-layer model.

## Troubleshooting

### "infisical CLI not installed"

See [CLI Installation](#cli-installation) above. Verify with `infisical --version`.

### "INFISICAL_PROJECT_ID not set"

Add to `~/.admin/.env`:
```bash
INFISICAL_PROJECT_ID=<your-project-id>
```
Get the ID from the Infisical dashboard URL.

### "Auth: FAILED"

Re-authenticate:
```bash
infisical login           # Interactive
infisical login --method=universal-auth  # Machine identity
```

Token may have expired. Check `~/.infisical/credentials`.

### Fallback activating unexpectedly

Run `secrets --status` to see which backend is active and whether auth succeeds. Common causes:
- `ADMIN_SECRETS_BACKEND` not set (defaults to `vault`)
- Infisical CLI installed but not logged in
- Project ID pointing to wrong project

### Secrets out of sync between backends

After migration, edits should go to Infisical (via dashboard or `infisical secrets set KEY=value`). The vault becomes read-only fallback. To re-sync vault from Infisical:

```bash
# Export from Infisical to temp file, re-encrypt to vault
infisical export --projectId $PROJECT_ID --env prod --format=dotenv > /tmp/sync.env
secrets --encrypt /tmp/sync.env
rm /tmp/sync.env
```
