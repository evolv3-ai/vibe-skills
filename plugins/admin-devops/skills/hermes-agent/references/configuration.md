# Hermes Agent Configuration Reference

## Directory Structure

```
~/.hermes/
├── config.yaml          # Primary settings
├── .env                 # Secrets (API keys, tokens) — chmod 600
├── auth.json            # OAuth credentials
├── gateway.json         # Gateway session config
├── SOUL.md              # Agent identity/personality
├── memories/            # Persistent memory files
├── skills/              # Agent-created skills
├── cron/                # Scheduled jobs
├── sessions/            # Conversation sessions
├── logs/                # Error and gateway logs
├── pairing/             # DM pairing data
├── hooks/               # Custom hooks
├── image_cache/         # Cached images
├── audio_cache/         # Cached audio
└── whatsapp/session/    # WhatsApp session data
```

## Precedence (highest to lowest)

1. CLI arguments
2. `~/.hermes/config.yaml`
3. `~/.hermes/.env`
4. Built-in defaults

**Rule**: Secrets → `.env`. Everything else → `config.yaml`.
`hermes config set` auto-routes: API keys go to `.env`, other values to `config.yaml`.

## config.yaml Sections

### Model / Inference Provider

```yaml
model:
  provider: "anthropic"         # anthropic|openrouter|nous|copilot|zai|kimi-coding|minimax|alibaba|custom
  default: "claude-sonnet-4-6"  # Model name
  context_length: 200000        # Optional override
```

### Provider Routing (OpenRouter)

```yaml
provider_routing:
  sort: "throughput"            # price|throughput|latency
  only: ["anthropic"]           # Restrict to these providers
  ignore: ["deepinfra"]         # Exclude these
  order: ["anthropic", "google"]
  require_parameters: true
  data_collection: "deny"
```

Shortcut syntax: `modelname:nitro` (throughput), `modelname:floor` (price).

### Smart Model Routing

```yaml
smart_model_routing:
  enabled: true
  max_simple_chars: 160
  max_simple_words: 28
  cheap_model:
    provider: openrouter
    model: google/gemini-2.5-flash
```

### Fallback Model

```yaml
fallback_model:
  provider: openrouter
  model: anthropic/claude-sonnet-4
  base_url: ""
  api_key_env: MY_CUSTOM_KEY
```

### Terminal Backend

```yaml
terminal:
  backend: local                # local|docker|ssh|singularity|modal|daytona
  cwd: "."
  timeout: 180                  # seconds
  persistent_shell: true

  # Docker backend
  docker_image: "nikolaik/python-nodejs:python3.11-nodejs20"
  docker_mount_cwd_to_workspace: false
  docker_forward_env:
    - "GITHUB_TOKEN"
  docker_volumes:
    - "/host/path:/container/path"
    - "/data:/data:ro"
  container_cpu: 1
  container_memory: 5120        # MB
  container_disk: 51200         # MB
  container_persistent: true
```

Docker security flags (auto-applied): `--cap-drop ALL`, `--security-opt no-new-privileges`,
`--pids-limit 256`, `nosuid`/`noexec` on tmp mounts.

### Agent Behavior

```yaml
agent:
  max_turns: 90
  reasoning_effort: ""          # xhigh|high|medium|low|minimal|none

approval_mode: ask              # ask|smart|off
```

### Memory

```yaml
memory:
  memory_enabled: true
  user_profile_enabled: true
  memory_char_limit: 2200       # ~800 tokens
  user_char_limit: 1375         # ~500 tokens
```

### Context Compression

```yaml
compression:
  enabled: true
  threshold: 0.50               # Compress at 50% of context
  summary_model: "google/gemini-3-flash-preview"
  summary_provider: "auto"      # auto|openrouter|nous|codex|main
```

### Auxiliary Models

```yaml
auxiliary:
  vision:
    provider: "auto"
    model: "openai/gpt-4o"
    base_url: ""
    api_key: ""
    timeout: 30
  web_extract:
    provider: "auto"
    model: ""
  approval:
    provider: "auto"
    model: ""
```

### Display

```yaml
display:
  tool_progress: all            # off|new|all|verbose
  skin: default
  theme_mode: auto              # auto|light|dark
  personality: "helpful"        # helpful|technical|creative|kawaii|pirate|noir|...
  compact: false
  resume_display: full          # full|minimal
  bell_on_complete: false
  show_reasoning: false
  streaming: false
  background_process_notifications: all  # all|result|error|off
  show_cost: false
```

### TTS / Voice

