---
name: obsidian-rlm
description: |
  Process large files for Obsidian workflows using RLM (Recursive Language Models). Handles LLM conversation exports (64MB+), bulk note analysis, and large JSON processing that would overwhelm standard tools.

  Use when: ContentImporter hits files over 10MB, processing large Claude/ChatGPT exports, bulk triage of conversation archives, extracting insights from massive JSON files.
---

# Obsidian RLM - Large File Processor

## Provider Requirements

**Local models (14B-24B) are unreliable for RLM's JSON protocol.** Testing with 72MB Claude export showed:

| Provider | JSON Reliability | Recommended |
|----------|-----------------|-------------|
| **OpenAI GPT-4o** | Excellent | **Yes** |
| **OpenRouter** | Excellent | **Yes** |
| DeepSeek API | Excellent | Yes |
| Ollama 70B+ | Moderate | Fallback |
| Ollama 14B-24B | Unreliable | No |

**For production use with large files, use API providers.**

---

## Recommended: Hybrid Approach

For files >50MB, the **hybrid approach** is most reliable:

1. **Python/jq for metadata** (instant, 100% reliable)
2. **RLM for content analysis** on extracted segments

See "Hybrid Workflow" section below.

## References

| Need | File |
|------|------|
| RLM query examples and file format schemas | `references/QUERY_PATTERNS.md` |
| RLM server configuration for large files | `references/configuration.md` |

---

## Purpose

When the **ContentImporter** agent encounters files too large for direct processing (10MB+), this skill takes over to:

1. **Analyze** the file structure via RLM iterative commands
2. **Extract** metadata, counts, and summaries without loading entire file
3. **Return** structured data for ContentImporter's triage workflow
4. **Generate** Obsidian-ready output (frontmatter, wikilinks, tags)

---

## Hybrid Workflow (Recommended for 50MB+)

**Tested with 72MB Claude export (1,375 conversations)**

**Timing**: ~3 min for full triage of 64MB files; individual conversation extraction 10-20s.

### Step 1: Python Metadata Extraction (Instant)

```python
import json

with open('<EXPORT_FILE>', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Basic stats
print(f"Total conversations: {len(data)}")
dates = [c['created_at'][:10] for c in data if c.get('created_at')]
print(f"Date range: {min(dates)} to {max(dates)}")

# Triage by message count
msg_counts = [len(c.get('chat_messages', [])) for c in data]
high_value = sum(1 for c in msg_counts if c > 50)
medium = sum(1 for c in msg_counts if 10 < c <= 50)
low = sum(1 for c in msg_counts if 0 < c <= 10)
print(f"HIGH (50+ msgs): {high_value}")
print(f"MEDIUM (11-50): {medium}")
print(f"LOW (1-10): {low}")

# Top conversations
convos = [(c.get('name', ''), len(c.get('chat_messages', []))) for c in data]
convos.sort(key=lambda x: x[1], reverse=True)
print("\nTop 10:")
for name, count in convos[:10]:
    print(f"  {count:3} msgs - {name[:50]}")
```

### Step 2: RLM for Content Analysis

For specific conversations needing deeper analysis:

```bash
# Extract one conversation to a smaller file
python -c "
import json
with open('<EXPORT_FILE>') as f:
    data = json.load(f)
# Find conversation by name
conv = next(c for c in data if 'BMAD' in c.get('name', ''))
with open('single_conv.json', 'w') as f:
    json.dump(conv, f)
"

# Analyze with RLM
curl -X POST http://localhost:4539/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Summarize the key decisions and action items from this conversation",
    "context_path": "demo/single_conv.json"
  }'
```

---

## Quick Start

### Prerequisites

1. **RLM Server Running** at `http://localhost:4539`
   ```bash
   cd <RLM_DIR>
   # Use OpenAI config for reliability
   export LITELLM_API_KEY="your-openai-key"
   ./rlm-server config-openai.toml
   ```

2. **Verify Health**
   ```bash
   curl http://localhost:4539/health
   # Expected: {"status":"healthy","wasm_enabled":false}
   ```

