---
name: simplemem
description: >
  Build persistent LLM agent memory with SimpleMem - semantic lossless compression
  with 30x token reduction. MCP server (cloud/self-hosted), Python API, cross-session
  memory. Use when: adding long-term memory to agents, cross-session context recall,
  semantic dialogue search, memory consolidation.
---

# SimpleMem

Efficient lifelong memory for LLM agents via semantic lossless compression.

SimpleMem converts unstructured dialogue into compact, atomic memory units with coreference resolution and temporal anchoring. It achieves 43.24% F1 on the LoCoMo benchmark with 30x fewer tokens than full-context methods.

## Integration Paths

Choose the path that fits your use case:

| Path | Best For | Setup |
|------|----------|-------|
| **MCP Server (cloud)** | Quickest start, multi-platform | Config only |
| **MCP Server (self-hosted)** | Privacy, custom deployment | Docker or Python |
| **Python API (`pip install simplemem`)** | Programmatic integration | pip/uv |
| **SimpleMem-Cross** | Cross-session agent memory | Python + orchestrator |

## MCP Server Setup (Recommended)

### Cloud Service

The fastest path. Uses the hosted service at `mcp.simplemem.cloud`.

1. Visit `https://mcp.simplemem.cloud`
2. Enter your OpenRouter API key to get an auth token
3. Add to your MCP client config:

**Claude Desktop / Claude Code (`~/.claude.json`):**

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

**Cursor (`.cursor/mcp.json`):**

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

### Self-Hosted (Docker)

For privacy-sensitive deployments or custom infrastructure:

```bash
git clone https://github.com/aiming-lab/SimpleMem.git
cd SimpleMem/MCP

# Configure environment
export JWT_SECRET_KEY="your-secure-random-secret"
export ENCRYPTION_KEY="your-32-byte-encryption-key!!"

# Run with Docker
docker compose up -d
```

The server exposes:
- Web UI: `http://localhost:8000/`
- REST API: `http://localhost:8000/api/`
- MCP endpoint: `http://localhost:8000/mcp`

See [references/mcp-setup.md](references/mcp-setup.md) for full self-hosting guide.

### MCP Tools Available

| Tool | Purpose |
|------|---------|
| `memory_add` | Store a dialogue (auto-compresses to atomic facts) |
| `memory_add_batch` | Batch store multiple dialogues |
| `memory_query` | Semantic Q&A over stored memories |
| `memory_retrieve` | Raw memory entry retrieval |
| `memory_delete` | Delete entries by entry_id or ref_id |
| `memory_stats` | Storage statistics |
| `memory_clear` | Delete all memories (irreversible) |

## Python API

Install via pip or uv:

```bash
pip install simplemem
# or
uv add simplemem
```

### Basic Usage

```python
from simplemem import SimpleMemSystem

# Initialize (uses config.py for API settings)
system = SimpleMemSystem(clear_db=True)

# Stage 1: Add dialogues (semantic structured compression)
system.add_dialogue("Alice", "Let's meet at Starbucks tomorrow at 2pm", "2025-11-15T14:30:00")
system.add_dialogue("Bob", "I'll bring the market analysis report", "2025-11-15T14:31:00")

# Finalize atomic encoding
system.finalize()

# Stage 3: Query with intent-aware retrieval
answer = system.ask("When and where will Alice and Bob meet?")
# "16 November 2025 at 2:00 PM at Starbucks"
```

### Parallel Processing

For large dialogue datasets:

```python
system = SimpleMemSystem(
    clear_db=True,
    enable_parallel_processing=True,
    max_parallel_workers=8,
    enable_parallel_retrieval=True,
    max_retrieval_workers=4
)
```

### Memory Deletion

Delete entries by ID:

```python
# Delete by entry_id
system.vector_store.delete_by_id(entry_id="uuid-here")

# Delete by ref_id (application-level reference)
system.vector_store.delete_by_ref_id(ref_id="my-ref")
```

## Configuration

SimpleMem supports any OpenAI-compatible API provider:

```python
# config.py
OPENAI_API_KEY = "your-api-key"         # OpenAI, OpenRouter, or compatible
OPENAI_BASE_URL = None                   # Set for non-OpenAI providers

# Models
LLM_MODEL = "gpt-4.1-mini"              # Or any OpenAI-compatible model
EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-0.6B"  # State-of-the-art retrieval

# Via OpenRouter (multi-provider gateway)
OPENROUTER_API_KEY = "sk-or-..."
LLM_MODEL = "openai/gpt-4.1-mini"       # OpenRouter model path
EMBEDDING_MODEL = "qwen/qwen3-embedding-8b"
EMBEDDING_DIMENSION = 4096
```

