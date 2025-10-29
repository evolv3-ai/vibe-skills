# AI SDK Core - Skill Specification

**Created**: 2025-10-21
**Status**: Planning Phase
**Priority**: High (Batch 2 - Do First)
**Estimated Dev Time**: 6-8 hours
**Token Savings**: ~55-60%
**Errors Prevented**: 10-12 documented issues

---

## Overview

**Purpose**: Backend/server-side AI functionality using Vercel AI SDK v5 - text generation, structured output, tool calling, and agents.

**Target Platforms**:
- Node.js (primary)
- Cloudflare Workers (workers-ai-provider as one option)
- Next.js Server Components & Server Actions (Vercel focus)
- Any JavaScript runtime

**Focus Providers** (in order of priority):
1. OpenAI (GPT-4, GPT-3.5, gpt-5)
2. Anthropic (Claude 3.5 Sonnet, Claude 3 Opus/Haiku)
3. Google (Gemini 2.5 Pro/Flash)
4. Cloudflare Workers AI (workers-ai-provider)
5. Others mentioned but not detailed (xAI, Mistral, Azure, Bedrock)

**Version**: AI SDK v5 (stable) - Focus on v5.0.76+

---

## Skill Structure

```
skills/ai-sdk-core/
├── SKILL.md                           # ~800-1000 lines
├── README.md                          # Auto-trigger keywords
├── templates/
│   ├── generate-text-basic.ts         # Simple text generation
│   ├── stream-text-chat.ts            # Streaming chat with messages
│   ├── generate-object-zod.ts         # Structured output with Zod
│   ├── stream-object-zod.ts           # Streaming structured output
│   ├── tools-basic.ts                 # Tool calling basics
│   ├── agent-with-tools.ts            # Agent class usage
│   ├── multi-step-execution.ts        # stopWhen patterns
│   ├── openai-setup.ts                # OpenAI provider config
│   ├── anthropic-setup.ts             # Anthropic provider config
│   ├── google-setup.ts                # Google provider config
│   ├── cloudflare-worker-integration.ts  # CF Workers with workers-ai-provider
│   ├── nextjs-server-action.ts        # Next.js Server Action example
│   └── package.json                   # Dependencies template
├── references/
│   ├── providers-quickstart.md        # Top 4 providers setup
│   ├── v5-breaking-changes.md         # Critical v4→v5 migrations
│   ├── top-errors.md                  # 10-12 most common errors
│   ├── production-patterns.md         # Best practices
│   └── links-to-official-docs.md      # Where to find advanced topics
└── scripts/
    └── check-versions.sh              # Package version checker
```

---

## SKILL.md Outline

### 1. Frontmatter (YAML)
```yaml
---
name: AI SDK Core
description: |
  Backend AI functionality with Vercel AI SDK v5 - text generation, structured output with Zod,
  tool calling, and agents. Multi-provider support for OpenAI, Anthropic, Google, and Cloudflare Workers AI.

  Use when: implementing server-side AI features, generating text/chat completions, creating structured
  AI outputs with Zod schemas, building AI agents with tools, streaming AI responses, integrating
  OpenAI/Anthropic/Google/Cloudflare providers, or encountering AI SDK errors like AI_APICallError,
  AI_NoObjectGeneratedError, streaming failures, or worker startup limits.

  Keywords: ai sdk core, vercel ai sdk, generateText, streamText, generateObject, streamObject,
  ai sdk node, ai sdk server, zod ai schema, ai tools calling, ai agent class, openai sdk, anthropic sdk,
  google gemini sdk, workers-ai-provider, ai streaming backend, multi-provider ai, ai sdk errors,
  AI_APICallError, AI_NoObjectGeneratedError, streamText fails, worker startup limit ai
license: MIT
---
```

### 2. Quick Start (5-10 minutes)
- Installation (ai + provider packages)
- Environment variables setup
- First generateText example (OpenAI)
- First streamText example (streaming chat)
- First generateObject example (Zod schema)

### 3. Core Functions Deep Dive

#### generateText()
- Signature and parameters
- Basic usage
- With messages (chat format)
- With tools
- Multi-step execution
- Error handling
- When to use vs streamText