**Note**: WASM is disabled for large files (crashes on 70MB+). DSL-only mode is sufficient.

### Basic Usage

```bash
# Count conversations in large Claude export
curl -X POST http://localhost:4539/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Count the total number of conversations in this JSON",
    "context_file": "<EXPORT_FILE>"
  }'

# Extract conversation titles for triage
curl -X POST http://localhost:4539/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "List all conversation names with their created_at dates",
    "context_file": "<EXPORT_FILE>"
  }'
```

---

## Size Threshold Logic

| File Size | Recommended Approach | Why |
|-----------|---------------------|-----|
| < 1MB | Direct parsing | Fast, no overhead |
| 1-10MB | Direct with streaming | Manageable in memory |
| 10-50MB | **RLM with API provider** | Iterative processing, reliable JSON |
| 50MB+ | **Hybrid: Python + RLM** | Python for metadata, RLM for analysis |
| 70MB+ | **Hybrid only** | WASM crashes, DSL-only too slow |

**WASM crashes on files >70MB** - Always disable WASM for large files.

### Detection Code (for ContentImporter)

```javascript
// In ContentImporter workflow
const fileSizeMB = fs.statSync(filePath).size / (1024 * 1024);

if (fileSizeMB > 10) {
  // Trigger obsidian-rlm skill
  console.log(`Large file detected (${fileSizeMB.toFixed(1)}MB) - using RLM`);
  return processWithRLM(filePath, query);
} else {
  // Standard processing
  return JSON.parse(fs.readFileSync(filePath));
}
```

---

## Integration with ContentImporter

### Workflow: Large Claude Export

```
1. User: "Process my Claude export at <EXPORT_FILE>"

2. ContentImporter checks file size:
   - Size: 64MB -> Triggers obsidian-rlm

3. obsidian-rlm runs initial analysis:
   - Query: "Count conversations, identify structure"
   - Returns: 847 conversations, Claude format

4. obsidian-rlm runs triage:
   - Query: "Categorize by value (HIGH/MEDIUM/LOW)"
   - Returns: 52 HIGH, 189 MEDIUM, 606 LOW

5. ContentImporter generates Triage Report

6. User selects items to import

7. obsidian-rlm extracts selected conversations:
   - Query: "Extract full conversation with uuid [X]"
   - Returns: Complete conversation text

8. ContentImporter creates notes in 00 NoteLab/
```

### Data Handoff Format

obsidian-rlm returns data in this format for ContentImporter:

```json
{
  "analysis": {
    "file_path": "<EXPORT_FILE>",
    "file_size_mb": 64.2,
    "format": "claude",
    "total_conversations": 847,
    "processing_time_seconds": 45
  },
  "triage": {
    "high_value": [
      {
        "uuid": "abc123",
        "name": "System Architecture Design",
        "date": "2024-01-15",
        "message_count": 89,
        "has_code": true,
        "suggested_folder": "02 Cards/Reference",
        "suggested_tags": ["#Architecture", "#Reference"]
      }
    ],
    "medium_value": [],
    "low_value_count": 606
  }
}
```

---

## Troubleshooting

### Problem: RLM times out on 64MB file
**Solution**: Use chunked queries. Instead of loading entire file, query specific ranges:
```
"Analyze conversations 0-100 in this export"
"Analyze conversations 100-200 in this export"
```

### Problem: JSON parse errors on Claude export
**Solution**: Verify file is valid JSON. Claude exports occasionally have encoding issues:
```bash
# Validate JSON
python -c "import json; json.load(open('<EXPORT_FILE>'))"
```

### Problem: RLM server not responding
**Solution**: Check server is running and accessible:
```bash
curl http://localhost:4539/health
# If no response, restart server
```

### Problem: Ollama model too slow
**Solution**: For initial triage (not extraction), use faster/smaller models:
```toml
# Fast triage model
model = "qwen3:8b"  # Faster than 14b for simple counts
```
