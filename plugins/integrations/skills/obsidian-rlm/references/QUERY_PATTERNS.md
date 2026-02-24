# RLM Query Patterns for Obsidian Workflows

Common queries for processing large files with RLM in Obsidian contexts.

---

## Claude Export Queries

### Initial Analysis

```
Analyze this Claude conversations export:
- Count total conversations
- Identify date range (earliest and latest created_at)
- Count total messages across all conversations
- Report average messages per conversation
```

### Triage by Value

```
Categorize all conversations into value tiers:

HIGH VALUE (create notes):
- Conversations with >50 messages
- Conversations containing code blocks
- Conversations about architecture, design, or decisions

MEDIUM VALUE (review):
- Conversations with 15-50 messages
- Conversations about specific topics or problems

LOW VALUE (discard):
- Conversations with <15 messages
- Quick Q&A, troubleshooting, general chat

Return counts for each tier and list HIGH VALUE conversation names with dates.
```

### Topic Search

```
Find all conversations discussing any of these topics:
- Obsidian
- PKM (Personal Knowledge Management)
- Note-taking
- Vault organization

Return conversation names, dates, and a brief excerpt showing the topic match.
```

### Code Extraction

```
Identify conversations containing code blocks.
For each, extract:
- Conversation name
- Programming languages detected
- Brief description of what the code does
Return as a markdown table.
```

### Date-Based Filtering

```
Find all conversations created between 2024-06-01 and 2024-12-31.
Group by month and return counts per month.
```

---

## ChatGPT Export Queries

### Structure Analysis

```
Analyze this ChatGPT export structure:
- Count total conversations (separate JSON files or single file)
- Identify the mapping structure
- Count total messages
- Report any conversations with images or files attached
```

### Convert to Common Format

```
For each conversation, extract and return in this standardized format:
{
  "title": "conversation title",
  "date": "YYYY-MM-DD",
  "message_count": number,
  "has_code": boolean,
  "topics": ["inferred", "topics"]
}
```

---

## Obsidian-Specific Queries

### Generate Frontmatter Batch

```
For HIGH VALUE conversations, generate Obsidian frontmatter:

---
title: "[conversation name]"
date: "[[YYYY-MM-DD]]"
source: "Claude Export"
import-date: "[[2026-01-25]]"
tags:
  - [inferred tag 1]
  - [inferred tag 2]
status: "🌱"
---

Return as YAML blocks for each conversation.
```

### Generate Wikilinks

```
For each HIGH VALUE conversation, suggest:
1. A note title (max 60 chars)
2. Potential wikilinks to existing concepts (return as [[Concept Name]])
3. Suggested folder path (02 Cards/[subfolder])
```

### Extract Key Insights

```
For the conversation named "[specific name]":
1. Summarize the main topic in 2-3 sentences
2. Extract key decisions or conclusions made
3. List any action items mentioned
4. Identify concepts that could become separate notes
Return in markdown bullet format.
```

---

## Bulk Processing Queries

### Batch Metadata Extraction

```
Extract metadata for ALL conversations (efficient bulk query):
Return as JSON array with:
- uuid
- name (first 50 chars)
- created_at (YYYY-MM-DD)
- message_count
- has_code (boolean)
Limit output to essential fields only.
```

### Chunk Processing (for 100MB+ files)

```
Process conversations 0-99 only.
Return metadata in JSON array format.
[Run multiple times with offset: 100-199, 200-299, etc.]
```

### Deduplication Check

```
Find potential duplicate conversations based on:
- Similar names (fuzzy match)
- Same date with similar message count
- Identical first message
Return pairs of potential duplicates for manual review.
```

---

## Triage Report Generation

### Full Triage Report (Markdown)

```
Generate a complete triage report in this format:

# LLM Export Triage Report

**Source:** [filename]
**Conversations:** [total] total
**Generated:** [today's date]

## Triage Summary

| Value | Count | Action |
|-------|-------|--------|
| HIGH | [n] | Create notes |
| MEDIUM | [n] | Review |
| LOW | [n] | Discard |

## High Value Conversations

### 1. "[conversation name]"
- **Date:** YYYY-MM-DD
- **Messages:** [count]
- **Summary:** [2-3 sentence summary]
- **Suggested Title:** "[title for Obsidian note]"
- **Tags:** #Tag1, #Tag2

[repeat for each HIGH value conversation]

## Medium Value Summary
[bullet list of names only]

## Low Value
[count] conversations recommended for discard
```

---

## Performance Tips

