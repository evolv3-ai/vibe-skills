# SimpleMem Architecture

## Three-Stage Pipeline

SimpleMem implements semantic lossless compression through three stages:

```
Raw Dialogue → [Stage 1: Compression] → [Stage 2: Synthesis] → Compact Memory Store
                                                                        ↓
User Query → [Stage 3: Retrieval Planning] → [Multi-View Search] → Answer
```

### Stage 1: Semantic Structured Compression

Converts unstructured dialogue into atomic, self-contained memory units.

**Transformations applied:**
- **Density gating**: LLM estimates information gain relative to existing memory. Low-utility content is filtered
- **Coreference resolution**: All pronouns resolved to named entities ("he" -> "Bob")
- **Temporal anchoring**: Relative times converted to absolute ISO 8601 ("tomorrow" -> "2025-11-16T14:00:00")
- **Reformulation**: Multi-speaker dialogue distilled into single-fact statements

**Example:**
```
Input dialogue:
  Alice: "He'll meet Bob tomorrow at 2pm"
  (Context: conversation date is 2025-11-15, "He" refers to Charlie)

Output memory unit:
  lossless_restatement: "Charlie will meet Bob on 2025-11-16T14:00:00"
  persons: ["Charlie", "Bob"]
  timestamp: "2025-11-16T14:00:00"
  keywords: ["meet", "Charlie", "Bob"]
```

**Processing:** Dialogues are buffered into windows (default: 40 dialogues) and processed in parallel via ThreadPoolExecutor.

### Stage 2: Online Semantic Synthesis

Intra-session consolidation during the write phase. Related memory units are merged into unified abstract representations.

```
Fragment 1: "User wants coffee"
Fragment 2: "User prefers oat milk"
Fragment 3: "User likes it hot"
    ↓ Synthesis
Consolidated: "User prefers hot coffee with oat milk"
```

This eliminates redundancy and maintains a compact memory topology without background maintenance jobs.

### Stage 3: Intent-Aware Retrieval Planning

Queries trigger LLM-based retrieval planning that determines:
- Search intent and complexity
- Retrieval depth (k_dyn)
- Which indexes to query
- How to decompose complex queries

**Three retrieval layers execute in parallel:**

| Layer | Index | Method | Purpose |
|-------|-------|--------|---------|
| Semantic | Dense vectors | Cosine similarity | Conceptual meaning |
| Lexical | BM25 / Tantivy | Keyword matching | Exact terms |
| Symbolic | SQL / DataFusion | Metadata filtering | Persons, dates, locations, entities |

Results are merged via ID-based deduplication and ranked by relevance.

**Optional reflection:** Multi-round retrieval with completeness checking. The LLM assesses whether retrieved context is sufficient and issues additional queries if needed (configurable, default: 2 rounds max).

## Component Architecture

```
SimpleMemSystem
├── LLMClient (OpenRouter / OpenAI / LiteLLM)
├── EmbeddingModel (via OpenRouter or local)
├── VectorStore (LanceDB)
│   ├── Semantic index (dense vectors)
│   ├── Lexical index (Tantivy FTS)
│   └── Symbolic index (DataFusion SQL)
├── MemoryBuilder (Stage 1)
│   ├── Window-based buffering
│   ├── Parallel processing
│   └── LLM-based extraction with retry
├── HybridRetriever (Stage 3)
│   ├── Planning-based multi-query
│   ├── Parallel multi-view search
│   ├── Intelligent reflection
│   └── Query complexity estimation
└── AnswerGenerator
    ├── Multi-layer context formatting
    └── JSON-structured output with retry
```

## Storage

**Vector database:** LanceDB (columnar, embedded, supports cloud storage via GCS/S3/Azure).

**Default location:** `./data/lancedb/`

**Table schema:**
- `entry_id` (string): UUID
- `ref_id` (string): Application-level reference ID
- `lossless_restatement` (string): The atomic fact
- `keywords` (list[string]): BM25 keywords
- `timestamp` (string): ISO 8601
- `location` (string): Natural language location
- `persons` (list[string]): Named people
- `entities` (list[string]): Organizations, products
- `topic` (string): Topic phrase
- `agents` (list[string]): Agent sources
- `source` (string): Origin identifier
- `embedding` (vector): Dense representation

## Performance

**LoCoMo-10 Benchmark (GPT-4.1-mini):**

| Metric | SimpleMem | Mem0 | A-Mem |
|--------|-----------|------|-------|
| Average F1 | 43.24% | 34.20% | 32.58% |
| Construction time | 92.6s | 1350.9s | 5140.5s |
| Retrieval time | 388.3s | 583.4s | 796.7s |
| Total time | 480.9s | 1934.3s | 5937.2s |

**Token efficiency:** ~550 tokens per query vs full-context methods (30x reduction).
