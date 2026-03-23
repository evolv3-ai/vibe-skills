---
name: hermes-agent
description: >
  Deploy and manage Hermes Agent (Nous Research) on remote servers. Self-improving AI agent
  with built-in learning loop, multi-platform messaging gateway (Telegram, Discord, Slack,
  WhatsApp, Signal, Mattermost), cron scheduling, MCP integration, and persistent memory.
  Supports Docker, bare-metal, and systemd deployments.

  Use when: deploying hermes-agent to a server, configuring hermes messaging gateway,
  managing hermes installations, troubleshooting hermes issues, migrating from OpenClaw
  to hermes, setting up hermes cron jobs, or any task involving hermes-agent deployment
  and operations.

  Keywords: hermes, hermes-agent, nous research, AI agent, messaging gateway,
  self-improving agent, openclaw migration.
compatibility: claude-code-only
---

# Hermes Agent — Deployment & Management

Hermes Agent is a self-improving AI agent by Nous Research. It creates skills from experience,
searches past conversations, and builds user models across sessions.

- **Repo**: github.com/NousResearch/hermes-agent (11k+ stars, MIT license)
- **Docs**: hermes-agent.nousresearch.com/docs/
- **Skills Hub**: agentskills.io

## Quick Reference

| Item | Value |
|------|-------|
| Config dir | `~/.hermes/` |
| Config file | `~/.hermes/config.yaml` |
| Secrets | `~/.hermes/.env` |
| Identity | `~/.hermes/SOUL.md` |
| Logs | `~/.hermes/logs/` |
| Sessions | `~/.hermes/sessions/` |
| Skills | `~/.hermes/skills/` |
| Memories | `~/.hermes/memories/` |
| Cron jobs | `~/.hermes/cron/` |
| Gateway config | `~/.hermes/gateway.json` |

## Installation

### Quick Install (Linux/macOS/WSL2)

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
source ~/.bashrc
hermes setup
```

Auto-installs: uv, Python 3.11, Node.js v22, ripgrep, ffmpeg. Only prerequisite: **git**.
Native Windows not supported — use WSL2.

### Manual Install

```bash
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv venv --python 3.11
export VIRTUAL_ENV="$(pwd)/venv"
uv pip install -e ".[all]"
uv pip install -e "./mini-swe-agent"
npm install  # optional, for MCP/browser tools

mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,whatsapp/session}
cp cli-config.yaml.example ~/.hermes/config.yaml
touch ~/.hermes/.env
chmod 600 ~/.hermes/.env

mkdir -p ~/.local/bin
ln -sf "$(pwd)/venv/bin/hermes" ~/.local/bin/hermes
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Docker Deployment

```bash
docker build -t hermes-agent:local .
docker run --rm -it \
  -v "$PWD:/home/agent/workspace" \
  -v "$HOME/.hermes:/home/agent/.hermes" \
  hermes-agent:local hermes
```

Runs as `agent` user. Mount `~/.hermes` for persistence.

Community Docker images:
- [xmbshwll/hermes-agent-docker](https://github.com/xmbshwll/hermes-agent-docker)
- [Crustocean/hermes-agent-template](https://github.com/Crustocean/hermes-agent-template)
- [ellickjohnson/portainer-stack-hermes](https://github.com/ellickjohnson/portainer-stack-hermes)

### Verify

```bash
hermes doctor        # Diagnose issues
hermes doctor --fix  # Auto-repair
hermes status --deep # Full status check
```

## Configuration

Full config reference: [references/configuration.md](references/configuration.md)

### Essential First Steps

```bash
hermes model          # Select LLM provider/model
hermes tools          # Configure enabled tools
hermes config check   # Check for missing options
hermes config migrate # Add options introduced in updates
```

### Minimum `.env`

```bash
# Pick one provider
ANTHROPIC_API_KEY=sk-ant-...
# OR
OPENROUTER_API_KEY=sk-or-...
```

### Config Management

```bash
hermes config show        # View current
hermes config edit        # Open in editor
hermes config set KEY VAL # Set value (auto-routes secrets to .env)
hermes config path        # Print config file path
```

## Messaging Gateway

Full gateway reference: [references/messaging.md](references/messaging.md)

### Quick Setup

```bash
hermes gateway setup     # Interactive platform config
hermes gateway install   # Install as user systemd service
sudo loginctl enable-linger $USER  # Survive logout
hermes gateway start
hermes gateway status
```

### Supported Platforms

Telegram, Discord, Slack, WhatsApp, Signal, SMS, Email, Home Assistant,
Mattermost, Matrix, DingTalk, webhooks.

### Security (Critical)

```bash
# Set explicit allowlists in .env — NEVER use GATEWAY_ALLOW_ALL_USERS=true
TELEGRAM_ALLOWED_USERS=123456789,987654321
DISCORD_ALLOWED_USERS=123456789012345678

# DM pairing for unknown users
hermes pairing approve telegram XKGH5N7P
hermes pairing list
hermes pairing revoke telegram 123456789
```

## OpenClaw Migration

Hermes auto-detects `~/.openclaw` during setup.

```bash
hermes claw migrate              # Interactive full migration
hermes claw migrate --dry-run    # Preview first
hermes claw migrate --overwrite  # Overwrite conflicts
```

Migrates: SOUL.md, memories, skills, allowlists, messaging settings, API keys, TTS files.

## Common Operations

| Task | Command |
|------|---------|
| Interactive chat | `hermes` |
| One-shot query | `hermes chat -q "..."` |
| Change model | `hermes model` |
| Update | `hermes update` |
| Resume session | `hermes -c` or `hermes -r <id>` |
| Browse skills | `hermes skills browse` |
| Install skill | `hermes skills install <name>` |
| Cron jobs | `hermes cron list` / `hermes cron create` |
| Analytics | `hermes insights --days 7` |
| Uninstall | `hermes uninstall --full --yes` |

## Systemd (Production)

```bash
# User service
hermes gateway install
sudo loginctl enable-linger $USER
journalctl --user -u hermes-gateway -f

# System service (starts at boot)
sudo hermes gateway install --system
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `hermes: command not found` | `source ~/.bashrc`, check `~/.local/bin` in PATH |
| Missing deps | `hermes doctor --fix` |
| Gateway won't start | Check `~/.hermes/logs/gateway.log` |
| Auth failure | `hermes login --provider <name>` or verify `.env` |
| Stale config after update | `hermes config migrate` |
| Migration issues | `hermes claw migrate --dry-run` first |

## Profile Integration

After deploying to a remote server, update the device profile:

1. Add `hermes-agent` to `profile.servers[].apps[]`
2. Record deployment in `profile.deployments{}`
3. Log via `log_admin_event`
4. Store outcome in SimpleMem with `devops:deployment-coordinator` speaker
