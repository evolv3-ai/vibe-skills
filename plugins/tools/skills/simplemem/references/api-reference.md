# Python API Reference

## Installation

```bash
pip install simplemem
# or
uv add simplemem

# With GPU support (PyTorch + CUDA)
pip install simplemem[gpu]
```

**Requirements:** Python 3.10+

## SimpleMemSystem

The main system class integrating all components.

### Constructor

```python
from simplemem import SimpleMemSystem

system = SimpleMemSystem(
    api_key=None,                      # API key (default: from config.py)
    model=None,                        # LLM model (default: from config.py)
    temperature=None,                  # LLM temperature (default: from config.py)
    db_path=None,                      # LanceDB path (default: "./data/lancedb")
    table_name=None,                   # Table name (default: "memory_entries")
    clear_db=False,                    # Clear existing data on init
    enable_planning=None,              # Multi-query planning (default: True)
    enable_reflection=None,            # Reflection-based retrieval (default: True)
    max_reflection_rounds=None,        # Max reflection iterations (default: 2)
    enable_parallel_processing=None,   # Parallel memory building (default: True)
    max_parallel_workers=None,         # Build workers (default: 16)
    enable_parallel_retrieval=None,    # Parallel retrieval (default: True)
    max_retrieval_workers=None,        # Retrieval workers (default: 8)
)
```

### Methods

#### add_dialogue(speaker, content, timestamp=None)

Add a single dialogue entry. Buffered and processed in windows.

```python
system.add_dialogue("Alice", "Meet at Starbucks at 2pm", "2025-11-15T14:30:00")
```

#### add_dialogues(dialogues)

Batch add dialogue entries.

```python
from simplemem.models.memory_entry import Dialogue

dialogues = [
    Dialogue(dialogue_id=1, speaker="Alice", content="Hello", timestamp="2025-11-15T14:30:00"),
    Dialogue(dialogue_id=2, speaker="Bob", content="Hi there", timestamp="2025-11-15T14:31:00"),
]
system.add_dialogues(dialogues)
```

#### finalize()

Process any remaining buffered dialogues. Call after all dialogues are added.

```python
system.finalize()
```

#### ask(question) -> str

Query the memory system. Runs hybrid retrieval + answer generation.

```python
answer = system.ask("When will Alice and Bob meet?")
```

#### get_all_memories() -> List[MemoryEntry]

Return all stored memory entries.

```python
memories = system.get_all_memories()
for m in memories:
    print(f"{m.entry_id}: {m.lossless_restatement}")
```

#### print_memories()

Debug: print all memory entries to stdout.

### Convenience Factory

```python
from simplemem import create_system

system = create_system(
    clear_db=True,
    enable_parallel_processing=True,
    max_parallel_workers=8,
)
```

## Data Models

### MemoryEntry

```python
from simplemem.models.memory_entry import MemoryEntry

# Fields:
entry_id: str              # UUID
ref_id: str                # Application-level reference
lossless_restatement: str  # Self-contained atomic fact
keywords: List[str]        # BM25 keywords
timestamp: str             # ISO 8601
location: str              # Natural language location
persons: List[str]         # Named people
entities: List[str]        # Organizations, products
topic: str                 # Topic phrase
agents: List[str]          # Agent sources
source: str                # Origin identifier
```

### Dialogue

```python
from simplemem.models.memory_entry import Dialogue

dialogue = Dialogue(
    dialogue_id=1,
    speaker="Alice",
    content="Let's meet tomorrow",
    timestamp="2025-11-15T14:30:00"  # Optional
)
```

## VectorStore

Direct access to the storage layer for advanced operations.

### Delete by ID

```python
system.vector_store.delete_by_id(entry_id="uuid-string")
```

### Delete by Reference ID

```python
system.vector_store.delete_by_ref_id(ref_id="my-application-ref")
```

### Search Methods

```python
# Semantic (vector similarity)
results = system.vector_store.semantic_search(query_embedding, top_k=10)

# Keyword (BM25 full-text)
results = system.vector_store.keyword_search("meeting deadline", top_k=5)

# Structured (metadata filtering)
results = system.vector_store.structured_search(
    persons=["Alice"],
    timestamp_range=("2025-11-01", "2025-11-30"),
    top_k=5
)
```

### Clear Database

```python
system.vector_store.clear()
```

## Configuration

Create `config.py` from the template (see `templates/config.py.example`):

```python
# Provider: OpenAI direct
OPENAI_API_KEY = "sk-..."
LLM_MODEL = "gpt-4.1-mini"
EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-0.6B"
EMBEDDING_DIMENSION = 1024

# Provider: OpenRouter
OPENROUTER_API_KEY = "sk-or-..."
LLM_MODEL = "openai/gpt-4.1-mini"
EMBEDDING_MODEL = "qwen/qwen3-embedding-8b"
EMBEDDING_DIMENSION = 4096

# Provider: LiteLLM (multi-provider)
# Supports: OpenAI, Anthropic, Azure, Bedrock, etc.
# Configure via LITELLM_* environment variables

# Provider: Azure OpenAI
OPENAI_API_KEY = "your-azure-key"
OPENAI_BASE_URL = "https://your-endpoint.openai.azure.com/"
LLM_MODEL = "your-deployment-name"
```

## Complete Example

```python
from simplemem import SimpleMemSystem

# Initialize with parallel processing
system = SimpleMemSystem(
    clear_db=True,
    enable_parallel_processing=True,
    max_parallel_workers=8,
    enable_parallel_retrieval=True,
    max_retrieval_workers=4,
)

# Add conversation
system.add_dialogue("Alice", "Let's meet at Starbucks tomorrow at 2pm", "2025-11-15T14:30:00")
system.add_dialogue("Bob", "I'll bring the market analysis report", "2025-11-15T14:31:00")
system.add_dialogue("Alice", "Remember the competitive analysis from last week too", "2025-11-15T14:32:00")

# Finalize (process remaining buffer)
system.finalize()

# Query
answer = system.ask("When and where will Alice and Bob meet?")
print(answer)  # "16 November 2025 at 2:00 PM at Starbucks"

# Query with reflection disabled
contexts = system.hybrid_retriever.retrieve("What documents will Bob bring?", enable_reflection=False)
answer = system.answer_generator.generate_answer("What documents will Bob bring?", contexts)
print(answer)

# View all memories
system.print_memories()

# Cleanup specific entry
system.vector_store.delete_by_id(entry_id="specific-uuid")
```
