# Claude Models

> Last verified: 2026-02-17

## Current Models

| Model | API ID | Alias | Context | Input/MTok | Output/MTok |
|-------|--------|-------|---------|-----------|-------------|
| Opus 4.6 | `claude-opus-4-6` | — | 1M | $15 | $75 |
| Sonnet 4.5 | `claude-sonnet-4-5-20250929` | `claude-sonnet-4-5` | 200K | $3 | $15 |
| Haiku 4.5 | `claude-haiku-4-5-20251001` | `claude-haiku-4-5` | 200K | $1 | $5 |
| Opus 4.5 | `claude-opus-4-5-20251101` | `claude-opus-4-5` | 200K | $5 | $25 |

## Legacy Models (still available)

| Model | API ID | Alias |
|-------|--------|-------|
| Opus 4.1 | `claude-opus-4-1-20250805` | `claude-opus-4-1` |
| Sonnet 4 | `claude-sonnet-4-20250514` | `claude-sonnet-4-0` |
| Opus 4 | `claude-opus-4-20250514` | `claude-opus-4-0` |
| Sonnet 3.7 | `claude-3-7-sonnet-20250219` | `claude-3-7-sonnet-latest` |
| Haiku 3 | `claude-3-haiku-20240307` | — |

## Retired (EOL Feb 2026)

| Model | Replaced by |
|-------|-------------|
| Haiku 3.5 (`claude-3-5-haiku-20241022`) | Haiku 4.5 |
| Sonnet 3.5 (`claude-3-5-sonnet-20241022`) | Sonnet 4.5 |

## Default Models by Environment

| Environment | Default model |
|-------------|--------------|
| Claude AI (Pro/Max/Team) | Opus 4.6 |
| Claude AI (Free) | Sonnet 4.5 |
| Claude Code | Opus 4.6 |
| Claude Code fast mode | Same model (Opus 4.6), faster output |
| API | No default — must specify |

## When to Use Which

| Use case | Recommended |
|----------|-------------|
| Most tasks | Sonnet 4.5 (best cost/quality balance) |
| Complex reasoning, creative work | Opus 4.6 or Opus 4.5 |
| High-volume, cost-sensitive | Haiku 4.5 |
| Subagent delegation (simple tasks) | Haiku 4.5 |
| Quality-critical outputs | Opus 4.6 |

## Verification

When uncertain about model availability, verify via API:

```bash
# Anthropic
curl -s https://api.anthropic.com/v1/models \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2024-01-01" | jq '.data[].id'

# OpenRouter
curl -s https://openrouter.ai/api/v1/models | jq -r '.data[].id' | grep -i "claude"
```

Official docs: https://platform.claude.com/docs/en/docs/about-claude/models
