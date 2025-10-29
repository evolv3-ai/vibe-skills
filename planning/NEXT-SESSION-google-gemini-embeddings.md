# Session Handoff: google-gemini-embeddings Skill

**Date**: 2025-10-25
**Status**: Ready to Start
**Priority**: High (completes Gemini API coverage)
**Estimated Time**: 3-4 hours

---

## What Was Just Completed

✅ **google-gemini-api Phase 2 Expansion**
- Context Caching (cost optimization)
- Code Execution (Python sandbox)
- Grounding with Google Search (real-time info)
- 4 new templates, 3 new reference docs
- 7 new errors documented
- Committed: 1b9537a

---

## What's Next: google-gemini-embeddings Skill

### Overview

Create a **separate atomic skill** for Google Gemini embeddings API (text-embedding-004). This is a distinct use case from the main API, so it deserves its own skill.

### Why Separate Skill?

1. **Atomic Skills Philosophy**: Embeddings is a distinct domain (vector search, RAG, semantic search)
2. **Composability**: Users can combine with cloudflare-vectorize skill
3. **Token Efficiency**: Only loads when needed for embeddings use cases
4. **Maintainability**: Easier to update embeddings-specific content

### Target Metrics

- **Token Savings**: ~60% (vs building RAG from scratch)
- **Errors Prevented**: 8+ embedding-specific issues
- **Development Time**: 3-4 hours
- **Package**: @google/genai@1.27.0 (same SDK)

---

## Research Required

### 1. Context7 Lookup

```typescript
// Use Context7 to get latest embeddings API docs
mcp__context7__get-library-docs({
  context7CompatibleLibraryID: '/websites/ai_google_dev_gemini-api',
  topic: 'embeddings text-embedding-004 embed content batch embeddings',
  tokens: 8000
})
```

### 2. Official Documentation

- **Embeddings Guide**: https://ai.google.dev/gemini-api/docs/embeddings
- **Model**: text-embedding-004 (768 dimensions)
- **API endpoint**: `/v1beta/models/text-embedding-004:embedContent`

### 3. Key Questions to Answer

- [ ] How to generate embeddings (single text)
- [ ] How to batch embed multiple texts
- [ ] What are the dimension options? (768 default)
- [ ] Task types: RETRIEVAL_QUERY vs RETRIEVAL_DOCUMENT
- [ ] Rate limits and quotas
- [ ] Integration with Vectorize
- [ ] Cost per token

---

## Skill Structure to Create

```
skills/google-gemini-embeddings/
├── README.md                          # Auto-trigger keywords
├── SKILL.md                           # Complete guide (600-800 lines)
├── templates/
│   ├── package.json
│   ├── basic-embeddings.ts            # Single text embedding
│   ├── embeddings-fetch.ts            # Cloudflare Workers fetch
│   ├── batch-embeddings.ts            # Bulk processing
│   ├── rag-with-vectorize.ts          # Complete RAG pattern
│   ├── semantic-search.ts             # Similarity search
│   ├── clustering.ts                  # Document clustering
│   └── dimension-comparison.ts        # 768 vs other models
├── references/
│   ├── model-comparison.md            # text-embedding-004 vs others
│   ├── vectorize-integration.md       # Cloudflare Vectorize patterns
│   ├── rag-patterns.md                # Retrieval augmented generation
│   ├── dimension-guide.md             # When to use 768d
│   └── top-errors.md                  # 8 embedding errors
└── scripts/
    └── check-versions.sh              # Package version checker
```

---

## SKILL.md Structure (600-800 lines)

### Table of Contents

1. **Quick Start**
   - Installation (@google/genai@1.27.0)
   - Environment setup (GEMINI_API_KEY)
   - First embedding example

2. **text-embedding-004 Model**
   - Dimensions: 768 (fixed)
   - Task types (RETRIEVAL_QUERY, RETRIEVAL_DOCUMENT)
   - Context window
   - Output format

3. **Basic Embeddings**
   - Single text (SDK)
   - Single text (fetch - Cloudflare Workers)
   - Response structure

4. **Batch Embeddings**
   - Multiple texts in one request
   - Rate limits and chunking
   - Performance optimization

5. **Task Types**
   - RETRIEVAL_QUERY: User queries
   - RETRIEVAL_DOCUMENT: Document indexing
   - When to use which

6. **RAG Patterns**
   - Complete RAG workflow
   - Integration with Cloudflare Vectorize
   - Query flow (embed query → search → retrieve → generate)
   - Document ingestion pipeline

7. **Semantic Search**
   - Cosine similarity calculation
   - Vector normalization
   - Search algorithms

8. **Document Clustering**
   - K-means clustering with embeddings
   - Similarity thresholds
   - Use cases

9. **Error Handling**
   - Common errors
   - Rate limiting
   - Token limits