#### streamText()
- Signature and parameters
- Basic streaming
- Streaming with tools
- Handling the stream
- Error handling
- Production patterns

#### generateObject()
- Signature and parameters
- Zod schema definition
- Basic usage
- Nested schemas
- Arrays and unions
- Error handling (AI_NoObjectGeneratedError)
- When to use vs streamObject

#### streamObject()
- Signature and parameters
- Streaming structured data
- Partial updates
- UI integration patterns
- Error handling

### 4. Provider Setup & Configuration

#### OpenAI
```typescript
import { openai } from '@ai-sdk/openai';

const model = openai('gpt-4-turbo');
const result = await generateText({
  model,
  prompt: 'Hello',
});
```
- API key setup
- Model selection (gpt-4, gpt-3.5-turbo, gpt-5)
- Common errors
- Rate limiting

#### Anthropic
```typescript
import { anthropic } from '@ai-sdk/anthropic';

const model = anthropic('claude-3-5-sonnet-20241022');
```
- API key setup
- Model selection (Claude 3.5 Sonnet, Opus, Haiku)
- Common errors

#### Google
```typescript
import { google } from '@ai-sdk/google';

const model = google('gemini-2.5-pro');
```
- API key setup
- Model selection (Gemini 2.5 Pro/Flash)
- Common errors

#### Cloudflare Workers AI
```typescript
import { createWorkersAI } from 'workers-ai-provider';

const workersai = createWorkersAI({ binding: env.AI });
const model = workersai('@cf/meta/llama-3.1-8b-instruct');
```
- Workers AI binding setup
- wrangler.jsonc configuration
- Worker startup optimization (avoid 270ms+ init)
- Model selection
- Link to cloudflare-workers-ai skill for native binding

### 5. Tool Calling & Agents

#### Basic Tool Definition
```typescript
const tools = {
  weather: tool({
    description: 'Get weather',
    inputSchema: z.object({
      location: z.string(),
    }),
    execute: async ({ location }) => {
      // Implementation
    },
  }),
};
```

#### Agent Class
- When to use Agent vs raw generateText
- Basic agent setup
- Multi-tool agents
- Dynamic tools (new in v5)
- Agent error handling

#### Multi-Step Execution
- stopWhen conditions
- stepCountIs() usage
- hasToolCall() usage
- Max steps vs stopWhen (v5 change)

### 6. Critical v4→v5 Migration

**Breaking Changes Developers Hit:**
1. `maxTokens` → `maxOutputTokens`
2. `providerMetadata` → `providerOptions`
3. Tool definitions: `parameters` → `inputSchema`
4. Tool properties: `args` → `input`, `result` → `output`
5. `ToolExecutionError` removed (now tool-error parts)
6. `maxSteps` → `stopWhen`
7. Message types: `CoreMessage` → `ModelMessage`
8. Streaming architecture changed
9. Package imports changed (ai/rsc → @ai-sdk/rsc)

**Migration Checklist:**
- [ ] Update parameter names
- [ ] Update tool definitions
- [ ] Replace maxSteps with stopWhen
- [ ] Update error handling (no ToolExecutionError)
- [ ] Update imports (@ai-sdk packages)
- [ ] Test streaming behavior
- [ ] Update TypeScript types

### 7. Top 10-12 Errors & Solutions

**Priority Errors to Document:**

1. **AI_APICallError**
   - Cause: API request failed (network, auth, rate limit)
   - Solution: Check API key, handle retries, check rate limits
   - Example code

2. **AI_NoObjectGeneratedError**
   - Cause: Model didn't generate valid object matching schema
   - Solution: Simplify schema, add examples, retry with different model
   - Example code

3. **Worker Startup Limit (270ms+)**
   - Cause: AI SDK v5 + Zod initialization overhead
   - Solution: Move imports inside handler, reduce Zod schemas at top level
   - Example code
   - Link to GitHub issue

4. **streamText Fails Silently**
   - Cause: Stream errors swallowed by createDataStreamResponse
   - Solution: Add explicit error handling, check logs
   - Example code
   - Link to GitHub issue