```yaml
tts:
  provider: "edge"              # edge|elevenlabs|openai|neutts
  edge:
    voice: "en-US-AriaNeural"
  elevenlabs:
    voice_id: "pNInz6obpgDQGcFmaJgB"
    model_id: "eleven_multilingual_v2"
  openai:
    model: "gpt-4o-mini-tts"
    voice: "alloy"

stt:
  provider: "local"             # local|groq|openai
  local:
    model: "base"               # tiny|base|small|medium|large-v3

voice:
  record_key: "ctrl+b"
  max_recording_seconds: 120
  auto_tts: false
  silence_threshold: 200
  silence_duration: 3.0
```

### Streaming

```yaml
streaming:
  enabled: true
  edit_interval: 0.3
  buffer_threshold: 40
  cursor: " ▉"
```

### Browser

```yaml
browser:
  inactivity_timeout: 120
  record_sessions: false
```

### Code Execution

```yaml
code_execution:
  timeout: 300
  max_tool_calls: 50
```

### Delegation (Subagents)

```yaml
delegation:
  max_iterations: 50
  default_toolsets:
    - terminal
    - file
    - web
  model: ""
  provider: ""
```

### Privacy & Sessions

```yaml
privacy:
  redact_pii: false

group_sessions_per_user: true
unauthorized_dm_behavior: pair  # pair|ignore

human_delay:
  mode: "off"                   # off|natural|custom
  min_ms: 500
  max_ms: 2000
```

### Quick Commands

```yaml
quick_commands:
  status:
    type: exec
    command: systemctl status hermes-agent
  disk:
    type: exec
    command: df -h /
```

### Website Blocklist

```yaml
website_blocklist:
  enabled: false
  domains:
    - "*.internal.company.com"
  shared_files:
    - "/etc/hermes/blocked-sites.txt"
```

### Checkpoints

```yaml
checkpoints:
  enabled: false
  max_snapshots: 50
```

### Misc

```yaml
worktree: true                  # Git worktree isolation
```

## Environment Variables (.env)

### Provider API Keys

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...
COPILOT_GITHUB_TOKEN=gho_...
GH_TOKEN=...
GITHUB_TOKEN=...
GLM_API_KEY=...                 # z.ai
KIMI_API_KEY=...                # Moonshot
MINIMAX_API_KEY=...
DASHSCOPE_API_KEY=...           # Alibaba/Qwen
```

### Custom Endpoints

```bash
OPENAI_BASE_URL=http://localhost:8000/v1
OPENAI_API_KEY=...
LLM_MODEL=meta-llama/Llama-3.1-70B-Instruct
```

### Tool Keys

```bash
FIRECRAWL_API_KEY=fc-...
FIRECRAWL_API_URL=http://localhost:3002  # Self-hosted
FAL_KEY=...                     # Image generation
ELEVENLABS_API_KEY=...          # TTS
GROQ_API_KEY=...                # STT
BROWSERBASE_API_KEY=...
BROWSERBASE_PROJECT_ID=...
HONCHO_API_KEY=...              # User modeling
```

### Terminal Overrides

```bash
TERMINAL_SSH_HOST=my-server.example.com
TERMINAL_SSH_USER=ubuntu
TERMINAL_SSH_PERSISTENT=true
TERMINAL_LOCAL_PERSISTENT=false
TERMINAL_CWD=/workspace
TERMINAL_DOCKER_VOLUMES='["/host:/container"]'
MESSAGING_CWD=/home/myuser/projects
```

### Special Flags

```bash
HERMES_YOLO_MODE=true           # Disable all command approvals
HERMES_BACKGROUND_NOTIFICATIONS=result  # all|result|error|off
```

### Gateway Allowlists

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
GATEWAY_ALLOWED_USERS=123456789  # Cross-platform fallback
GATEWAY_ALLOW_ALL_USERS=true     # DANGEROUS — never in production
```

## Custom Endpoint Examples

| Provider | BASE_URL | API_KEY |
|----------|----------|---------|
| Ollama | `http://localhost:11434/v1` | `ollama` |
| vLLM | `http://localhost:8000/v1` | `dummy` |
| SGLang | `http://localhost:8000/v1` | `dummy` |
| llama.cpp | `http://localhost:8080/v1` | `dummy` |
| LiteLLM | `http://localhost:4000/v1` | your key |
| Together AI | `https://api.together.xyz/v1` | your key |
| Groq | `https://api.groq.com/openai/v1` | your key |
| DeepSeek | `https://api.deepseek.com/v1` | your key |

## Context Files

| File | Location | Purpose |
|------|----------|---------|
| `SOUL.md` | `~/.hermes/SOUL.md` | Agent identity |
| `AGENTS.md` | Working directory | Project conventions |
| `.cursorrules` | Working directory | Cursor IDE rules |

All capped at 20,000 characters.
