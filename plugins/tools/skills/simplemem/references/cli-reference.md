# CLI Command Reference

The SimpleMem CLI provides one-shot atomic operations for memory management.

## Installation

The CLI requires the `simplemem` package:

```bash
pip install simplemem
# or
uv add simplemem
```

## Global Options

| Option | Description |
|--------|-------------|
| `--table-name TABLE` | Use a custom table (default: `memory_entries`) |

## Commands

### add

Add a single dialogue entry to memory.

```bash
python -m simplemem add --speaker SPEAKER --content CONTENT [--timestamp TIMESTAMP]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `--speaker` | Yes | Who said it |
| `--content` | Yes | What was said |
| `--timestamp` | No | ISO 8601 datetime (auto-generated if omitted) |

**Examples:**

```bash
# Simple add
python -m simplemem add --speaker "Alice" --content "Project deadline is Friday"

# With explicit timestamp
python -m simplemem add --speaker "Bob" --content "I'll have the report ready" --timestamp "2026-02-13T09:00:00Z"
```

### import

Batch import dialogues from a JSONL file.

```bash
python -m simplemem import --file FILE_PATH
```

| Argument | Required | Description |
|----------|----------|-------------|
| `--file` | Yes | Path to JSONL file |

**JSONL format:**
```jsonl
{"speaker": "Alice", "content": "Let's meet tomorrow at 2pm", "timestamp": "2026-01-16T14:00:00Z"}
{"speaker": "Bob", "content": "Sounds good, I'll be there"}
{"speaker": "Alice", "content": "Don't forget the documents"}
```

Notes:
- `timestamp` is optional per line (defaults to current time)
- Lines with parse errors are skipped and reported
- All valid entries are added in a single batch

### query

Semantic Q&A over stored memories. Retrieves relevant entries and generates a natural language answer.

```bash
python -m simplemem query --question QUESTION [--enable-reflection] [--top-k K]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `--question` | Yes | Natural language question |
| `--enable-reflection` | No | Multi-step reasoning for complex queries |
| `--top-k` | No | Number of entries to retrieve (default: 5) |

**Examples:**

```bash
# Simple query
python -m simplemem query --question "What did Alice say about the deadline?"

# Complex query with reflection
python -m simplemem query --question "Summarize all project updates" --enable-reflection

# With more context
python -m simplemem query --question "Timeline of meetings" --top-k 15
```

### retrieve

Raw memory entry retrieval without LLM synthesis. Returns matching entries directly.

```bash
python -m simplemem retrieve --query QUERY [--top-k K]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `--query` | Yes | Search query |
| `--top-k` | No | Number of results (default: 5) |

### stats

Display memory store statistics.

```bash
python -m simplemem stats
```

Output includes: total entries, table name, database path.

### clear

Delete all entries from memory. Irreversible.

```bash
python -m simplemem clear --yes
```

The `--yes` flag is required to prevent accidental deletion.

## Custom Tables

Use different tables to organize memory by context:

```bash
# Store project-specific memories
python -m simplemem --table-name project_alpha add --speaker "PM" --content "Sprint ends Friday"

# Query project-specific memories
python -m simplemem --table-name project_alpha query --question "When does the sprint end?"
```
