---
name: thesys-generative-ui
description: |
  Integrate TheSys C1 Generative UI API to stream interactive React components (forms, charts, tables) from LLM responses. Supports Vite+React, Next.js, and Cloudflare Workers with OpenAI, Anthropic Claude, and Workers AI.

  Use when building conversational UIs, AI assistants with rich interactions, or troubleshooting empty responses, theme application failures, streaming issues, or tool calling errors.
license: MIT
metadata:
  version: "1.0.1"
  package: "@thesysai/genui-sdk"
  package_version: "0.7.4"
  last_verified: "2025-11-28"
  production_tested: true
  token_savings: "~65-70%"
  errors_prevented: 12
---

# TheSys Generative UI Integration

Complete skill for building AI-powered interfaces with TheSys C1 Generative UI API. Convert LLM responses into streaming, interactive React components.

---

## TheSys C1 Overview

TheSys C1 API transforms LLM responses into streaming, interactive React components (forms, charts, tables) instead of plain text.

**When to use**: Chat UIs, data visualizations, AI assistants, dynamic forms, search interfaces with rich results.

**Error Prevention** (12 documented issues):

- ❌ Empty agent responses from incorrect streaming setup
- ❌ Models ignoring system prompts due to message array issues
- ❌ Version compatibility errors between SDK and API
- ❌ Themes not applying without ThemeProvider
- ❌ Streaming failures from improper response transformation
- ❌ Tool calling bugs from invalid Zod schemas
- ❌ Thread state loss from missing persistence
- ❌ CSS conflicts from import order issues
- ❌ TypeScript errors from outdated type definitions
- ❌ CORS failures from missing headers
- ❌ Rate limit crashes without retry logic
- ❌ Authentication token errors from environment issues

---

## Quick Start by Framework

### Vite + React Setup

**Most flexible setup for custom backends (your preferred stack).**

#### 1. Install Dependencies

```bash
npm install @thesysai/genui-sdk @crayonai/react-ui @crayonai/react-core @crayonai/stream
npm install openai zod
```

#### 2. Chat Component (`src/App.tsx`)

```typescript
import "@crayonai/react-ui/styles/index.css";
import { ThemeProvider, C1Component } from "@thesysai/genui-sdk";

export default function App() {
  const [response, setResponse] = useState("");

  async function sendMessage(query: string) {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt: query }),
    });
    setResponse((await res.json()).response);
  }

  return (
    <ThemeProvider>
      <C1Component c1Response={response} onAction={({ llmFriendlyMessage }) => sendMessage(llmFriendlyMessage)} />
    </ThemeProvider>
  );
}
```

#### 3. Backend API (Express)

```typescript
const client = new OpenAI({ baseURL: "https://api.thesys.dev/v1/embed", apiKey: process.env.THESYS_API_KEY });

app.post("/api/chat", async (req, res) => {
  const stream = await client.chat.completions.create({
    model: "c1/openai/gpt-5/v-20250930",
    messages: [{ role: "system", content: "You are a helpful assistant." }, { role: "user", content: req.body.prompt }],
    stream: true,
  });
  const c1Stream = transformStream(stream, (chunk) => chunk.choices[0]?.delta?.content || "");
  res.json({ response: await streamToString(c1Stream) });
});
```

---

### Next.js

```bash
npm install @thesysai/genui-sdk @crayonai/react-ui @crayonai/react-core openai
```

**Page** (`app/page.tsx`):
```typescript
"use client";
import { C1Chat } from "@thesysai/genui-sdk";
import "@crayonai/react-ui/styles/index.css";

export default function Home() {
  return <C1Chat apiUrl="/api/chat" />;
}
```

**API Route** (`app/api/chat/route.ts`):
```typescript
const client = new OpenAI({ baseURL: "https://api.thesys.dev/v1/embed", apiKey: process.env.THESYS_API_KEY });

export async function POST(req: NextRequest) {
  const stream = await client.chat.completions.create({
    model: "c1/openai/gpt-5/v-20250930",
    messages: [{ role: "system", content: "You are a helpful AI assistant." }, { role: "user", content: (await req.json()).prompt }],
    stream: true,
  });
  return new NextResponse(transformStream(stream, (chunk) => chunk.choices[0]?.delta?.content || ""), {
    headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache, no-transform" },
  });
}
```

---

### Cloudflare Workers + Static Assets Setup

**Your stack: Workers backend with Vite+React frontend.**

**Worker** (`backend/src/index.ts` with Hono):
```typescript
app.post("/api/chat", async (c) => {
  const response = await fetch("https://api.thesys.dev/v1/embed/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${c.env.THESYS_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "c1/openai/gpt-5/v-20250930",
      messages: [{ role: "system", content: "You are a helpful assistant." }, { role: "user", content: (await c.req.json()).prompt }],
    }),
  });
  return c.json(await response.json());
});
```