5. **AI_LoadAPIKeyError**
   - Cause: Missing or invalid API key
   - Solution: Check .env file, verify key format
   - Example code

6. **AI_InvalidArgumentError**
   - Cause: Invalid parameters passed to function
   - Solution: Check types, validate inputs
   - Example code

7. **AI_NoContentGeneratedError**
   - Cause: Model generated no content
   - Solution: Check prompt, retry, handle gracefully
   - Example code

8. **AI_TypeValidationError**
   - Cause: Zod schema validation failed
   - Solution: Check schema matches expected output
   - Example code

9. **AI_RetryError**
   - Cause: All retry attempts failed
   - Solution: Check root cause, adjust retry config
   - Example code

10. **Rate Limiting Errors**
    - Cause: Exceeded provider rate limits
    - Solution: Implement backoff, queue requests
    - Example code

**For Other Errors**: Link to https://ai-sdk.dev/docs/reference/ai-sdk-errors

### 8. Production Best Practices

**Performance:**
- Always use streaming for long-form content
- Implement proper error boundaries
- Use appropriate maxOutputTokens limits
- Cache provider instances
- Optimize Zod schemas (avoid complex nesting at startup)

**Error Handling:**
- Wrap all AI calls in try-catch
- Handle specific error types
- Implement retry logic
- Log errors properly
- Return user-friendly messages

**Cost Optimization:**
- Choose appropriate models (gpt-3.5 vs gpt-4)
- Set maxOutputTokens appropriately
- Cache results when possible
- Use streaming to reduce buffering

**Cloudflare Workers Specific:**
- Move AI SDK imports inside handlers (not top-level)
- Use workers-ai-provider for Workers AI
- Monitor startup time (must be <400ms)
- Handle streaming properly (ReadableStream)

**Vercel/Next.js Specific:**
- Use Server Actions for mutations
- Use Server Components for initial loads
- Implement proper loading states
- Handle errors in Server Actions
- Link to Vercel deployment docs

### 9. When to Use This Skill

**Use ai-sdk-core when:**
- Building backend AI features
- Implementing server-side text generation
- Creating structured AI outputs (JSON, forms, etc.)
- Building AI agents with tools
- Integrating multiple AI providers
- Migrating from v4 to v5
- Encountering AI SDK errors
- Building Node.js AI applications
- Using AI in Cloudflare Workers
- Using AI in Next.js Server Components/Actions

**Don't use when:**
- Building React chat UIs (use ai-sdk-ui instead)
- Need frontend hooks (use ai-sdk-ui instead)
- Need advanced topics like embeddings (check official docs)
- Building native Workers AI apps (use cloudflare-workers-ai skill)

### 10. Dependencies & Versions

**Required Packages:**
```json
{
  "dependencies": {
    "ai": "^5.0.76",
    "@ai-sdk/openai": "^2.0.53",
    "@ai-sdk/anthropic": "^2.0.x",
    "@ai-sdk/google": "^2.0.x",
    "workers-ai-provider": "^2.0.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.x.x",
    "typescript": "^5.x.x"
  }
}
```

**Version Notes:**
- AI SDK v5.0.76+ (stable, released recently with breaking changes)
- Zod 3.23.8+ (required for schemas)
- Provider packages at 2.0+ (v5 compatible)

### 11. Links to Official Documentation

**Core Docs:**
- AI SDK Introduction: https://ai-sdk.dev/docs/introduction
- AI SDK Core: https://ai-sdk.dev/docs/ai-sdk-core/overview
- Generating Text: https://ai-sdk.dev/docs/ai-sdk-core/generating-text
- Generating Objects: https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data
- Tool Calling: https://ai-sdk.dev/docs/ai-sdk-core/tools-and-tool-calling
- Agents: https://ai-sdk.dev/docs/agents/overview

**Advanced Topics (Link Only):**
- Embeddings: https://ai-sdk.dev/docs/ai-sdk-core/embeddings
- Image Generation: https://ai-sdk.dev/docs/ai-sdk-core/generating-images
- Transcription: https://ai-sdk.dev/docs/ai-sdk-core/generating-transcriptions
- Speech: https://ai-sdk.dev/docs/ai-sdk-core/generating-speech
- MCP Tools: https://ai-sdk.dev/docs/ai-sdk-core/mcp-tools
- Telemetry: https://ai-sdk.dev/docs/ai-sdk-core/telemetry

