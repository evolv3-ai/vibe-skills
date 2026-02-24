# MCP Server Setup

## Cloud Service (Quickest)

1. Visit https://mcp.simplemem.cloud
2. Enter your OpenRouter API key
3. Receive your authentication token
4. Configure your MCP client:

### Client Configuration

**Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "simplemem": {
      "url": "https://mcp.simplemem.cloud/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  }
}
```

**Claude Code** (`~/.claude.json`):
```json
{
  "mcpServers": {
    "simplemem": {
      "url": "https://mcp.simplemem.cloud/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  }
}
```

**Cursor** (`.cursor/mcp.json`):
```json
{
  "mcpServers": {
    "simplemem": {
      "url": "https://mcp.simplemem.cloud/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  }
}
```

**LM Studio / Cherry Studio:**
Add MCP server with:
- URL: `https://mcp.simplemem.cloud/mcp`
- Auth header: `Bearer YOUR_TOKEN`

## Self-Hosting

### Option 1: Docker (Recommended)

```bash
git clone https://github.com/aiming-lab/SimpleMem.git
cd SimpleMem/MCP

# Set required environment variables
export JWT_SECRET_KEY="$(openssl rand -hex 32)"
export ENCRYPTION_KEY="$(openssl rand -base64 24)"

# Start
docker compose up -d
```

The server runs on port 8000:
- Web UI: http://localhost:8000/
- REST API: http://localhost:8000/api/ (**cloud-only**; self-hosted returns 404)
- MCP endpoint: http://localhost:8000/mcp (use this for all programmatic interaction)

### Option 2: Python Direct

```bash
cd SimpleMem/MCP
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Or with uv
uv sync

# Configure
export JWT_SECRET_KEY="your-secret"
export ENCRYPTION_KEY="your-32-byte-key!!"

# Run
python run.py
```

### Option 3: Coolify Deployment

For production deployment on Coolify:

```bash
# Use the Dockerfile in MCP/
cd SimpleMem/MCP
# Deploy via Coolify's Git-based deployment
# Set environment variables in Coolify dashboard:
#   JWT_SECRET_KEY, ENCRYPTION_KEY
```

### Connecting Self-Hosted to Clients

Point your MCP client to your local/deployed server:

```json
{
  "mcpServers": {
    "simplemem": {
      "url": "http://localhost:8000/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_LOCAL_TOKEN"
      }
    }
  }
}
```

## MCP Server Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  SimpleMem MCP Server                     │
├──────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐    │
│  │              HTTP Server (FastAPI)                │    │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │    │
│  │  │ Web UI   │  │ REST API │  │ MCP Streamable │  │    │
│  │  │ (/)      │  │ (/api/*) │  │ HTTP (/mcp)    │  │    │
│  │  └──────────┘  └──────────┘  └───────────────┘  │    │
│  └──────────────────────────────────────────────────┘    │
│                         │                                 │
│  ┌──────────────────────────────────────────────────┐    │
│  │         Token Authentication (JWT + AES-256)      │    │
│  └──────────────────────────────────────────────────┘    │
│                         │                                 │
│      ┌──────────────────┼──────────────────┐             │
│      ▼                  ▼                  ▼             │
│  ┌────────┐       ┌────────┐       ┌────────┐          │
│  │ User A │       │ User B │       │ User C │          │
│  │ Table  │       │ Table  │       │ Table  │          │
│  └────────┘       └────────┘       └────────┘          │
│  └──────────────── LanceDB ──────────────────┘          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │           OpenRouter API Integration              │    │
│  │  LLM: openai/gpt-4.1-mini                        │    │
│  │  Embed: qwen/qwen3-embedding-8b                   │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## MCP Tools Reference

### memory_add

Store a single dialogue entry. SimpleMem automatically:
- Extracts atomic facts
- Resolves coreferences
- Anchors timestamps
- Generates embeddings

### memory_add_batch

Batch store multiple dialogue entries in a single operation. More efficient than individual adds.

### memory_query

Semantic Q&A: retrieves relevant memories and generates a natural language answer using the LLM.

### memory_retrieve

Raw retrieval: returns matching memory entries without LLM synthesis. Useful for programmatic access.

### memory_stats

Returns storage statistics: total entries, table name, database size.

### memory_clear

Permanently deletes all memory entries. Irreversible.

## Protocol Details

- **Transport**: Streamable HTTP (MCP 2025-03-26 spec)
- **Format**: JSON-RPC 2.0
- **Authentication**: Bearer token
- **Multi-tenancy**: Per-user LanceDB tables with token-based isolation
- **Encryption**: AES-256 for stored API keys
