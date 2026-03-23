# Hermes Agent CLI Reference

## Global Options

```
hermes [global-options] <command> [subcommand/options]
```

| Flag | Description |
|------|-------------|
| `--version`, `-V` | Show version |
| `--resume <session>`, `-r` | Resume session by ID or title |
| `--continue [name]`, `-c` | Resume most recent (or matching) session |
| `--worktree`, `-w` | Isolated git worktree |
| `--yolo` | Bypass command approval |
| `--pass-session-id` | Include session ID in system prompt |

## Commands

### hermes chat

```bash
hermes chat [options]
hermes chat -q "one-shot query"
hermes chat -m claude-sonnet-4-6 -t terminal,web
```

| Flag | Description |
|------|-------------|
| `-q`, `--query "..."` | One-shot non-interactive |
| `-m`, `--model <model>` | Override model |
| `-t`, `--toolsets <csv>` | Enable toolsets |
| `--provider <name>` | Force provider |
| `-v`, `--verbose` | Verbose output |
| `-Q`, `--quiet` | Programmatic mode |
| `--worktree` | Git worktree isolation |
| `--checkpoints` | Filesystem checkpoints |
| `--yolo` | Skip approvals |

### hermes model

Interactive provider + model selector. Saves to config.yaml.

### hermes gateway

| Subcommand | Description |
|------------|-------------|
| `run` | Run in foreground |
| `start` | Start installed service |
| `stop` | Stop service |
| `restart` | Restart service |
| `status [--system]` | Show status |
| `install [--system]` | Install as service |
| `uninstall` | Remove service |
| `setup` | Interactive platform config |

### hermes setup

```bash
hermes setup [section] [--non-interactive] [--reset]
```

Sections: `model`, `terminal`, `gateway`, `tools`, `agent`

### hermes config

| Subcommand | Description |
|------------|-------------|
| `show` | View current values |
| `edit` | Open in editor |
| `set <key> <value>` | Set value (auto-routes secrets) |
| `path` | Print config file path |
| `env-path` | Print .env path |
| `check` | Check for missing options |
| `migrate` | Add new options interactively |

### hermes doctor

```bash
hermes doctor [--fix]
```

### hermes status

```bash
hermes status [--all] [--deep]
```

### hermes pairing

| Subcommand | Description |
|------------|-------------|
| `list` | Show pending/approved users |
| `approve <platform> <code>` | Approve pairing code |
| `revoke <platform> <user-id>` | Revoke access |
| `clear-pending` | Clear pending codes |

### hermes skills

| Subcommand | Description |
|------------|-------------|
| `browse` | Paginated browser |
| `search` | Search registries |
| `install [--source <reg>]` | Install skill |
| `inspect` | Preview without installing |
| `list` | List installed |
| `check` | Check for updates |
| `update` | Reinstall with changes |
| `audit` | Re-scan installed |
| `uninstall` | Remove skill |
| `publish` | Publish to registry |
| `snapshot` | Export/import configs |
| `tap` | Manage custom sources |
| `config` | Enable/disable per platform |

### hermes cron

| Subcommand | Description |
|------------|-------------|
| `list` | Show scheduled jobs |
| `create` / `add` | Create job (`--skill` supported) |
| `edit` | Update job |
| `pause` | Pause without deleting |
| `resume` | Resume paused job |
| `run` | Trigger on next tick |
| `remove` | Delete job |
| `status` | Scheduler status |
| `tick` | Run due jobs once and exit |

### hermes sessions

| Subcommand | Description |
|------------|-------------|
| `list` | List recent |
| `browse` | Interactive picker |
| `export <output> [--session-id]` | Export JSONL |
| `delete <id>` | Delete one |
| `prune` | Delete old sessions |
| `stats` | Store statistics |
| `rename <id> <title>` | Set/change title |

### hermes insights

```bash
hermes insights [--days N] [--source platform]
```

### hermes claw

```bash
hermes claw migrate [--dry-run] [--preset user-data] [--overwrite]
```

### hermes login / logout

```bash
hermes login [--provider nous|openai-codex] [--no-browser] [--timeout N]
hermes logout [--provider nous|openai-codex]
```

### hermes tools

```bash
hermes tools [--summary]
```

### hermes honcho

| Subcommand | Description |
|------------|-------------|
| `setup` | Interactive setup |
| `status` | Config and connection |
| `sessions` | List mappings |
| `map` | Map directory to session |
| `peer` | Show/update peer names |
| `mode` | Show/set memory mode (hybrid\|honcho\|local) |
| `tokens` | Token budgets |
| `identity` | Seed/show AI peer identity |
| `migrate` | Migration guide |

### Maintenance

```bash
hermes version              # Version info
hermes update               # Pull latest + reinstall
hermes uninstall [--full] [--yes]  # Remove (--full deletes data)
```