**Migration & Troubleshooting:**
- v4→v5 Migration: https://ai-sdk.dev/docs/migration-guides/migration-guide-5-0
- All Errors Reference: https://ai-sdk.dev/docs/reference/ai-sdk-errors
- Full Troubleshooting: https://ai-sdk.dev/docs/troubleshooting

**Provider Docs:**
- OpenAI Provider: https://ai-sdk.dev/providers/ai-sdk-providers/openai
- Anthropic Provider: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- Google Provider: https://ai-sdk.dev/providers/ai-sdk-providers/google
- All Providers: https://ai-sdk.dev/providers/overview

**Cloudflare Integration:**
- Workers AI Provider (Community): https://ai-sdk.dev/providers/community-providers/cloudflare-workers-ai
- Cloudflare Workers AI Docs: https://developers.cloudflare.com/workers-ai/
- workers-ai-provider GitHub: https://github.com/cloudflare/ai

**Vercel Deployment:**
- Vercel AI SDK Blog: https://vercel.com/blog/ai-sdk-5
- Next.js Integration: https://ai-sdk.dev/docs/getting-started/nextjs-app-router
- Vercel Functions: https://vercel.com/docs/functions

---

## README.md Keywords

### Primary Keywords (High Weight)
- `ai sdk core`, `vercel ai sdk`, `ai sdk v5`
- `generateText`, `streamText`, `generate text ai`
- `generateObject`, `streamObject`, `structured ai output`
- `ai sdk node`, `ai sdk server`, `ai sdk backend`
- `zod ai schema`, `zod ai validation`
- `ai tools calling`, `ai agent class`, `agent with tools`
- `openai sdk`, `anthropic sdk`, `google gemini sdk`
- `multi-provider ai`, `ai provider switching`

### Secondary Keywords (Medium Weight)
- `ai streaming backend`, `stream ai responses`
- `ai server actions`, `nextjs ai server`
- `cloudflare workers ai sdk`, `workers-ai-provider`
- `ai sdk migration`, `v4 to v5 migration`
- `ai chat completion`, `llm text generation`
- `ai sdk typescript`, `typed ai responses`
- `stopWhen ai sdk`, `multi-step ai execution`
- `dynamic tools ai`, `runtime tools ai`

### Error Keywords (Trigger on Errors)
- `AI_APICallError`, `ai api call error`
- `AI_NoObjectGeneratedError`, `no object generated`
- `AI_LoadAPIKeyError`, `ai api key error`
- `AI_InvalidArgumentError`, `invalid argument ai`
- `AI_TypeValidationError`, `zod validation failed`
- `AI_RetryError`, `ai retry failed`
- `streamText fails silently`, `stream error swallowed`
- `worker startup limit ai sdk`, `270ms startup`
- `ai rate limit`, `rate limiting ai`
- `maxTokens maxOutputTokens`, `v5 breaking changes`
- `providerMetadata providerOptions`, `tool inputSchema`
- `ToolExecutionError removed`, `tool-error parts`

### Framework Keywords
- `nextjs ai sdk`, `next.js server actions ai`
- `cloudflare workers ai integration`
- `node.js ai sdk`, `nodejs llm`
- `vercel ai deployment`, `serverless ai`

### Provider Keywords
- `openai integration`, `gpt-4 api`, `chatgpt api`
- `anthropic claude`, `claude api integration`
- `google gemini api`, `gemini integration`
- `cloudflare llama`, `workers ai llm`

---

## Templates to Create

### 1. generate-text-basic.ts
```typescript
// Simple text generation with OpenAI
import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';

const result = await generateText({
  model: openai('gpt-4-turbo'),
  prompt: 'What is TypeScript?',
});

console.log(result.text);
```

