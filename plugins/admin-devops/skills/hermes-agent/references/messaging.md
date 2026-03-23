# Hermes Agent Messaging Gateway Reference

## Setup & Management

```bash
hermes gateway setup        # Interactive platform config
hermes gateway run          # Run in foreground
hermes gateway install      # Install as user service (Linux/macOS)
sudo hermes gateway install --system  # System service (Linux)
hermes gateway start        # Start installed service
hermes gateway stop         # Stop service
hermes gateway restart      # Restart service
hermes gateway status       # Show status
hermes gateway uninstall    # Remove service
```

## Supported Platforms

Telegram, Discord, Slack, WhatsApp, Signal, SMS, Email,
Home Assistant, Mattermost, Matrix, DingTalk, webhooks.

Each platform gets a dedicated toolset with full tools including terminal access.

## Service Installation

### Linux (systemd)

```bash
# User service (recommended)
hermes gateway install
sudo loginctl enable-linger $USER  # Survive logout
journalctl --user -u hermes-gateway -f

# System service (starts at boot)
sudo hermes gateway install --system
journalctl -u hermes-gateway -f
```

### macOS (launchd)

```bash
hermes gateway install
launchctl start ai.hermes.gateway
launchctl stop ai.hermes.gateway
tail -f ~/.hermes/logs/gateway.log
```

## Security

### Authorization Check Order

1. Per-platform allow-all flag (e.g., `DISCORD_ALLOW_ALL_USERS=true`)
2. DM pairing approved list
3. Platform-specific allowlists (`TELEGRAM_ALLOWED_USERS`)
4. Global allowlist (`GATEWAY_ALLOWED_USERS`)
5. Global allow-all (`GATEWAY_ALLOW_ALL_USERS`)
6. **Default: deny**

### Allowlists (in `~/.hermes/.env`)

```bash
TELEGRAM_ALLOWED_USERS=123456789,987654321
DISCORD_ALLOWED_USERS=123456789012345678
SIGNAL_ALLOWED_USERS=+15554567,+15556543
SLACK_ALLOWED_USERS=U123456
WHATSAPP_ALLOWED_USERS=+15554567
SMS_ALLOWED_USERS=+15554567
EMAIL_ALLOWED_USERS=trusted@example.com
MATTERMOST_ALLOWED_USERS=userid
MATRIX_ALLOWED_USERS=@alice:matrix.org
DINGTALK_ALLOWED_USERS=user-id-1

# Cross-platform fallback
GATEWAY_ALLOWED_USERS=123456789,987654321

# DANGEROUS — never in production
GATEWAY_ALLOW_ALL_USERS=true
```

### DM Pairing

Unknown users receive a one-time pairing code. Approve from CLI:

```bash
hermes pairing approve telegram XKGH5N7P
hermes pairing list
hermes pairing revoke telegram 123456789
hermes pairing clear-pending
```

Pairing security:
- 8-character codes from 32-char unambiguous alphabet
- Cryptographic randomness (`secrets.choice()`)
- 1-hour expiration
- Rate limit: 1 request/user/10 min
- Max 3 pending codes per platform
- 5 failed attempts → 1-hour lockout
- File permissions: `chmod 0600` on pairing data

## Session Management

### Reset Policies (`~/.hermes/gateway.json`)

```json
{
  "reset_by_platform": {
    "telegram": { "mode": "idle", "idle_minutes": 240 },
    "discord": { "mode": "idle", "idle_minutes": 60 }
  }
}
```

Modes: `daily` (default 4:00 AM reset), `idle` (default 1440 min), `both` (whichever first).

### Privacy

```yaml
# In config.yaml
privacy:
  redact_pii: false             # Gateway only
group_sessions_per_user: true   # Per-user isolation in groups
unauthorized_dm_behavior: pair  # pair|ignore
```

## In-Chat Commands

| Command | Function |
|---------|----------|
| `/new` or `/reset` | Fresh conversation |
| `/model [provider:model]` | Display/change model |
| `/provider` | Show providers with auth status |
| `/personality [name]` | Set personality |
| `/retry` | Retry last message |
| `/undo` | Remove last exchange |
| `/status` | Session info |
| `/stop` | Interrupt running agent |
| `/approve` / `/deny` | Handle dangerous commands |
| `/voice [on\|off\|tts\|join\|leave\|status]` | Voice features |
| `/background <prompt>` | Run async task |
| `/reload-mcp` | Reload MCP servers |
| `/insights [days]` | Usage analytics |
| `/compress` | Compress context |
| `/usage` | Token usage |
| `/skills` | Browse skills |

## Background Sessions

`/background <prompt>` spawns a separate agent instance. Main chat stays responsive.
Results return prefixed with "✅ Background task complete" or "❌ Background task failed."

Configure notifications:
```yaml
display:
  background_process_notifications: all  # all|result|error|off
```

Or via env: `HERMES_BACKGROUND_NOTIFICATIONS=result`

## Tool Progress in Chat

```yaml
display:
  tool_progress: all  # off|new|all|verbose
```

Status indicators: 💻 terminal, 🔍 search, 📄 file, 🐍 code.

## Working Directory

| Context | Default | Override |
|---------|---------|----------|
| CLI | Current directory | — |
| Gateway | `~` (home) | `MESSAGING_CWD` env var |
| Docker/SSH/Modal | User home in container | `TERMINAL_CWD` env var |

## Production Checklist

1. Set explicit per-platform allowlists
2. Never use `GATEWAY_ALLOW_ALL_USERS=true`
3. Use Docker terminal backend for isolation
4. `chmod 600 ~/.hermes/.env`
5. Enable DM pairing
6. Audit `command_allowlist` regularly
7. Set `MESSAGING_CWD` to a safe directory
8. Run as non-root user
9. Monitor `~/.hermes/logs/`
10. Keep hermes updated (`hermes update`)