### Fast Queries (< 30 seconds)
- Counts and totals
- Simple filters (by date, by size)
- Metadata extraction

### Medium Queries (30-120 seconds)
- Topic categorization
- Code block detection
- Triage by multiple criteria

### Slow Queries (2-5 minutes)
- Full content analysis
- Summary generation for many conversations
- Complex pattern matching

### Query Optimization

**DO:**
- Ask for counts before details
- Use specific date ranges
- Request JSON output for structured data
- Process in chunks for 100MB+ files

**DON'T:**
- Ask for full text of all conversations at once
- Request multiple complex analyses in one query
- Forget to specify output format

---

## Example Workflow Script

```bash
#!/bin/bash
# Process large Claude export in stages

RLM_URL="http://localhost:4539/query"
EXPORT_FILE="$1"

# Stage 1: Initial analysis
echo "Stage 1: Analyzing export..."
curl -s -X POST "$RLM_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"Count conversations, date range, total messages\",
    \"context_file\": \"$EXPORT_FILE\"
  }" | jq .

# Stage 2: Triage
echo "Stage 2: Generating triage..."
curl -s -X POST "$RLM_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"Categorize by value tier (HIGH/MEDIUM/LOW). Return counts and HIGH VALUE names.\",
    \"context_file\": \"$EXPORT_FILE\"
  }" | jq .

# Stage 3: Generate report
echo "Stage 3: Full triage report..."
curl -s -X POST "$RLM_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"Generate markdown triage report for ContentImporter\",
    \"context_file\": \"$EXPORT_FILE\"
  }" > triage_report.md

echo "Done! Report saved to triage_report.md"
```

---

## Supported File Formats

### Claude/Anthropic Exports

**Structure:**
```json
{
  "conversations": [
    {
      "uuid": "abc123",
      "name": "Project Discussion",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T12:45:00Z",
      "chat_messages": [
        {"sender": "human", "text": "..."},
        {"sender": "assistant", "text": "..."}
      ]
    }
  ]
}
```

**Common RLM Queries:**
- "Count total conversations"
- "List conversation names with dates"
- "Find conversations mentioning [topic]"
- "Extract conversations longer than 20 messages"
- "Identify conversations with code blocks"

### ChatGPT/OpenAI Exports

**Structure:**
```json
{
  "title": "Conversation Title",
  "create_time": 1705312800,
  "mapping": {
    "node_id": {
      "message": {
        "author": {"role": "user|assistant"},
        "content": {"parts": ["..."]}
      }
    }
  }
}
```

**Common RLM Queries:**
- "Count total conversations across all files"
- "List titles with create_time converted to dates"
- "Find conversations about [topic]"
- "Extract conversations with assistant code responses"

---

## RLM Query Patterns for Obsidian

### Pattern 1: Generate Triage Report

**Query:**
```
Analyze this Claude conversations export and generate a triage report:
- Count total conversations
- Categorize by apparent topic (coding, writing, research, general)
- Flag conversations with >50 messages as HIGH VALUE
- Flag conversations with code blocks as HIGH VALUE
- Return as markdown table format
```

**Expected Output:**
```markdown
| Category | Count | High Value |
|----------|-------|------------|
| Coding | 47 | 23 |
| Writing | 18 | 5 |
| Research | 12 | 8 |
| General | 89 | 2 |
| **Total** | **166** | **38** |
```

### Pattern 2: Extract Metadata for Staging

**Query:**
```
For each conversation in this export, extract:
- uuid
- name (truncated to 50 chars)
- created_at date (YYYY-MM-DD format)
- message_count
- has_code_blocks (true/false)
Return as JSON array
```

**Expected Output:**
```json
[
  {"uuid": "abc123", "name": "Project Architecture Discussion", "date": "2024-01-15", "message_count": 67, "has_code": true},
  {"uuid": "def456", "name": "Quick Question About Syntax", "date": "2024-01-14", "message_count": 4, "has_code": false}
]
```

### Pattern 3: Search for Specific Topics

**Query:**
```
Find all conversations that discuss "Obsidian" or "vault" or "PKM".
Return conversation names and relevant excerpt (first 200 chars of matching message).
```

### Pattern 4: Generate Frontmatter Batch

**Query:**
```
For HIGH VALUE conversations (>30 messages or contains code), generate Obsidian frontmatter:
- title: conversation name
- date: created_at
- tags: [inferred from content]
- source: "Claude Export"
- import-date: "[[2026-01-25]]"
Return as YAML blocks ready for copy-paste
```