### 2. stream-text-chat.ts
```typescript
// Streaming chat with messages
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

const stream = streamText({
  model: anthropic('claude-3-5-sonnet-20241022'),
  messages: [
    { role: 'user', content: 'Tell me a story' },
  ],
});

for await (const chunk of stream.textStream) {
  process.stdout.write(chunk);
}
```

### 3. generate-object-zod.ts
```typescript
// Structured output with Zod
import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

const result = await generateObject({
  model: openai('gpt-4'),
  schema: z.object({
    name: z.string(),
    age: z.number(),
    skills: z.array(z.string()),
  }),
  prompt: 'Generate a person profile for a software engineer',
});

console.log(result.object);
// { name: "Alice", age: 28, skills: ["TypeScript", "React"] }
```

### 4. stream-object-zod.ts
```typescript
// Streaming structured output
import { streamObject } from 'ai';
import { google } from '@ai-sdk/google';
import { z } from 'zod';

const stream = streamObject({
  model: google('gemini-2.5-pro'),
  schema: z.object({
    items: z.array(z.object({
      name: z.string(),
      price: z.number(),
    })),
  }),
  prompt: 'Generate a shopping list',
});

for await (const partialObject of stream.partialObjectStream) {
  console.log(partialObject);
}
```

### 5. tools-basic.ts
```typescript
// Basic tool calling
import { generateText, tool } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

const result = await generateText({
  model: openai('gpt-4'),
  tools: {
    weather: tool({
      description: 'Get the weather for a location',
      inputSchema: z.object({
        location: z.string().describe('The city name'),
      }),
      execute: async ({ location }) => {
        // Simulate API call
        return { temperature: 72, condition: 'sunny' };
      },
    }),
  },
  prompt: 'What is the weather in San Francisco?',
});

console.log(result.text);
```

### 6. agent-with-tools.ts
```typescript
// Agent class with tools
import { Agent, tool } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';
import { z } from 'zod';

const weatherAgent = new Agent({
  model: anthropic('claude-3-5-sonnet-20241022'),
  tools: {
    getWeather: tool({
      description: 'Get weather for a location',
      inputSchema: z.object({
        location: z.string(),
      }),
      execute: async ({ location }) => {
        return { temp: 72, condition: 'sunny' };
      },
    }),
    convertTemp: tool({
      description: 'Convert Fahrenheit to Celsius',
      inputSchema: z.object({
        fahrenheit: z.number(),
      }),
      execute: async ({ fahrenheit }) => {
        return { celsius: (fahrenheit - 32) * 5/9 };
      },
    }),
  },
  system: 'You are a weather assistant.',
});

const result = await weatherAgent.run({
  messages: [
    { role: 'user', content: 'What is the weather in SF in Celsius?' },
  ],
});

console.log(result.text);
```

### 7. multi-step-execution.ts
```typescript
// Multi-step execution with stopWhen
import { generateText, stopWhen, stepCountIs } from 'ai';
import { openai } from '@ai-sdk/openai';

const result = await generateText({
  model: openai('gpt-4'),
  tools: { /* tools here */ },
  prompt: 'Research TypeScript and create a summary',
  stopWhen: stepCountIs(5), // Stop after 5 steps
  // Or: stopWhen: hasToolCall('finalizeReport')
});
```

### 8. openai-setup.ts
```typescript
// OpenAI provider configuration
import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';

// Using environment variable (recommended)
// OPENAI_API_KEY=sk-...
const model = openai('gpt-4-turbo');

// Or explicit API key
const model = openai('gpt-4', {
  apiKey: process.env.OPENAI_API_KEY,
});

// Available models
const gpt4 = openai('gpt-4-turbo');
const gpt35 = openai('gpt-3.5-turbo');
const gpt5 = openai('gpt-5'); // If available

const result = await generateText({
  model: gpt4,
  prompt: 'Hello',
});
```

### 9. anthropic-setup.ts
```typescript
// Anthropic provider configuration
import { anthropic } from '@ai-sdk/anthropic';

// ANTHROPIC_API_KEY=sk-ant-...
const claude = anthropic('claude-3-5-sonnet-20241022');

// Available models
const sonnet = anthropic('claude-3-5-sonnet-20241022');
const opus = anthropic('claude-3-opus-20240229');
const haiku = anthropic('claude-3-haiku-20240307');

const result = await generateText({
  model: sonnet,
  prompt: 'Hello',
});
```

