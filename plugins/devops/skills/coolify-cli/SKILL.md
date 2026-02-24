---
name: coolify-cli
description: |
  Manage Coolify self-hosted PaaS from the terminal. Multi-instance contexts, application lifecycle (deploy, logs, env sync), database provisioning with backups, service management, and CI/CD automation via JSON output.

  Use when: deploying apps via Coolify CLI, managing servers/databases/services, syncing environment variables, automating Coolify workflows, or troubleshooting "cannot unmarshal array", 404 on service env update, context authentication failures.
---

# Coolify CLI

## Quick Start (3 Minutes)

### 1. Install

```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/coollabsio/coolify-cli/main/scripts/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/coollabsio/coolify-cli/main/scripts/install.ps1 | iex

# Via Go
go install github.com/coollabsio/coolify-cli/coolify@latest
```

### 2. Authenticate

Get an API token from your Coolify dashboard at `/security/api-tokens`.

```bash
# Cloud-hosted Coolify
coolify context set-token cloud <YOUR_TOKEN>

# Self-hosted Coolify
coolify context add production https://coolify.example.com <YOUR_TOKEN>

# Verify connection
coolify context verify
```

### 3. First Commands

```bash
coolify server list
coolify app list
coolify deploy name my-app
```

---

## Multi-Instance Context Management

Each context stores a name, URL, and API token. Multiple Coolify instances (cloud, staging, production) are managed independently.

```bash
# Add contexts
coolify context add production https://prod.coolify.example.com <token>
coolify context add staging https://staging.coolify.example.com <token>

# List all contexts
coolify context list

# Switch default context
coolify context use production

# Override per-command (no switching needed)
coolify app list --context staging

# Verify current context
coolify context verify

# Show Coolify instance version
coolify context version

# Delete a context
coolify context delete staging
```

**Config file location:**
- Linux/macOS: `~/.config/coolify/config.json`
- Windows: `%USERPROFILE%\.config\coolify\config.json`

**Override priority:** `--token` flag > `--context` flag > default context.

---

## Application Lifecycle

### Deploy

```bash
coolify deploy uuid <uuid>              # Deploy by UUID
coolify deploy name my-app              # Deploy by app name
coolify deploy batch <uuid1>,<uuid2>    # Deploy multiple apps
```

### Manage

```bash
coolify app list                        # List all applications
coolify app get <uuid>                  # Get app details
coolify app start <uuid>               # Start application
coolify app stop <uuid>                # Stop application
coolify app restart <uuid>             # Restart application
coolify app delete <uuid>              # Delete application
```

### Logs

```bash
coolify app logs <uuid>                           # View recent logs
coolify app logs <uuid> --lines 100               # Last 100 lines
coolify app logs <uuid> --follow                  # Stream in real-time
coolify app deployments list <uuid>               # Deployment history
coolify app deployments logs <deployment-uuid>    # Specific deployment logs
```

### Environment Variables

```bash
coolify app env list <uuid>                              # List all vars
coolify app env create <uuid> --key DB_URL --value "..." # Create variable
coolify app env update <uuid> --key DB_URL --value "..." # Update variable
coolify app env delete <uuid> --key DB_URL               # Delete variable
coolify app env sync <uuid> --file .env                  # Sync from file
```

**CRITICAL:** `env sync` only creates and updates variables. It does NOT delete variables that exist in Coolify but are absent from the `.env` file. To fully sync, manually delete unwanted vars first.

---

## Database Management

Supported types: postgres, mysql, mariadb, mongodb, redis, keydb, dragonfly, clickhouse.

```bash
coolify database list                                           # List all
coolify database get <uuid>                                     # Get details
coolify database create --server-uuid <uuid> --type postgres    # Create
coolify database start <uuid>                                   # Start
coolify database stop <uuid>                                    # Stop
coolify database restart <uuid>                                 # Restart
coolify database delete <uuid>                                  # Delete
```

### Backup Automation

```bash
coolify database backup list <db-uuid>                          # List backup configs
coolify database backup create <db-uuid> --frequency "daily" --enabled  # Create schedule
coolify database backup trigger <backup-uuid>                   # Trigger now
coolify database backup executions <backup-uuid>                # Check history
coolify database backup update <backup-uuid> --frequency "weekly"       # Update schedule
coolify database backup delete <backup-uuid>                    # Remove config
```

---

## Service Management

Coolify supports 110+ one-click services (Redis, WordPress, Plausible, Ghost, etc.).