**Provider options:**
- **OpenAI direct** - Set `OPENAI_API_KEY`
- **OpenRouter** - Set `OPENROUTER_API_KEY`, prefix model names with provider
- **LiteLLM** - Multi-provider abstraction, configure via `LITELLM_*` settings
- **Azure OpenAI** - Set `OPENAI_BASE_URL` to your Azure endpoint
- **Qwen / local models** - Set `OPENAI_BASE_URL` to your endpoint

See [references/api-reference.md](references/api-reference.md) for full configuration.

## Cross-Session Memory (SimpleMem-Cross)

SimpleMem-Cross enables persistent memory across conversations. Agents recall context, decisions, and learnings from previous sessions automatically.

**Performance:** 64% improvement over Claude-Mem on LoCoMo benchmark (score 48 vs 29.3).

### Quick Example

```python
from cross.orchestrator import create_orchestrator

async def main():
    orch = create_orchestrator(project="my-project")

    # Start session - previous context injected automatically
    result = await orch.start_session(
        content_session_id="session-001",
        user_prompt="Continue building the REST API",
    )
    print(result["context"])  # Relevant context from past sessions

    # Record events during the session
    await orch.record_message(result["memory_session_id"], "User asked about JWT")
    await orch.record_tool_use(
        result["memory_session_id"],
        tool_name="read_file",
        tool_input="auth/jwt.py",
        tool_output="class JWTHandler: ...",
    )

    # Finalize - extracts observations, generates summary, stores memories
    report = await orch.stop_session(result["memory_session_id"])
    print(f"Stored {report.entries_stored} memory entries")

    await orch.end_session(result["memory_session_id"])
    orch.close()
```

### Key Features

| Feature | Description |
|---------|-------------|
| Session lifecycle | start -> record -> stop -> end with full event tracking |
| Automatic context injection | Token-budgeted context from previous sessions at start |
| Event collection | Messages, tool uses, file changes with 3-tier redaction |
| Observation extraction | Heuristic extraction of decisions, discoveries, learnings |
| Provenance tracking | Every memory links back to source evidence |
| Consolidation | Automatic decay, merge, and prune of old memories |

See [references/cross-session.md](references/cross-session.md) for full API and architecture.

## Three-Stage Pipeline

SimpleMem's architecture is based on semantic lossless compression:

### Stage 1: Semantic Structured Compression

Raw dialogue is converted to atomic, self-contained memory units:
- **Coreference resolution**: "He" becomes "Bob"
- **Temporal anchoring**: "tomorrow" becomes "2025-11-16T14:00:00"
- **Density gating**: Filters low-information content

```
Input:  "He'll meet Bob tomorrow at 2pm"
Output: "Alice will meet Bob at Starbucks on 2025-11-16T14:00:00"
```

### Stage 2: Online Semantic Synthesis

Related fragments are consolidated during writes:
- Eliminates redundant information
- Merges related facts into unified representations
- Maintains compact memory topology

### Stage 3: Intent-Aware Retrieval Planning

Queries trigger parallel multi-view retrieval:
- **Semantic layer**: Dense vector similarity (1024-d embeddings)
- **Lexical layer**: BM25 keyword matching
- **Symbolic layer**: Metadata filtering (persons, locations, timestamps, entities)
- Dynamic retrieval depth based on query complexity

See [references/architecture.md](references/architecture.md) for detailed architecture.

## Data Model

Each memory entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `entry_id` | UUID | Unique identifier |
| `ref_id` | String | Application-level reference (for deletion) |
| `lossless_restatement` | String | Self-contained atomic fact |
| `keywords` | List[str] | Core keywords for BM25 search |
| `timestamp` | ISO 8601 | When the event occurred |
| `location` | String | Where (natural language) |
| `persons` | List[str] | People mentioned |
| `entities` | List[str] | Companies, products, organizations |
| `topic` | String | Topic phrase |
| `agents` | List[str] | Agent sources |
| `source` | String | Origin identifier |

## Troubleshooting

**Embedding dimension mismatch:**
```
RuntimeError: lance error: Invalid: ListType can only be casted to FixedSizeListType
```
The `EMBEDDING_DIMENSION` in config doesn't match the model's output. Update the value and clear the database: `rm -rf data/lancedb/*`

**API key not detected:**
- Verify key is set in `config.py` (not `config.py.example`)
- For OpenRouter keys, ensure they start with `sk-or-`
- Restart Python after updating the key

**Model not found:**
- Use full provider path for OpenRouter: `openai/gpt-4.1-mini` not `gpt-4.1-mini`
- Check available models at `openrouter.ai/models`