### 10. google-setup.ts
```typescript
// Google provider configuration
import { google } from '@ai-sdk/google';

// GOOGLE_GENERATIVE_AI_API_KEY=...
const gemini = google('gemini-2.5-pro');

// Available models
const pro = google('gemini-2.5-pro');
const flash = google('gemini-2.5-flash');

const result = await generateText({
  model: pro,
  prompt: 'Hello',
});
```

### 11. cloudflare-worker-integration.ts
```typescript
// Cloudflare Workers with workers-ai-provider
import { Hono } from 'hono';
import { generateText } from 'ai';
import { createWorkersAI } from 'workers-ai-provider';

interface Env {
  AI: Ai;
}

const app = new Hono<{ Bindings: Env }>();

app.post('/chat', async (c) => {
  // Create provider inside handler (avoid startup overhead)
  const workersai = createWorkersAI({ binding: c.env.AI });

  const result = await generateText({
    model: workersai('@cf/meta/llama-3.1-8b-instruct'),
    prompt: 'What is Cloudflare?',
  });

  return c.json({ response: result.text });
});

export default app;
```

**wrangler.jsonc:**
```jsonc
{
  "name": "ai-sdk-worker",
  "compatibility_date": "2025-10-21",
  "ai": {
    "binding": "AI"
  }
}
```

**Important Notes:**
- Move `createWorkersAI` inside handler to avoid startup overhead
- Don't import heavy dependencies at top level
- Monitor startup time (must be <400ms)
- For pure Workers AI usage without multi-provider, use cloudflare-workers-ai skill instead

### 12. nextjs-server-action.ts
```typescript
// Next.js Server Action with AI SDK
'use server';

import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

export async function generateRecipe(ingredients: string[]) {
  const result = await generateObject({
    model: openai('gpt-4'),
    schema: z.object({
      name: z.string(),
      ingredients: z.array(z.string()),
      instructions: z.array(z.string()),
    }),
    prompt: `Create a recipe using: ${ingredients.join(', ')}`,
  });

  return result.object;
}
```

**Usage in component:**
```typescript
'use client';

import { generateRecipe } from './actions';
import { useState } from 'react';

export default function RecipeGenerator() {
  const [recipe, setRecipe] = useState(null);

  async function handleSubmit(formData: FormData) {
    const ingredients = formData.get('ingredients')?.toString().split(',') || [];
    const result = await generateRecipe(ingredients);
    setRecipe(result);
  }

  return (
    <form action={handleSubmit}>
      <input name="ingredients" placeholder="flour, eggs, sugar" />
      <button type="submit">Generate Recipe</button>
      {recipe && <pre>{JSON.stringify(recipe, null, 2)}</pre>}
    </form>
  );
}
```

### 13. package.json
```json
{
  "name": "ai-sdk-core-example",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc"
  },
  "dependencies": {
    "ai": "^5.0.76",
    "@ai-sdk/openai": "^2.0.53",
    "@ai-sdk/anthropic": "^2.0.0",
    "@ai-sdk/google": "^2.0.0",
    "workers-ai-provider": "^2.0.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "tsx": "^4.7.0",
    "typescript": "^5.3.3"
  }
}
```

---

## References to Create

### 1. providers-quickstart.md
- OpenAI setup (API key, models, common errors)
- Anthropic setup (API key, models, common errors)
- Google setup (API key, models, common errors)
- Cloudflare Workers AI setup (binding, models, startup optimization)
- Quick comparison table
- Link to full providers list in official docs

### 2. v5-breaking-changes.md
- All critical breaking changes (15+ items)
- Before/after code examples
- Migration checklist
- Common migration errors
- Link to official migration guide

### 3. top-errors.md
- Top 10-12 errors with:
  - Error name and type
  - What causes it
  - How to fix it
  - Example code
  - Link to official docs (if available)
  - GitHub issue (if available)