**Config** (`wrangler.jsonc`):
```jsonc
{
  "main": "backend/src/index.ts",
  "assets": { "directory": "dist", "binding": "ASSETS" }
}
```
Secret: `wrangler secret put THESYS_API_KEY`

---

## Core Components


**`<C1Chat>`** - Pre-built chat UI with message history, streaming, thread management.

**Props**: `apiUrl` (required), `agentName`, `logoUrl`, `theme`, `threadManager`, `threadListManager`, `customizeC1`

**`<C1Component>`** - Low-level renderer for custom state management.

**Props**: `c1Response` (required), `isStreaming`, `updateMessage`, `onAction`

**CRITICAL**: Must wrap with `<ThemeProvider>` for theming to work.

**`<ThemeProvider>`** - Theming wrapper.

**Presets**: `themePresets.default`, `themePresets.candy`

**Custom**: Pass theme object with colors, typography, spacing.

## Models

**C1 Stable Models** (production):
- `c1/openai/gpt-5/v-20250930` - GPT-5
- `c1/anthropic/claude-sonnet-4/v-20250930` - Claude Sonnet 4

**C1 Experimental** (testing):
- `c1-exp/openai/gpt-4.1/v-20250617` - GPT-4.1
- `c1-exp/anthropic/claude-3.5-haiku/v-20250709` - Claude 3.5 Haiku

Use with OpenAI-compatible client: `baseURL: "https://api.thesys.dev/v1/embed"`

---


## Tool Calling with Zod Schemas


**Tool Schema** (Zod):
```typescript
const toolSchema = z.object({ query: z.string().describe("Search query") });
const tool = { type: "function" as const, function: { name: "web_search", description: "Search web", parameters: zodToJsonSchema(toolSchema) } };
```

**Pass to LLM**: Add tools array to `client.chat.completions.create({ tools: [tool], ... })`

**Handle Callbacks**: Implement tool execution logic when `tool_calls` appear in response.

## Advanced Features


**Thread Management**: Use `useThreadListManager` and `useThreadManager` hooks for multi-conversation support.

**Thinking States**: Use `c1Response.writeThinkItem()` to show progress indicators during processing.

**Custom Components**: Pass `customizeC1` prop to override default UI elements.


**Database Persistence**: Store threads/messages in D1, PostgreSQL, or MongoDB.

**Caching**: Use KV for session data and response caching.

**Error Boundaries**: Wrap C1 components in React error boundaries.

**Rate Limiting**: Implement exponential backoff for API calls.

**Security**: Never expose API keys client-side; use server-side proxies.

## Common Errors & Solutions

### 1. Empty Agent Responses

**Problem**: AI returns empty responses, UI shows nothing.

**Cause**: Incorrect streaming transformation or response format.

**Solution**:
```typescript
// ✅ Use transformStream helper
import { transformStream } from "@crayonai/stream";

const c1Stream = transformStream(llmStream, (chunk) => {
  return chunk.choices[0]?.delta?.content || ""; // Fallback to empty string
}) as ReadableStream<string>;
```

---

### 2. Model Not Following System Prompt

**Problem**: AI ignores instructions in system prompt.

**Cause**: System prompt is not first in messages array or improperly formatted.

**Solution**:
```typescript
// ✅ System prompt MUST be first
const messages = [
  { role: "system", content: "You are a helpful assistant." }, // FIRST!
  ...conversationHistory,
  { role: "user", content: userPrompt },
];

// ❌ Wrong - system prompt after user messages
const messages = [
  { role: "user", content: "Hello" },
  { role: "system", content: "..." }, // TOO LATE
];
```

---

### 3. Version Compatibility Errors

**Problem**: `TypeError: Cannot read property 'X' of undefined` or component rendering errors.

**Cause**: Mismatched SDK versions.

**Solution**: Check compatibility matrix:

| C1 Version | @thesysai/genui-sdk | @crayonai/react-ui | @crayonai/react-core |
|------------|---------------------|-------------------|---------------------|
| v-20250930 | ~0.6.40             | ~0.8.42           | ~0.7.6              |

```bash
# Update to compatible versions
npm install @thesysai/genui-sdk@0.6.40 @crayonai/react-ui@0.8.42 @crayonai/react-core@0.7.6
```

---

### 4. Theme Not Applying

**Problem**: UI components don't match custom theme.

**Cause**: Missing `ThemeProvider` wrapper.

**Solution**:
```typescript
// ❌ Wrong
<C1Component c1Response={response} />

// ✅ Correct
<ThemeProvider theme={customTheme}>
  <C1Component c1Response={response} />
</ThemeProvider>
```

---

### 5. Streaming Not Working

**Problem**: UI doesn't update in real-time, waits for full response.

**Cause**: Not using streaming or improper response headers.

**Solution**:
```typescript
// 1. Enable streaming in API call
const stream = await client.chat.completions.create({
  model: "c1/openai/gpt-5/v-20250930",
  messages: [...],
  stream: true, // ✅ IMPORTANT
});

// 2. Set proper response headers
return new NextResponse(responseStream, {
  headers: {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
  },
});

// 3. Pass isStreaming prop
<C1Component
  c1Response={response}
  isStreaming={true} // ✅ Shows loading indicator
/>
```