10. **Best Practices**
    - Always do / never do
    - Cost optimization
    - Performance tips

---

## Templates to Create (7 total)

### 1. package.json
```json
{
  "dependencies": {
    "@google/genai": "^1.27.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

### 2. basic-embeddings.ts
- Single text embedding
- SDK approach
- Response parsing

### 3. embeddings-fetch.ts
- Fetch-based for Cloudflare Workers
- No SDK dependencies
- REST API direct

### 4. batch-embeddings.ts
- Process multiple texts
- Chunking for rate limits
- Progress tracking

### 5. rag-with-vectorize.ts (CRITICAL - integration pattern)
- Complete RAG implementation
- Vectorize index creation
- Document ingestion
- Query flow with streaming response
- Shows how to combine with cloudflare-vectorize skill

### 6. semantic-search.ts
- Cosine similarity
- Vector normalization
- Top-k search

### 7. clustering.ts
- K-means clustering
- Similarity grouping
- Visualization

---

## Reference Docs to Create (5 total)

### 1. model-comparison.md
- text-embedding-004 (768d) - Gemini
- text-embedding-3-small (1536d) - OpenAI
- text-embedding-3-large (3072d) - OpenAI
- BGE-base-en-v1.5 (768d) - Workers AI
- When to use which

### 2. vectorize-integration.md
- Cloudflare Vectorize setup
- Index creation (768 dimensions for Gemini)
- Insert embeddings
- Query patterns
- Metadata filtering

### 3. rag-patterns.md
- Document chunking strategies
- Embedding generation workflow
- Storage in Vectorize
- Retrieval with similarity search
- Response generation with context
- Complete end-to-end examples

### 4. dimension-guide.md
- Why 768 dimensions?
- Trade-offs (accuracy vs storage/compute)
- Comparison with other embedding models
- Use case recommendations

### 5. top-errors.md (8 errors)
1. Dimension mismatch (768 vs 1536 vs 3072)
2. Batch size limits exceeded
3. Rate limiting errors
4. Text truncation (input length limits)
5. Cosine similarity calculation errors
6. Vector normalization mistakes
7. Incorrect task type (RETRIEVAL_QUERY vs RETRIEVAL_DOCUMENT)
8. Embedding model version confusion

---

## README.md Keywords (Comprehensive List)

### Primary Keywords
- `gemini embeddings`
- `text-embedding-004`
- `google embeddings`
- `gemini embed`
- `@google/genai embeddings`

### Use Cases
- `semantic search gemini`
- `rag gemini`
- `vector search gemini`
- `document clustering gemini`
- `similarity search gemini`
- `retrieval augmented generation gemini`

### Technical
- `768 dimensions`
- `embed content gemini`
- `batch embeddings gemini`
- `embeddings api gemini`
- `cosine similarity gemini`
- `vector normalization`

### Integration
- `vectorize gemini`
- `cloudflare vectorize embeddings`
- `rag vectorize`
- `gemini embeddings workers`

### Task Types
- `retrieval query gemini`
- `retrieval document gemini`
- `embedding task types`

### Errors
- `dimension mismatch embeddings`
- `embeddings rate limit`
- `text truncation embeddings`
- `batch size limit embeddings`

---

## Known Issues to Document

### From Research/Experience

1. **Dimension Mismatch**
   - Gemini: 768d (fixed)
   - OpenAI small: 1536d
   - OpenAI large: 3072d
   - **Error**: Vectorize index created with wrong dimensions

2. **Batch Size Limits**
   - Max texts per request: [Need to research]
   - Rate limits: [Need to research]

3. **Task Type Confusion**
   - RETRIEVAL_QUERY: For user questions
   - RETRIEVAL_DOCUMENT: For documents to index
   - **Error**: Using wrong type reduces search quality

4. **Text Truncation**
   - Max input length: [Need to research]
   - No warning if truncated
   - **Error**: Incomplete embeddings

5. **Cosine Similarity Errors**
   - Not normalizing vectors
   - Incorrect formula
   - **Error**: Wrong similarity scores

6. **Vector Storage**
   - Storing raw floats vs normalized
   - Precision loss
   - **Error**: Search quality degradation

7. **Chunking Strategy**
   - Chunk size too large/small
   - No overlap
   - **Error**: Missing context in search

8. **Model Version**
   - Using old embedding models
   - Mixing model outputs
   - **Error**: Incompatible vectors

---

## Integration Points

### With Other Skills

**cloudflare-vectorize**:
```typescript
// 1. Generate embeddings with Gemini
const embedding = await ai.models.embedContent({
  model: 'text-embedding-004',
  content: documentText
});

// 2. Store in Vectorize (from cloudflare-vectorize skill)
await env.VECTORIZE.insert([{
  id: 'doc-1',
  values: embedding.values,
  metadata: { text: documentText }
}]);

