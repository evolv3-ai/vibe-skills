# Coolify CLI Command Reference

Complete reference for all commands, subcommands, arguments, and flags.

**Source**: https://github.com/coollabsio/coolify-cli

---

## Table of Contents

- [Context Commands](#context-commands)
- [Server Commands](#server-commands)
- [Application Commands](#application-commands)
- [Application Environment Variables](#application-environment-variables)
- [Application Deployments](#application-deployments)
- [Deploy Commands](#deploy-commands)
- [Database Commands](#database-commands)
- [Database Backup Commands](#database-backup-commands)
- [Service Commands](#service-commands)
- [Service Environment Variables](#service-environment-variables)
- [GitHub App Commands](#github-app-commands)
- [Team Commands](#team-commands)
- [Private Key Commands](#private-key-commands)
- [Project Commands](#project-commands)
- [Resource Commands](#resource-commands)
- [Utility Commands](#utility-commands)
- [Global Flags](#global-flags)

---

## Context Commands

Manage multiple Coolify instances. Each context stores a name, URL, and API token.

### coolify context list
List all configured contexts. Shows name, URL, and default status.

### coolify context add \<name\> \<url\> \<token\>
Add a new Coolify instance.
- **name** (required): Identifier for this context
- **url** (required): Full URL, e.g. `https://coolify.example.com`
- **token** (required): API token from `/security/api-tokens`

Flags:
- `-d` - Set as default context

### coolify context get [name]
Show details of a context. Defaults to current context if name omitted.

### coolify context use \<name\>
Switch active context.

### coolify context set-default \<name\>
Set the default context.

### coolify context set-token \<name\> \<token\>
Update API token for an existing context.

### coolify context update \<name\> [flags]
Update context settings.

Flags:
- `--url <url>` - New URL
- `--token <token>` - New token

### coolify context delete \<name\>
Remove a context.

### coolify context verify
Test connection to current context. Returns instance info on success, error on failure.

### coolify context version
Show Coolify instance version for current context.

---

## Server Commands

### coolify server list
List all servers. Shows name, IP, status.

### coolify server get \<uuid\>
Get server details.

Flags:
- `--resources` - Include resource usage information

### coolify server add [flags]
Add a new server.

Flags:
- `--name <name>` - Server name
- `--ip <ip>` - Server IP address
- `--private-key-uuid <uuid>` - SSH key UUID
- `--user <user>` - SSH user (default: root)
- `--port <port>` - SSH port (default: 22)
- `--validate` - Validate server after adding

### coolify server remove \<uuid\>
Remove a server.

### coolify server validate \<uuid\>
Validate server configuration and connectivity.

### coolify server domains \<uuid\>
List domains configured on a server.

---

## Application Commands

### coolify app list
List all applications. Shows name, UUID, status, FQDN.

### coolify app get \<uuid\>
Get application details including configuration, environment, and deployment info.

### coolify app create [flags]
Create a new application.

Flags:
- `--server-uuid <uuid>` - Target server
- `--project-uuid <uuid>` - Target project
- `--environment-name <name>` - Target environment
- `--type <type>` - Application type
- `--name <name>` - Application name

### coolify app update \<uuid\> [flags]
Update application settings.

### coolify app delete \<uuid\>
Delete an application.

### coolify app start \<uuid\>
Start/deploy application (triggers build and deployment).

### coolify app stop \<uuid\>
Stop application containers.

### coolify app restart \<uuid\>
Restart application containers without rebuild.

### coolify app logs \<uuid\>
View application logs.

Flags:
- `--lines <n>` - Number of lines (default: 50)
- `--follow` - Stream logs in real-time
- `--debug` - Include debug information

---

## Application Environment Variables

### coolify app env list \<uuid\>
List all environment variables for an application.

### coolify app env get \<uuid\> --key \<key\>
Get a specific environment variable.

### coolify app env create \<uuid\> --key \<key\> --value \<value\>
Create a new environment variable.

Optional flags:
- `--is-preview` - Variable for preview deployments only
- `--is-build` - Variable available during build

### coolify app env update \<uuid\> --key \<key\> --value \<value\>
Update an existing environment variable.

### coolify app env delete \<uuid\> --key \<key\>
Delete an environment variable.

### coolify app env sync \<uuid\> --file \<path\>
Sync environment variables from a `.env` file.

**IMPORTANT**: Creates and updates only. Does NOT delete variables absent from the file. One-directional merge.

---

## Application Deployments

### coolify app deployments list \<uuid\>
List deployment history for an application.

### coolify app deployments get \<deployment-uuid\>
Get specific deployment details.

### coolify app deployments logs \<deployment-uuid\>
View build/deployment logs.

Flags:
- `--debuglogs` - Include debug-level log entries

---

## Deploy Commands

Top-level deployment commands. **Note**: `deploy` is NOT a subcommand of `app`.

### coolify deploy uuid \<uuid\>
Deploy by application UUID.

### coolify deploy name \<app-name\>
Deploy by application name.

### coolify deploy batch \<uuid1\>,\<uuid2\>,\<uuid3\>
Deploy multiple applications simultaneously. UUIDs separated by commas (no spaces).

### coolify deploy list
List recent deployments across all applications.

### coolify deploy get \<deployment-uuid\>
Get deployment details.

### coolify deploy cancel \<deployment-uuid\>
Cancel a running deployment.

---

## Database Commands

### coolify database list
List all databases.

### coolify database get \<uuid\>
Get database details.

### coolify database create [flags]
Create a new database.

Required flags:
- `--server-uuid <uuid>` - Target server
- `--type <type>` - Database type

Supported types: `postgres`, `mysql`, `mariadb`, `mongodb`, `redis`, `keydb`, `dragonfly`, `clickhouse`

Optional flags:
- `--name <name>` - Database name
- `--project-uuid <uuid>` - Target project
- `--environment-name <name>` - Target environment

### coolify database update \<uuid\> [flags]
Update database settings.

### coolify database delete \<uuid\>
Delete a database.

### coolify database start \<uuid\>
Start database container.

### coolify database stop \<uuid\>
Stop database container.

### coolify database restart \<uuid\>
Restart database container.

---

## Database Backup Commands

### coolify database backup list \<db-uuid\>
List backup configurations for a database.

### coolify database backup create \<db-uuid\> [flags]
Create a backup configuration.

Flags:
- `--frequency <schedule>` - Backup frequency (e.g., "daily", "weekly", cron expression)
- `--enabled` - Enable the backup schedule
- `--s3-storage-id <id>` - S3-compatible storage for remote backups
- `--retention-days-locally <n>` - Local retention in days
- `--save-s3` - Save backups to S3

### coolify database backup update \<backup-uuid\> [flags]
Update backup configuration.

Flags: Same as create.

### coolify database backup delete \<backup-uuid\>
Delete a backup configuration.

### coolify database backup trigger \<backup-uuid\>
Trigger an immediate backup.

### coolify database backup executions \<backup-uuid\>
List backup execution history (past runs).

### coolify database backup delete-execution \<execution-uuid\>
Delete a specific backup execution record.

---

## Service Commands

### coolify service list
List all one-click services.

### coolify service get \<uuid\>
Get service details.

### coolify service start \<uuid\>
Start a service.

### coolify service stop \<uuid\>
Stop a service.

### coolify service restart \<uuid\>
Restart a service.

### coolify service delete \<uuid\>
Delete a service.

---

## Service Environment Variables

### coolify service env list \<uuid\>
List environment variables for a service.

### coolify service env get \<uuid\> --key \<key\>
Get a specific service variable.

### coolify service env create \<uuid\> --key \<key\> --value \<value\>
Create a service environment variable.

### coolify service env update \<uuid\> --key \<key\> --value \<value\>
Update a service variable.

**KNOWN BUG**: Returns 404 (issue #48). Workaround: delete + create.

### coolify service env delete \<uuid\> --key \<key\>
Delete a service variable.

### coolify service env sync \<uuid\> --file \<path\>
Sync service variables from `.env` file.

---

## GitHub App Commands

### coolify github list
List GitHub App integrations.

### coolify github get \<id\>
Get GitHub App details.

### coolify github create [flags]
Create a GitHub App integration.

Flags:
- `--name <name>` - App name
- `--app-id <id>` - GitHub App ID
- `--private-key-uuid <uuid>` - SSH key for authentication
- `--webhook-secret <secret>` - Webhook secret
- `--is-system-wide` - System-wide (cloud) vs local

### coolify github update \<id\> [flags]
Update GitHub App configuration.

### coolify github delete \<id\>
Remove a GitHub App integration.

### coolify github repos \<id\>
List repositories accessible to the GitHub App.

### coolify github branches \<id\> --repo \<owner/repo\>
List branches for a specific repository.

---

## Team Commands

### coolify team list
List all teams.

### coolify team get \<id\>
Get team details.

### coolify team current
Show current active team.

### coolify team members list
List team members.

---

## Private Key Commands

### coolify private-key list
List all SSH keys.

### coolify private-key get \<uuid\>
Get key details (fingerprint, name, creation date).

### coolify private-key add [flags]
Add a new SSH key.

Flags:
- `--name <name>` - Key name/label
- `--private-key <key>` - Key content (inline)
- `--file <path>` - Key file path (alternative to inline)

**Note**: Keys must be passwordless (passphrase not supported).

### coolify private-key remove \<uuid\>
Remove an SSH key.

---

## Project Commands

### coolify projects list
List all projects.

### coolify projects get \<uuid\>
Get project details including environments.

---

## Resource Commands

### coolify resources list
List all resources (applications, databases, services) across all projects.

---

## Utility Commands

### coolify update
Update CLI to the latest version.

### coolify config
Show config file location and current settings.

### coolify completion \<shell\>
Generate shell completions.

Supported shells: `bash`, `zsh`, `fish`, `powershell`

```bash
coolify completion bash > /etc/bash_completion.d/coolify
coolify completion zsh > "${fpath[1]}/_coolify"
coolify completion fish > ~/.config/fish/completions/coolify.fish
coolify completion powershell > coolify.ps1
```

### coolify version
Show CLI version.

### coolify help [command]
Show help for any command.

---

## Global Flags

Available on all commands:

| Flag | Short | Type | Description |
|------|-------|------|-------------|
| `--context` | | string | Use a specific context instead of default |
| `--host` | | string | Override hostname/URL |
| `--token` | | string | Override authentication token |
| `--format` | | string | Output format: `table` (default), `json`, `pretty` |
| `--show-sensitive` | `-s` | bool | Display sensitive data (tokens, passwords) |
| `--force` | `-f` | bool | Skip confirmation prompts |
| `--debug` | | bool | Enable verbose debug logging |

**Override priority**: `--token`/`--host` flags > `--context` flag > default context settings.