### 4. production-patterns.md
- Performance optimization
- Error handling strategies
- Cost optimization
- Cloudflare Workers best practices
- Vercel/Next.js best practices
- Monitoring and logging
- Rate limiting handling

### 5. links-to-official-docs.md
- Organized list of all official docs links
- What each link covers
- When to use each resource
- Advanced topics (embeddings, image gen, etc.)

---

## Scripts to Create

### check-versions.sh
```bash
#!/bin/bash
# Check installed versions against latest

echo "Checking AI SDK Core package versions..."
echo ""

packages=(
  "ai"
  "@ai-sdk/openai"
  "@ai-sdk/anthropic"
  "@ai-sdk/google"
  "workers-ai-provider"
  "zod"
)

for package in "${packages[@]}"; do
  echo "📦 $package"
  echo "   Installed: $(npm list $package --depth=0 2>/dev/null | grep $package | awk '{print $2}')"
  echo "   Latest:    $(npm view $package version)"
  echo ""
done
```

---

## Known Issues to Document (Top 10-12)

Based on research, these are the highest-priority errors to cover:

1. **AI_APICallError** - API call failed (auth, network, rate limits)
2. **AI_NoObjectGeneratedError** - Model didn't generate valid object
3. **Worker Startup Limit** - Cloudflare Workers >270ms initialization
4. **streamText Fails Silently** - Errors swallowed by stream
5. **AI_LoadAPIKeyError** - Missing/invalid API key
6. **AI_InvalidArgumentError** - Invalid function parameters
7. **AI_NoContentGeneratedError** - Model generated no content
8. **AI_TypeValidationError** - Zod schema validation failed
9. **AI_RetryError** - All retry attempts failed
10. **Rate Limiting** - Exceeded provider rate limits
11. **TypeScript Performance with Zod** - Slow type checking with complex schemas
12. **Unclosed Streams** - Stream not properly closed

For all other errors, link to: https://ai-sdk.dev/docs/reference/ai-sdk-errors

---

## Token Savings Calculation

**Manual Setup (No Skill):**
- Research AI SDK v5: ~3000 tokens
- Find breaking changes: ~2000 tokens
- Setup providers: ~2000 tokens
- Implement generateText/streamText: ~2000 tokens
- Implement generateObject: ~2000 tokens
- Tool calling research: ~2000 tokens
- Error handling research: ~2000 tokens
- Fix common errors: ~3000 tokens
- Total: ~18,000 tokens

**With Skill:**
- Skill discovery: ~500 tokens
- Read relevant sections: ~3000 tokens
- Copy templates: ~2000 tokens
- Customize: ~2000 tokens
- Total: ~7,500 tokens

**Savings: ~58% (10,500 tokens saved)**

---

## Success Criteria

A skill is complete when:

- [x] SKILL.md has valid YAML frontmatter
- [x] All 4 core functions covered (generateText, streamText, generateObject, streamObject)
- [x] Top 4 providers documented (OpenAI, Anthropic, Google, Cloudflare)
- [x] 13 working templates
- [x] Top 10-12 errors documented
- [x] v5 breaking changes documented
- [x] Cloudflare Workers integration included
- [x] Next.js Server Actions example included
- [x] Links to advanced topics (not replicated)
- [x] README.md has comprehensive keywords
- [x] Production-tested examples
- [x] Token savings >= 50%

---

## Notes for Implementation

**What to Emphasize:**
- v5 stability and breaking changes from v4
- Multi-provider flexibility (OpenAI, Anthropic, Google as top 3)
- Cloudflare Workers as one option (not the focus)
- Vercel/Next.js patterns (Server Actions)
- Practical examples over theory
- Links to docs for deep-dives

**What to De-Emphasize:**
- workers-ai-provider (one option among many)
- Advanced topics (embeddings, image gen) - link only
- Full error catalog (top 10-12 only, link to rest)
- CI/CD (mention Vercel docs, don't replicate)
- v6 beta (stick to v5 stable)

**Critical Success Factors:**
- Templates must work copy-paste
- Error solutions must be actionable
- Provider setup must be clear
- Migration guide must prevent common mistakes
- Links to official docs must be accurate

---

**Ready for execution with fresh context!**