```bash
coolify service list                   # List all services
coolify service get <uuid>             # Get details
coolify service start <uuid>           # Start
coolify service stop <uuid>            # Stop
coolify service restart <uuid>         # Restart
coolify service delete <uuid>          # Delete
```

**Known bug:** `coolify service env update` returns 404 (issue #48). Use delete + create as workaround.

---

## Server Management

```bash
coolify server list                    # List all servers
coolify server get <uuid>              # Get details
coolify server add --name web-1 --ip 192.168.1.100 --private-key-uuid <key-uuid> --user root
coolify server validate <uuid>         # Validate configuration
coolify server domains <uuid>          # List configured domains
```

---

## Output Formats & Scripting

All commands support `--format`:

```bash
coolify server list                    # Table (default, human-readable)
coolify server list --format json      # JSON for automation
coolify server list --format pretty    # Pretty-printed JSON

# Pipe to jq for filtering
coolify app list --format json | jq '.[].name'

# Extract UUIDs
coolify app list --format json | jq -r '.[].uuid'
```

---

## SSH Key Management

```bash
coolify private-key list                                    # List keys
coolify private-key get <uuid>                              # Get details
coolify private-key add --name deploy-key --file ~/.ssh/id_ed25519  # Add key
coolify private-key remove <uuid>                           # Remove key
```

**Note:** SSH keys must be passwordless (passphrase not supported).

---

## GitHub App Integration

```bash
coolify github list                                 # List GitHub Apps
coolify github get <id>                             # Get details
coolify github repos <id>                           # List repos
coolify github branches <id> --repo owner/repo      # List branches
coolify github create --name my-app --app-id 123456 --private-key-uuid <uuid> --webhook-secret "secret"
coolify github delete <id>                          # Remove integration
```

---

## Critical Rules

### Always Do

- Verify context before operations: `coolify context verify`
- Use `--format json` for automation and piping
- Test deployments on staging context before production
- Use `coolify deploy batch` for coordinated multi-app deployments
- Keep API tokens scoped and rotated regularly

### Never Do

- Store API tokens in shell history (use context system instead)
- Assume `env sync` deletes variables (it only creates/updates)
- Use `--force` in production without understanding the operation
- Skip context verification after token rotation
- Use passphrase-protected SSH keys (not supported)

### Command Name Corrections

Claude has limited training data for Coolify CLI (released late 2025). Common hallucinations:

- `coolify app list` NOT `coolify apps list` or `coolify application list`
- `coolify deploy uuid <uuid>` NOT `coolify app deploy <uuid>` — deploy is top-level
- `coolify deploy name <name>` NOT `coolify deploy --app <name>`
- Must specify subcommand: `coolify deploy uuid <uuid>` NOT `coolify deploy <uuid>`
- `--format json` is correct (NOT `--output json` like cf CLI)

---

## Known Issues Prevention

This skill prevents **5** documented issues:

### Issue #1: "app env sync" Fails with "cannot unmarshal array"
**Error**: `cannot unmarshal array into Go value`
**Source**: https://github.com/coollabsio/coolify-cli/issues/49
**Prevention**: Ensure `.env` file uses simple `KEY=VALUE` format. No JSON arrays. Sync individual variables if bulk sync fails.

### Issue #2: "service env update" Returns 404
**Error**: HTTP 404 Not Found
**Source**: https://github.com/coollabsio/coolify-cli/issues/48
**Prevention**: Delete and recreate the variable instead of updating:
```bash
coolify service env delete <uuid> --key MY_KEY
coolify service env create <uuid> --key MY_KEY --value "new_value"
```

### Issue #3: Context Auth Failure After Token Rotation
**Error**: 401 Unauthorized after rotating API token
**Prevention**: Update token and verify: `coolify context set-token <name> <new-token> && coolify context verify`

### Issue #4: Table Rendering Issues with Wide Output
**Error**: Misaligned or truncated columns
**Source**: https://github.com/coollabsio/coolify-cli/issues/54
**Prevention**: Use `--format json` or `--format pretty` for reliable output.

### Issue #5: Windows Config File Not Found
**Error**: Config file not found on Windows
**Prevention**: Ensure directory exists: `%USERPROFILE%\.config\coolify\`. The CLI stores config at `%USERPROFILE%\.config\coolify\config.json`.

---

## Global Flags Reference

| Flag | Short | Purpose |
|------|-------|---------|
| `--context` | | Use specific context |
| `--host` | | Override hostname |
| `--token` | | Override auth token |
| `--format` | | Output: table/json/pretty |
| `--show-sensitive` | `-s` | Show secrets in output |
| `--force` | `-f` | Skip confirmations |
| `--debug` | | Enable debug logging |