---

### 6. Tool Calling Failures

**Problem**: Tools not executing or validation errors.

**Cause**: Invalid Zod schema or incorrect tool format.

**Solution**:
```typescript
import { z } from "zod";
import zodToJsonSchema from "zod-to-json-schema";

// ✅ Proper Zod schema with descriptions
const toolSchema = z.object({
  query: z.string().describe("Search query"), // DESCRIBE all fields
  limit: z.number().int().min(1).max(100).describe("Max results"),
});

// ✅ Convert to OpenAI format
const tool = {
  type: "function" as const,
  function: {
    name: "search_web",
    description: "Search the web for information", // Clear description
    parameters: zodToJsonSchema(toolSchema), // Convert schema
  },
};

// ✅ Validate incoming tool calls
const args = toolSchema.parse(JSON.parse(toolCall.function.arguments));
```

---

### 7. Thread State Not Persisting

**Problem**: Threads disappear on page refresh.

**Cause**: No backend persistence, using in-memory storage.

**Solution**: Implement database storage (see Production Patterns section).

---

### 8. CSS Conflicts

**Problem**: Styles from C1 components clash with app styles.

**Cause**: CSS import order or global styles overriding.

**Solution**:
```typescript
// ✅ Correct import order
import "@crayonai/react-ui/styles/index.css"; // C1 styles FIRST
import "./your-app.css"; // Your styles SECOND

// In your CSS, use specificity if needed
.your-custom-class .c1-message {
  /* Override specific styles */
}
```

---

### 9. TypeScript Type Errors

**Problem**: TypeScript complains about missing types or incompatible types.

**Cause**: Outdated package versions or missing type definitions.

**Solution**:
```bash
# Update packages
npm install @thesysai/genui-sdk@latest @crayonai/react-ui@latest @crayonai/react-core@latest

# If still errors, check tsconfig.json
{
  "compilerOptions": {
    "moduleResolution": "bundler", // or "node16"
    "skipLibCheck": true // Skip type checking for node_modules
  }
}
```

---

### 10. CORS Errors with API

**Problem**: `Access-Control-Allow-Origin` errors when calling backend.

**Cause**: Missing CORS headers in API responses.

**Solution**:
```typescript
// Next.js API Route
export async function POST(req: NextRequest) {
  const response = new NextResponse(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Access-Control-Allow-Origin": "*", // Or specific domain
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });

  return response;
}

// Express
app.use(cors({
  origin: "http://localhost:5173", // Your frontend URL
  methods: ["POST", "OPTIONS"],
}));
```

---

### 11. Rate Limiting Issues

**Problem**: API calls fail with 429 errors, no retry mechanism.

**Cause**: No backoff logic for rate limits.

**Solution**:
```typescript
async function callApiWithRetry(apiCall, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await apiCall();
    } catch (error) {
      if (error.status === 429 && i < maxRetries - 1) {
        const waitTime = Math.pow(2, i) * 1000; // Exponential backoff
        await new Promise((resolve) => setTimeout(resolve, waitTime));
        continue;
      }
      throw error;
    }
  }
}

// Usage
const response = await callApiWithRetry(() =>
  client.chat.completions.create({...})
);
```

---

### 12. Authentication Token Errors

**Problem**: `401 Unauthorized` even with API key set.

**Cause**: Environment variable not loaded or incorrect variable name.

**Solution**:
```bash
# .env file (Next.js)
THESYS_API_KEY=your_api_key_here

# Verify it's loaded
# In your code:
if (!process.env.THESYS_API_KEY) {
  throw new Error("THESYS_API_KEY is not set");
}

# For Vite, use VITE_ prefix for client-side
VITE_THESYS_API_KEY=your_key # Client-side
THESYS_API_KEY=your_key      # Server-side

# Access in Vite
const apiKey = import.meta.env.VITE_THESYS_API_KEY;

# For Cloudflare Workers, use wrangler secrets
npx wrangler secret put THESYS_API_KEY
```

---

## Templates & Examples


**Vite+React**: basic-chat.tsx, custom-component.tsx, tool-calling.tsx, theme-dark-mode.tsx, package.json

**Next.js**: app/page.tsx, app/api/chat/route.ts, tool-calling-route.ts, package.json

**Cloudflare Workers**: worker-backend.ts, frontend-setup.tsx, wrangler.jsonc

**Shared**: theme-config.ts, tool-schemas.ts, streaming-utils.ts

**References**: component-api.md, ai-provider-setup.md, tool-calling-guide.md, theme-customization.md, common-errors.md

**Docs**: https://docs.thesys.dev | Playground: https://console.thesys.dev/playground | Context7: `/websites/thesys_dev`

**Official Standards Compliant**: ✅ Yes
