# OpenClaw Configuration Reference

## Configuration Merge Order

OpenClaw uses a three-tier system (lowest to highest priority):

1. **Custom JSON file** (`OPENCLAW_CUSTOM_CONFIG`) - Base configuration
2. **Persisted state** from previous runs - Saved by gateway
3. **Environment variables** - Highest priority, overrides everything

**Key behaviors**:
- API keys: environment-only (never in JSON config)
- Arrays: replace (not concatenate) during merge
- WhatsApp: full-overwrite when `WHATSAPP_ENABLED=true`
- Other channels (Telegram/Discord/Slack): merge mode
- Group/guild configuration: JSON-only (too complex for env vars)
- Complex keys (`presets`, `mappings`, `transformsDir`): JSON-only

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OPENCLAW_GATEWAY_BIND` | **CRITICAL**: Must be `loopback` | `loopback` |
| `AUTH_PASSWORD` | nginx basic auth password | `strong-password` |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway API token | `openssl rand -hex 32` |
| One of `*_API_KEY` | At least one AI provider | `sk-ant-...` |

## AI Provider Variables

| Variable | Provider |
|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI GPT |
| `GEMINI_API_KEY` | Google Gemini |
| `XAI_API_KEY` | xAI Grok |
| `GROQ_API_KEY` | Groq |
| `MISTRAL_API_KEY` | Mistral |
| `CEREBRAS_API_KEY` | Cerebras |
| `VENICE_API_KEY` | Venice |
| `OPENROUTER_API_KEY` | OpenRouter (multi-provider) |
| `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` | AWS Bedrock |
| `OLLAMA_BASE_URL` | Ollama (local models) |
| `COPILOT_GITHUB_TOKEN` | GitHub Copilot |

**Model selection**: Set `OPENCLAW_PRIMARY_MODEL` to override automatic provider priority.

## Gateway Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_GATEWAY_BIND` | varies | `loopback` / `lan` / `tailnet` / `auto` |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Internal gateway port |
| `PORT` | `8080` | External nginx port |
| `AUTH_USERNAME` | `admin` | nginx basic auth username |
| `AUTH_PASSWORD` | - | nginx basic auth password |
| `OPENCLAW_GATEWAY_TOKEN` | auto | Bearer token for API |

## Storage Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_STATE_DIR` | `/data/.openclaw` | Mutable state storage |
| `OPENCLAW_WORKSPACE_DIR` | `/data/workspace` | Workspace data |
| `OPENCLAW_HOME_VOLUME` | - | Named Docker volume for home |
| `OPENCLAW_CUSTOM_CONFIG` | - | Custom JSON config file path |

## Docker Build Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_DOCKER_APT_PACKAGES` | - | Space-separated APT packages |
| `OPENCLAW_EXTRA_MOUNTS` | - | Comma-separated bind mounts |

## Persistent Storage Structure

```
/data/
├── .openclaw/              # Configuration and state
│   ├── config.json         # Persisted configuration
│   └── agents/
│       └── <agentId>/
│           └── sessions/   # Per-agent session data
└── workspace/              # User workspace files
```

## JSON Configuration File

For settings too complex for environment variables, use a JSON config:

```bash
export OPENCLAW_CUSTOM_CONFIG=/data/openclaw-config.json
```

```json
{
  "agents": {
    "defaults": {
      "model": "claude-sonnet-4-5-20250929",
      "sandbox": false
    }
  },
  "channels": {
    "telegram": {
      "groups": {
        "-1001234567890": {
          "model": "gpt-4o",
          "systemPrompt": "You are a helpful assistant for this group."
        }
      }
    }
  }
}
```

**Important**: API keys should NEVER go in the JSON file. Always use env vars.

## Verifying Configuration

```bash
# Check active environment
docker exec openclaw env | grep -E 'OPENCLAW|AUTH|API_KEY|PORT'

# Check gateway config
docker exec openclaw openclaw config show

# Verify binding (CRITICAL)
docker exec openclaw ss -tlnp | grep 18789
# Expected: 127.0.0.1:18789
# DANGEROUS: 0.0.0.0:18789
```
