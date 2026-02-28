# SimpleMem-Cross: Cross-Session Memory

Persistent cross-conversation memory for LLM agents. Agents recall context, decisions, and learnings from previous sessions automatically.

**Performance:** LoCoMo score of 48 (64% improvement over Claude-Mem at 29.3).

## Architecture

```
Agent Frameworks (Claude Code / Cursor / custom)
                    |
     +--------------+--------------+
     |                             |
Hook/Lifecycle Adapter      HTTP/MCP API (FastAPI)
     |                             |
     +--------------+--------------+
                    |
           CrossMemOrchestrator
                    |
  +-----------------+------------------+
  |                 |                  |
Session Manager  Context Injector  Consolidation
(SQLite)         (budgeted bundle) (decay/merge/prune)
  |                 |                  |
  +---------+-------+                  |
            |                          |
   Cross-Session Vector Store (LanceDB) <--+
```

## Session Lifecycle

```
start_session() → record_*() → stop_session() → end_session()
```

### 1. Start Session

```python
from cross.orchestrator import create_orchestrator

orch = create_orchestrator(project="my-project")

result = await orch.start_session(
    content_session_id="session-001",
    user_prompt="Continue building the REST API",
)

memory_session_id = result["memory_session_id"]
context = result["context"]  # Auto-injected from past sessions
```

Context injection is **token-budgeted** - only the most relevant memories from previous sessions are included, respecting the token budget.

### 2. Record Events

During the session, record events as they happen:

```python
# Record a message
await orch.record_message(memory_session_id, "User asked about JWT implementation")

# Record a tool use
await orch.record_tool_use(
    memory_session_id,
    tool_name="read_file",
    tool_input="auth/jwt.py",
    tool_output="class JWTHandler: ...",
)

# Record a file change
await orch.record_file_change(
    memory_session_id,
    file_path="auth/jwt.py",
    change_type="modified",
    summary="Added token refresh logic",
)
```

**3-tier automatic redaction:** Sensitive data (API keys, passwords, tokens) is automatically redacted before storage.

### 3. Stop Session

Finalizes the session - extracts observations and generates summary:

```python
report = await orch.stop_session(memory_session_id)
print(f"Stored {report.entries_stored} memory entries")
print(f"Observations: {report.observations}")
```

**Observation extraction** heuristically identifies:
- **Decisions**: "We decided to use JWT over sessions"
- **Discoveries**: "Found that the auth middleware wasn't handling refresh tokens"
- **Learnings**: "The database migration tool requires explicit lock release"

### 4. End Session

Closes the session and cleans up resources:

```python
await orch.end_session(memory_session_id)
orch.close()
```

## Module Reference

| Module | Description |
|--------|-------------|
| `cross/types.py` | Pydantic models, enums, records |
| `cross/storage_sqlite.py` | SQLite backend for sessions, events, observations |
| `cross/storage_lancedb.py` | LanceDB vector store with provenance |
| `cross/hooks.py` | Lifecycle hooks (SessionStart/ToolUse/End) |
| `cross/collectors.py` | Event collection with 3-tier redaction |
| `cross/session_manager.py` | Full session lifecycle orchestration |
| `cross/context_injector.py` | Token-budgeted context builder |
| `cross/orchestrator.py` | Top-level facade and factory |
| `cross/api_http.py` | FastAPI REST endpoints |
| `cross/api_mcp.py` | MCP tool definitions (8 tools) |
| `cross/consolidation.py` | Memory maintenance worker |

## MCP Tools (Cross-Session)

When used via MCP, SimpleMem-Cross exposes 8 tools:

| Tool | Purpose |
|------|---------|
| `session_start` | Begin a new memory session with auto-context injection |
| `session_record_message` | Record a conversation message |
| `session_record_tool_use` | Record a tool invocation |
| `session_record_file_change` | Record a file modification |
| `session_stop` | Finalize session (extract observations, store memories) |
| `session_end` | Close session and clean up |
| `memory_search` | Search across all session memories |
| `memory_consolidate` | Trigger manual consolidation |

## Consolidation

Automatic memory maintenance that runs periodically:

- **Decay**: Older memories lose relevance score over time
- **Merge**: Similar memories from different sessions are combined
- **Prune**: Below-threshold memories are removed

This keeps the memory store compact and high-quality without manual intervention.

## Provenance Tracking

Every memory entry maintains a link back to its source evidence:

```python
memory_entry = {
    "content": "Team decided to use JWT for auth",
    "source_session": "session-001",
    "source_event_id": "evt-042",
    "confidence": 0.92,
    "timestamp": "2025-11-15T14:30:00Z"
}
```

This enables audit trails and helps agents understand where their knowledge came from.

## Configuration

```python
# cross/config.py
CROSS_DB_PATH = "./data/cross_sessions.db"  # SQLite for session metadata
CROSS_VECTOR_PATH = "./data/cross_lancedb"  # LanceDB for memory vectors
TOKEN_BUDGET = 2000                          # Max tokens for context injection
CONSOLIDATION_INTERVAL = 3600                # Seconds between consolidation runs
DECAY_RATE = 0.95                            # Per-day relevance decay
MERGE_THRESHOLD = 0.85                       # Similarity threshold for merging
PRUNE_THRESHOLD = 0.1                        # Minimum relevance to keep
```
