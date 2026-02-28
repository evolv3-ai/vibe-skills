# SimpleMem Integration

The admin skill integrates with SimpleMem for persistent operational memory across sessions. Agents can store and recall installation history, issue context, diagnostic findings, and configuration decisions.

## Architecture

```
Admin Operations
    │
    ├─ tool-installer ──→ memory_add (what was installed, how, gotchas)
    ├─ verify-agent ────→ memory_add (verification results, failures)
    ├─ mcp-bot ─────────→ memory_add (diagnostic findings, fixes)
    ├─ docs-agent ──────→ memory_add (session summaries)
    │
    └─ All agents ──────→ memory_query (before starting, check past context)
                            │
                            ▼
                    SimpleMem MCP Server
                    (mem.self-host.io/mcp)
                            │
                            ▼
                    Semantic Memory Store
                    (LanceDB + hybrid retrieval)
```

## How It Works

SimpleMem is registered as an MCP server. When available, agents use two MCP tools:

| Tool | When | What Gets Stored/Retrieved |
|------|------|---------------------------|
| `memory_query` | Before operations | Past experience with this tool/server/issue |
| `memory_add` | After operations | What happened, what worked, what didn't |

## MCP Configuration

SimpleMem runs as a self-hosted MCP server. The config lives in the Claude Code MCP settings.

**Claude Code CLI** (`~/.claude/.mcp.json` or Windows equivalent):
```json
{
  "simplemem": {
    "type": "http",
    "url": "https://mem.self-host.io/mcp",
    "headers": {
      "Authorization": "Bearer YOUR_TOKEN"
    }
  }
}
```

**Getting a token:**
1. Visit `https://mem.self-host.io`
2. Enter your OpenRouter API key
3. Copy the generated JWT token
4. Add to MCP config as shown above

## Memory Patterns by Agent

### tool-installer

**Before install** - Query for past experience:
```
memory_query: "What happened last time I installed {tool} on {platform}?"
```

This surfaces:
- Past installation issues and fixes
- Version compatibility notes
- Platform-specific gotchas
- Preferred installation methods that worked

**After install** - Store the outcome:
```
memory_add: "Installed {tool} v{version} on {device} ({platform}) via {manager}. {outcome}. {notes}"
```

### verify-agent

**After verification** - Store findings:
```
memory_add: "Verified {tool} on {device}: {result}. {details}"
```

Especially valuable for failures - next time the same verification fails, the LLM can recall what fixed it.

### mcp-bot

**During diagnostics** - Query past issues:
```
memory_query: "What MCP server issues have occurred on this device?"
```

**After fixing** - Store the solution:
```
memory_add: "Fixed MCP issue on {device}: {problem}. Solution: {fix}."
```

### docs-agent

**Session end** - Store session summary:
```
memory_add: "Admin session on {device} ({date}): {summary}. Actions: {actions}. Outcome: {outcome}."
```

This provides cross-session continuity beyond what `sessions.log` offers - SimpleMem enables semantic search over all past sessions.

## Graceful Degradation

SimpleMem is **optional**. If the MCP server is unavailable:

1. Agents check if `memory_query` / `memory_add` tools are available
2. If not available (server down, not configured), agents skip memory operations
3. All other admin operations proceed normally
4. Flat file logging (`operations.log`, `sessions.log`) continues regardless

**Rule**: Never fail an operation because SimpleMem is unavailable. Memory is additive, not required.

## What Gets Stored

### High-Value Memories (always store)
- Installation outcomes (success + failure)
- Issue resolutions and workarounds
- MCP diagnostic findings
- Server provisioning decisions and outcomes
- Configuration choices and reasoning

### Low-Value (skip)
- Routine profile reads
- Listing operations (ls, status)
- Unchanged verification results
- Duplicate information already in logs

## Speaker Convention

When storing memories via `memory_add`, use consistent speaker names:

| Speaker | Meaning |
|---------|---------|
| `admin:tool-installer` | Installation context |
| `admin:verify-agent` | Verification results |
| `admin:mcp-bot` | MCP diagnostics |
| `admin:docs-agent` | Session summaries |
| `admin:troubleshoot` | Issue context |
| `User` | User-provided context |

This enables filtered queries like "What has tool-installer recorded about Docker?"

## Cross-Device Benefits

Since SimpleMem is cloud-hosted, memories are shared across all devices:

- Install Docker on WSL device → memory stored
- Later on macOS device, install Docker → query finds WSL experience
- Platform-specific gotchas surface automatically

This complements the vault (shared secrets) and profile (per-device config) with shared operational knowledge.

## Privacy Considerations

- **No secrets**: Never store API keys, passwords, or tokens in memories
- **No paths with usernames**: Use `~/.admin/` not `/home/username/.admin/`
- **Device names OK**: Hostnames are fine for context
- **Error messages OK**: Stack traces and error output are useful for recall
- **Redaction**: SimpleMem has 3-tier automatic redaction for cross-session mode