// 3. Query
const queryEmbedding = await ai.models.embedContent({
  model: 'text-embedding-004',
  content: userQuery
});

const results = await env.VECTORIZE.query(queryEmbedding.values, { topK: 5 });
```

**google-gemini-api** (for generation):
```typescript
// 1. Embed query
// 2. Search Vectorize
// 3. Generate response with context
const response = await ai.models.generateContent({
  model: 'gemini-2.5-flash',
  contents: `Context: ${retrievedDocs}\n\nQuestion: ${userQuery}`
});
```

---

## Quick Start Checklist

When you resume, follow this order:

### Phase 1: Research (30 min)
- [ ] Use Context7 to fetch embeddings API docs
- [ ] Read official Google embeddings guide
- [ ] Identify API endpoints and parameters
- [ ] Document task types (RETRIEVAL_QUERY vs RETRIEVAL_DOCUMENT)
- [ ] Find rate limits, token limits, dimensions

### Phase 2: Structure (15 min)
- [ ] Copy skill skeleton template
- [ ] Create directory structure
- [ ] Set up package.json

### Phase 3: SKILL.md (90 min)
- [ ] Write Quick Start section
- [ ] Document text-embedding-004 model
- [ ] Add basic embeddings (SDK + fetch)
- [ ] Add batch embeddings
- [ ] Add task types explanation
- [ ] Add RAG patterns
- [ ] Add semantic search
- [ ] Add clustering
- [ ] Add error handling
- [ ] Add best practices

### Phase 4: Templates (60 min)
- [ ] Create package.json
- [ ] Create basic-embeddings.ts
- [ ] Create embeddings-fetch.ts
- [ ] Create batch-embeddings.ts
- [ ] Create rag-with-vectorize.ts (IMPORTANT!)
- [ ] Create semantic-search.ts
- [ ] Create clustering.ts

### Phase 5: References (45 min)
- [ ] Create model-comparison.md
- [ ] Create vectorize-integration.md
- [ ] Create rag-patterns.md
- [ ] Create dimension-guide.md
- [ ] Create top-errors.md

### Phase 6: README.md (20 min)
- [ ] Write skill description
- [ ] Add all auto-trigger keywords
- [ ] Add when to use / when not to use
- [ ] Add quick example
- [ ] Add known issues table
- [ ] Add token efficiency metrics

### Phase 7: Testing & Verification (20 min)
- [ ] Install skill: `./scripts/install-skill.sh google-gemini-embeddings`
- [ ] Verify auto-discovery works
- [ ] Check all templates compile
- [ ] Verify integration with Vectorize examples

### Phase 8: Finalize (10 min)
- [ ] Update planning/skills-roadmap.md
- [ ] Commit with detailed message
- [ ] Push to GitHub

**Total Estimated Time**: 3-4 hours

---

## Context7 Library ID

```
/websites/ai_google_dev_gemini-api
```

**Topics to search**:
- embeddings
- text-embedding-004
- embed content
- batch embeddings
- retrieval query
- retrieval document

---

## Example Queries for Research

When you start, ask these to Context7:

1. "How do I generate embeddings with text-embedding-004?"
2. "What are the task types for Gemini embeddings?"
3. "How do I batch embed multiple texts?"
4. "What are the rate limits for Gemini embeddings API?"
5. "How do I integrate Gemini embeddings with vector search?"

---

## Success Criteria

Skill is complete when:

✅ SKILL.md has 600-800 lines with all 10 sections
✅ 7 templates created and tested
✅ 5 reference docs created
✅ README.md has 50+ auto-trigger keywords
✅ 8+ errors documented with solutions
✅ RAG pattern with Vectorize integration works
✅ Token savings >= 60%
✅ Auto-discovery works in Claude Code
✅ Committed and pushed to GitHub

---

## Notes

- **Same SDK**: Uses @google/genai@1.27.0 (same as main API skill)
- **Fixed Dimensions**: text-embedding-004 always outputs 768 dimensions
- **Atomic Design**: Should NOT duplicate content from google-gemini-api skill
- **Integration Focus**: Strong emphasis on Vectorize + RAG patterns
- **Production Value**: Complete RAG implementation is the killer feature

---

## Resources

**Official Docs**:
- https://ai.google.dev/gemini-api/docs/embeddings
- https://ai.google.dev/gemini-api/docs/models/gemini#text-embedding-004

**Related Skills**:
- google-gemini-api (main API - already complete)
- cloudflare-vectorize (vector database - already complete)

**Templates Reference**:
- Use google-gemini-api templates as style guide
- Use cloudflare-vectorize for Vectorize integration patterns

---

## Ready to Start?

1. Open fresh Claude Code session
2. Read this document
3. Start with Phase 1 (Research)
4. Follow the checklist

**Good luck! This will complete the Gemini API coverage and provide a production-ready RAG skill.**
