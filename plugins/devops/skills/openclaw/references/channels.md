# OpenClaw Messaging Channels

## Channel Overview

| Channel | Library | DM Policy | Config Mode |
|---------|---------|-----------|-------------|
| Telegram | grammY | pairing/allow/deny | Merge |
| Discord | discord.js | pairing/allow/deny | Merge |
| Slack | Bolt SDK | pairing/allow/deny | Merge |
| WhatsApp | Baileys | pairing/allow/deny | **Full-overwrite** |
| Google Chat | Chat API | - | JSON-only |
| Signal | signal-cli | - | JSON-only |
| iMessage | BlueBubbles | - | JSON-only |

**Config modes**:
- **Merge**: env vars layer onto existing JSON config
- **Full-overwrite**: entire channel block replaced when enabled via env
- **JSON-only**: too complex for env vars, use JSON config file

## Telegram Setup

### Step 1: Create bot via BotFather

1. Message `@BotFather` on Telegram
2. Send `/newbot`
3. Choose name and username
4. Copy the bot token

### Step 2: Configure environment

```bash
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_DM_POLICY=pairing    # pairing: pair via code, allow: anyone, deny: block all
TELEGRAM_ALLOW_FROM=12345678  # comma-separated Telegram user IDs (optional filter)
```

### Step 3: Optional settings

```bash
TELEGRAM_REPLY_TO_MODE=first        # first/last/all - which message to reply to
TELEGRAM_CHUNK_MODE=length          # length: split by chars, message: split by message
TELEGRAM_TEXT_CHUNK_LIMIT=4000      # max characters per message (Telegram limit: 4096)
TELEGRAM_STREAM_MODE=partial        # partial: edit message as tokens arrive, full: send complete
```

### Pairing mode

When `TELEGRAM_DM_POLICY=pairing`:
1. User messages bot
2. Bot responds with pairing code
3. User enters code in OpenClaw dashboard
4. Future messages are processed

## Discord Setup

### Step 1: Create Discord Application

1. Go to https://discord.com/developers/applications
2. Click "New Application"
3. Go to Bot tab > Add Bot
4. Copy bot token
5. Enable "Message Content Intent" under Privileged Gateway Intents

### Step 2: Invite bot to server

Generate invite URL with permissions:
- Read Messages/View Channels
- Send Messages
- Read Message History
- Attach Files

### Step 3: Configure environment

```bash
DISCORD_BOT_TOKEN=your-discord-bot-token
DISCORD_DM_POLICY=pairing
DISCORD_TEXT_CHUNK_LIMIT=2000     # Discord limit: 2000 chars
DISCORD_MEDIA_MAX_MB=8            # Discord file size limit
DISCORD_HISTORY_LIMIT=20          # messages to include as context
```

## Slack Setup

### Step 1: Create Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App" > "From scratch"
3. Enable Socket Mode (Settings > Socket Mode)
4. Generate App-Level Token with `connections:write` scope
5. Add Bot Token Scopes:
   - `chat:write`
   - `channels:history`
   - `groups:history`
   - `im:history`
   - `files:read`
   - `files:write`
6. Install app to workspace
7. Copy Bot Token and App Token

### Step 2: Configure environment

```bash
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_TEXT_CHUNK_LIMIT=4000
SLACK_MEDIA_MAX_MB=20
SLACK_HISTORY_LIMIT=50
```

### Step 3: Enable Events

Subscribe to bot events:
- `message.channels`
- `message.groups`
- `message.im`
- `app_mention`

## WhatsApp Setup

**WARNING**: WhatsApp uses full-overwrite mode. When `WHATSAPP_ENABLED=true`, set ALL WhatsApp variables you need. Any unset variables revert to defaults.

### Step 1: Enable WhatsApp

```bash
WHATSAPP_ENABLED=true
WHATSAPP_DM_POLICY=pairing
WHATSAPP_ALLOW_FROM=+1234567890    # E.164 format, comma-separated
WHATSAPP_MEDIA_MAX_MB=50
```

### Step 2: Pair device

1. Launch OpenClaw
2. Check logs for QR code: `docker logs openclaw`
3. Open WhatsApp > Settings > Linked Devices > Link a Device
4. Scan QR code from logs

### Important notes

- WhatsApp Web connection can be flaky - expect occasional reconnections
- Session data stored in `/data/.openclaw/` - persist this volume
- Phone must stay connected to internet (WhatsApp limitation)

## Channel Access Policies

All channels support three DM policies:

| Policy | Behavior |
|--------|----------|
| `pairing` | User must pair via code first (default, most secure) |
| `allow` | Accept messages from anyone (or filtered by allow list) |
| `deny` | Block all direct messages |

### Allow lists

Filter who can message the bot:

```bash
# Telegram: user IDs
TELEGRAM_ALLOW_FROM=12345678,87654321

# WhatsApp: phone numbers (E.164)
WHATSAPP_ALLOW_FROM=+1234567890,+0987654321
```

## Multi-Channel Example

```bash
# Core
OPENCLAW_GATEWAY_BIND=loopback
AUTH_PASSWORD=strong-password
OPENCLAW_GATEWAY_TOKEN=your-token
ANTHROPIC_API_KEY=sk-ant-your-key

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_DM_POLICY=allow
TELEGRAM_ALLOW_FROM=12345678

# Discord
DISCORD_BOT_TOKEN=your-discord-token
DISCORD_DM_POLICY=pairing

# Slack
SLACK_BOT_TOKEN=xoxb-your-token
SLACK_APP_TOKEN=xapp-your-token
```

## Troubleshooting Channels

```bash
# Check channel status
docker exec openclaw openclaw status --all

# Diagnose issues
docker exec openclaw openclaw doctor --fix

# View channel-specific logs
docker logs openclaw 2>&1 | grep -i telegram
docker logs openclaw 2>&1 | grep -i discord
docker logs openclaw 2>&1 | grep -i slack
docker logs openclaw 2>&1 | grep -i whatsapp
```

Common issues:
- **Bot not responding**: Check token validity, verify OAuth scopes (Slack/Discord)
- **"Not authorized"**: Check DM policy and allow list configuration
- **Messages truncated**: Adjust `*_TEXT_CHUNK_LIMIT` for the channel
- **Media fails**: Check `*_MEDIA_MAX_MB` limits vs provider limits
