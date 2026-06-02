# Infisical Secrets Backend

Infisical Cloud is the primary secrets backend for the admin suite. The age vault remains as offline fallback and bootstrap anchor. For the full 4-layer model, backend comparison, folder taxonomy, and daily-usage CLI, see `references/secrets-architecture.md`.

## Contents

- [CLI Installation](#cli-installation)
- [Configuration](#configuration)
- [Bootstrap Chain](#bootstrap-chain)
- [Migration from Vault](#migration-from-vault)
- [MCP Server](#mcp-server)
- [Troubleshooting](#troubleshooting)

## CLI Installation

One-line install per platform, then verify with `infisical --version`:

```bash
# Linux/WSL (apt)
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash && sudo apt install -y infisical
# macOS
brew install infisical/get-cli/infisical
```
```powershell
# Windows
winget install Infisical.CLI
```

Project bootstrap (create the 3 projects + folder hierarchy) is run once via `infisical-bootstrap.sh`.

## Configuration

Add to `~/.admin/.env`:

```bash
ADMIN_SECRETS_BACKEND=infisical
INFISICAL_PROJECT_ID=<your-project-id>     # default project; multi-project uses config/infisical-projects.json
INFISICAL_ENVIRONMENT=prod
INFISICAL_AUTH_METHOD=cli-login            # or machine-identity
```

All secrets scripts (`secrets`, `secrets.ps1`, `load-profile.sh`, `resolve-secret-ref.sh`) read these values and route through Infisical automatically. The project slug → ID mapping for multi-project lookups lives in `$ADMIN_ROOT/config/infisical-projects.json`.

For daily-usage CLI (including `--project`/`--path` and `-Backend` override), see `references/secrets-architecture.md` § Daily Usage.

## Bootstrap Chain

The bootstrap problem: you need credentials to access Infisical, but credentials are what Infisical stores. The solution is the two-layer anchor:

```
Layer 1: age key (local file, kept on device)
  └── Decrypts vault.age
        └── Contains: INFISICAL_UNIVERSAL_AUTH_CLIENT_ID, CLIENT_SECRET
              └── Authenticates to Infisical Cloud
                    └── Returns: all other secrets (HCLOUD_TOKEN, etc.)
```

The machine-identity client credentials are the only secrets that need to live in the age vault — everything else is fetched from Infisical at runtime. Headless environments authenticate with:

```bash
export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="..."
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="..."
infisical login --method=universal-auth
```

Machine-identity scoping per environment is documented in `references/secrets-architecture.md` § Machine Identities.

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
4. Print next steps (verify, update satellite `.env`, keep vault as fallback)

After migration, set `ADMIN_SECRETS_BACKEND=infisical` in `~/.admin/.env`. Keep `vault.age` and `ADMIN_VAULT=enabled` — the vault serves as offline fallback.

The phased migration into the 3-project layout uses `migrate-secrets-phase2.sh` (operator) through `migrate-secrets-phase5.sh` (JSON credential files); see `references/secrets-architecture.md` § Scripts Reference.

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

## Troubleshooting

Project structure (3-project split), folder taxonomy, and the `infisical://` URI scheme are in `references/secrets-architecture.md` § 3 Infisical Projects and § URI Format.

### Fallback activating unexpectedly

Run `secrets --status` to see which backend is active and whether auth succeeds. Common causes:
- `ADMIN_SECRETS_BACKEND` not set (defaults to `vault`)
- Infisical CLI installed but not logged in (`infisical login`, or `infisical login --method=universal-auth` for machine identity)
- `INFISICAL_PROJECT_ID` pointing to the wrong project

### Secrets out of sync between backends

After migration, edits should go to Infisical (via dashboard or `infisical secrets set KEY=value`). The vault becomes read-only fallback. To re-sync the vault from Infisical:

```bash
# Export from Infisical to temp file, re-encrypt to vault
infisical export --projectId $PROJECT_ID --env prod --format=dotenv > /tmp/sync.env
secrets --encrypt /tmp/sync.env
rm /tmp/sync.env
```
