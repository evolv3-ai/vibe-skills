# AI SDK UI - Skill Specification

**Created**: 2025-10-21
**Status**: Planning Phase
**Priority**: High (Batch 2 - Do After ai-sdk-core)
**Estimated Dev Time**: 5-7 hours
**Token Savings**: ~50-55%
**Errors Prevented**: 10-12 documented issues

---

## Overview

**Purpose**: Frontend React hooks for building chat interfaces, completions, and streaming UI with Vercel AI SDK v5.

**Target Frameworks**:
- React (primary)
- Next.js App Router (Vercel focus)
- Next.js Pages Router
- Other React frameworks (Remix, Gatsby, Vite)

**Core Hooks**:
1. `useChat` - Chat interfaces with streaming
2. `useCompletion` - Text completions
3. `useObject` - Streaming structured data

**Version**: AI SDK v5 (stable) - Focus on v5.0.76+

---

## Skill Structure

```
skills/ai-sdk-ui/
├── SKILL.md                           # ~700-900 lines
├── README.md                          # Auto-trigger keywords
├── templates/
│   ├── use-chat-basic.tsx             # Basic chat with useChat
│   ├── use-chat-tools.tsx             # Chat with tool calling UI
│   ├── use-chat-attachments.tsx       # File attachments support
│   ├── use-completion-basic.tsx       # Basic text completion
│   ├── use-object-streaming.tsx       # Streaming structured data
│   ├── nextjs-chat-app-router.tsx     # Next.js App Router full example
│   ├── nextjs-chat-pages-router.tsx   # Next.js Pages Router full example
│   ├── nextjs-api-route.ts            # API route for useChat
│   ├── message-persistence.tsx        # Save/load chat history
│   ├── custom-message-renderer.tsx    # Custom message components
│   └── package.json                   # Dependencies template
├── references/
│   ├── use-chat-migration.md          # v4→v5 useChat changes
│   ├── streaming-patterns.md          # UI streaming best practices
│   ├── top-ui-errors.md               # 10-12 most common UI errors
│   ├── nextjs-integration.md          # Next.js setup patterns
│   └── links-to-official-docs.md      # Advanced topics
└── scripts/
    └── check-versions.sh              # Package version checker
```

---

## SKILL.md Outline

### 1. Frontmatter (YAML)
```yaml
---
name: AI SDK UI
description: |
  Frontend React hooks for AI-powered chat interfaces, completions, and streaming UIs with Vercel AI SDK v5.
  Includes useChat, useCompletion, and useObject hooks for building interactive AI applications.

  Use when: building React chat interfaces, implementing AI completions in UI, streaming AI responses to frontend,
  handling chat message state, building Next.js AI apps, managing file attachments with AI, or encountering
  errors like "useChat failed to parse stream", "useChat no response", unclosed streams, or streaming issues.

  Keywords: ai sdk ui, useChat hook, useCompletion hook, useObject hook, react ai chat, ai chat interface,
  streaming ai ui, nextjs ai chat, vercel ai ui, react streaming, ai sdk react, chat message state,
  ai file attachments, message persistence, useChat error, streaming failed ui, parse stream error,
  useChat no response, react ai hooks, nextjs app router ai, nextjs pages router ai
license: MIT
---
```

### 2. Quick Start (5-10 minutes)

**Installation:**
```bash
npm install ai @ai-sdk/openai
```

**Basic Chat Component:**
```tsx
'use client';
import { useChat } from 'ai/react';

export default function Chat() {
  const { messages, input, handleInputChange, handleSubmit } = useChat();

  return (
    <div>
      {messages.map(m => (
        <div key={m.id}>{m.role}: {m.content}</div>
      ))}
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} />
      </form>
    </div>
  );
}
```

**API Route (Next.js App Router):**
```typescript
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
  });

  return result.toDataStreamResponse();
}
```

### 3. useChat Hook Deep Dive

#### Basic Usage
```tsx
const { messages, input, handleInputChange, handleSubmit } = useChat();
```

#### Full API Reference
```typescript
const {
  // Messages
  messages,           // Chat messages array
  setMessages,        // Update messages

  // Input (NO LONGER MANAGED - v5 change)
  input,              // Deprecated in v5
  handleInputChange,  // Deprecated in v5
  handleSubmit,       // Deprecated in v5

  // v5 Way (Manual Input Management)
  sendMessage,        // Send a message

  // State
  isLoading,          // Is AI responding?
  error,              // Error if any

  // Actions
  reload,             // Reload last response
  stop,               // Stop current generation
  append,             // Deprecated → use sendMessage

  // Data
  data,               // Custom data from stream
} = useChat({
  api: '/api/chat',
  id: 'chat-1',
  initialMessages: [],

  // Callbacks
  onResponse: (response) => {},  // REMOVED in v5
  onFinish: (message) => {},
  onError: (error) => {},
});
```

#### v4 → v5 Breaking Changes
**OLD (v4):**
```tsx
const { input, handleInputChange, handleSubmit, append } = useChat();

<form onSubmit={handleSubmit}>
  <input value={input} onChange={handleInputChange} />
</form>
```

**NEW (v5):**
```tsx
const { messages, sendMessage } = useChat();
const [input, setInput] = useState('');

<form onSubmit={(e) => {
  e.preventDefault();
  sendMessage({ content: input });
  setInput('');
}}>
  <input value={input} onChange={(e) => setInput(e.target.value)} />
</form>
```

**Key Changes:**
- Input state NO LONGER managed by useChat
- `append()` → `sendMessage()`
- `handleSubmit` removed (use sendMessage)
- `onResponse` callback removed
- `initialMessages` → `messages` prop
- `maxSteps` removed (handle server-side)

#### Tool Calling in UI
```tsx
const { messages } = useChat({
  api: '/api/chat',
});

// Messages include tool calls
messages.map(message => {
  if (message.toolInvocations) {
    return message.toolInvocations.map(tool => (
      <div key={tool.toolCallId}>
        Tool: {tool.toolName}
        Args: {JSON.stringify(tool.args)}
        Result: {JSON.stringify(tool.result)}
      </div>
    ));
  }
  return <div>{message.content}</div>;
});
```

#### File Attachments
```tsx
const { messages, sendMessage } = useChat();
const [files, setFiles] = useState<FileList | null>(null);

const handleSubmit = async (e: FormEvent) => {
  e.preventDefault();

  sendMessage({
    content: input,
    experimental_attachments: files ? Array.from(files).map(file => ({
      name: file.name,
      contentType: file.type,
      url: URL.createObjectURL(file),
    })) : undefined,
  });

  setInput('');
  setFiles(null);
};
```

#### Message Persistence
```tsx
const { messages, setMessages, sendMessage } = useChat({
  id: 'chat-1',
  initialMessages: loadMessagesFromStorage('chat-1'),
});

// Save on change
useEffect(() => {
  saveMessagesToStorage('chat-1', messages);
}, [messages]);
```

### 4. useCompletion Hook Deep Dive

#### Basic Usage
```tsx
'use client';
import { useCompletion } from 'ai/react';

export default function Completion() {
  const { completion, input, handleInputChange, handleSubmit } = useCompletion();

  return (
    <div>
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} />
      </form>
      <div>{completion}</div>
    </div>
  );
}
```

#### Full API Reference
```typescript
const {
  completion,         // Current completion text
  complete,           // Trigger completion
  setCompletion,      // Update completion
  input,              // Input value (deprecated in v5)
  handleInputChange,  // Handle input (deprecated in v5)
  handleSubmit,       // Submit (deprecated in v5)
  isLoading,          // Is generating?
  error,              // Error if any
  stop,               // Stop generation
} = useCompletion({
  api: '/api/completion',
  id: 'completion-1',

  onFinish: (prompt, completion) => {},
  onError: (error) => {},
});
```

#### API Route
```typescript
// app/api/completion/route.ts
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: Request) {
  const { prompt } = await req.json();

  const result = streamText({
    model: openai('gpt-3.5-turbo'),
    prompt,
  });

  return result.toDataStreamResponse();
}
```

### 5. useObject Hook Deep Dive

#### Basic Usage
```tsx
'use client';
import { useObject } from 'ai/react';
import { z } from 'zod';

const schema = z.object({
  recipe: z.object({
    name: z.string(),
    ingredients: z.array(z.string()),
  }),
});

export default function Recipe() {
  const { object, submit, isLoading } = useObject({
    api: '/api/recipe',
    schema,
  });

  return (
    <div>
      <button onClick={() => submit('pasta')}>Generate</button>
      {isLoading && <div>Loading...</div>}
      {object && (
        <div>
          <h2>{object.recipe?.name}</h2>
          <ul>
            {object.recipe?.ingredients?.map((i, idx) => (
              <li key={idx}>{i}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
```

#### API Route
```typescript
// app/api/recipe/route.ts
import { streamObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

export async function POST(req: Request) {
  const { prompt } = await req.json();

  const result = streamObject({
    model: openai('gpt-4'),
    schema: z.object({
      recipe: z.object({
        name: z.string(),
        ingredients: z.array(z.string()),
        instructions: z.array(z.string()),
      }),
    }),
    prompt: `Generate a recipe for ${prompt}`,
  });

  return result.toTextStreamResponse();
}
```

### 6. Next.js Integration

#### App Router Setup

**Directory Structure:**
```
app/
├── api/
│   └── chat/
│       └── route.ts      # Chat API endpoint
├── chat/
│   └── page.tsx          # Chat page
└── layout.tsx
```

**Complete Example:**
```tsx
// app/chat/page.tsx
'use client';
import { useChat } from 'ai/react';
import { useState } from 'react';

export default function ChatPage() {
  const { messages, sendMessage, isLoading } = useChat({
    api: '/api/chat',
  });
  const [input, setInput] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    sendMessage({ content: input });
    setInput('');
  };

  return (
    <div className="flex flex-col h-screen">
      <div className="flex-1 overflow-y-auto p-4">
        {messages.map(m => (
          <div key={m.id} className={m.role === 'user' ? 'text-right' : 'text-left'}>
            <div className="inline-block p-2 rounded bg-gray-100">
              {m.content}
            </div>
          </div>
        ))}
      </div>
      <form onSubmit={handleSubmit} className="p-4 border-t">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          className="w-full p-2 border rounded"
          placeholder="Type a message..."
          disabled={isLoading}
        />
      </form>
    </div>
  );
}
```

```tsx
// app/api/chat/route.ts
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
    system: 'You are a helpful assistant.',
  });

  return result.toDataStreamResponse();
}
```

#### Pages Router Setup

**Directory Structure:**
```
pages/
├── api/
│   └── chat.ts           # Chat API endpoint
└── chat.tsx              # Chat page
```

**Complete Example:**
```tsx
// pages/chat.tsx
import { useChat } from 'ai/react';
import { useState, FormEvent } from 'react';

export default function ChatPage() {
  const { messages, sendMessage, isLoading } = useChat({
    api: '/api/chat',
  });
  const [input, setInput] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    sendMessage({ content: input });
    setInput('');
  };

  return (
    <div>
      {messages.map(m => (
        <div key={m.id}>{m.role}: {m.content}</div>
      ))}
      <form onSubmit={handleSubmit}>
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={isLoading}
        />
      </form>
    </div>
  );
}
```

```typescript
// pages/api/chat.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { messages } = req.body;

  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
  });

  return result.pipeDataStreamToResponse(res);
}
```

### 7. Critical v4→v5 Migration (UI-Specific)

**useChat Breaking Changes:**

1. **Managed Input State Removed**
   - **v4**: `input`, `handleInputChange`, `handleSubmit` managed by hook
   - **v5**: Manage input manually with `useState`

2. **append → sendMessage**
   - **v4**: `append({ role: 'user', content: 'hi' })`
   - **v5**: `sendMessage({ content: 'hi' })`

3. **initialMessages → messages**
   - **v4**: `initialMessages` prop
   - **v5**: `messages` prop for controlled mode

4. **onResponse Removed**
   - **v4**: `onResponse` callback existed
   - **v5**: Removed, use `onFinish` instead

5. **maxSteps Removed**
   - **v4**: Could set `maxSteps` in useChat
   - **v5**: Handle on server-side only

6. **Message Structure Changed**
   - **v4**: Simple content string
   - **v5**: Parts array (text, tool-call, tool-result parts)

**Migration Checklist:**
- [ ] Remove `input`, `handleInputChange`, `handleSubmit` from useChat
- [ ] Add manual input state with `useState`
- [ ] Replace `append()` with `sendMessage()`
- [ ] Replace `onResponse` with `onFinish`
- [ ] Move `maxSteps` to server-side
- [ ] Update message rendering for parts structure
- [ ] Test streaming behavior

### 8. Top 10-12 UI Errors & Solutions

**Priority Errors to Document:**

1. **useChat Failed to Parse Stream**
   - Cause: Invalid JSON in stream response
   - Solution: Check API route returns proper stream format
   - Code example

2. **useChat No Response**
   - Cause: API route not returning stream correctly
   - Solution: Use `toDataStreamResponse()` or `pipeDataStreamToResponse()`
   - Code example

3. **Unclosed Streams**
   - Cause: Stream not properly closed in API
   - Solution: Ensure stream completes properly
   - Code example
   - GitHub issue link

4. **Streaming Not Working When Deployed**
   - Cause: Deployment platform buffering responses
   - Solution: Configure platform for streaming (Vercel auto-detects)
   - Link to Vercel docs

5. **Streaming Not Working When Proxied**
   - Cause: Proxy buffering responses
   - Solution: Configure proxy to disable buffering
   - Nginx/Cloudflare examples

6. **Strange Stream Output (0:... characters)**
   - Cause: Seeing raw stream protocol
   - Solution: Ensure using correct hook/stream format
   - Code example

7. **Stale Body Values with useChat**
   - Cause: Body captured at first render only
   - Solution: Use callbacks or controlled messages
   - Code example

8. **Custom Headers Not Working with useChat**
   - Cause: Incorrect headers configuration
   - Solution: Use `headers` or `body` options correctly
   - Code example

9. **React Maximum Update Depth**
   - Cause: Infinite loop in useEffect with messages
   - Solution: Proper dependency array
   - Code example

10. **Repeated Assistant Messages**
    - Cause: Duplicate message handling
    - Solution: Check message deduplication
    - Code example

11. **onFinish Not Called When Stream Aborted**
    - Cause: Stream abort doesn't trigger callback
    - Solution: Handle abort separately
    - Code example

12. **Type Error with Message Parts**
    - Cause: v5 message structure change
    - Solution: Update TypeScript types
    - Code example

**For Other Errors**: Link to https://ai-sdk.dev/docs/troubleshooting

### 9. Streaming Patterns & Best Practices

**Performance:**
- Always use streaming for better UX
- Show loading states
- Handle partial messages
- Debounce input for completions

**Error Handling:**
- Display errors to users
- Provide retry functionality
- Handle network failures gracefully
- Log errors for debugging

**UX Patterns:**
- Show typing indicators
- Scroll to latest message
- Disable input while loading
- Handle empty states
- Provide stop button for long responses

**Message Rendering:**
- Support markdown rendering
- Handle code blocks
- Display tool calls visually
- Show timestamps
- Group messages by role

**State Management:**
- Persist chat history
- Clear chat functionality
- Export/import conversations
- Handle multiple chats (routing)

### 10. When to Use This Skill

**Use ai-sdk-ui when:**
- Building React chat interfaces
- Implementing AI completions in UI
- Streaming AI responses to frontend
- Building Next.js AI applications
- Handling chat message state
- Displaying tool calls in UI
- Managing file attachments with AI
- Migrating from v4 to v5 (UI hooks)
- Encountering useChat/useCompletion errors

**Don't use when:**
- Need backend AI functionality (use ai-sdk-core instead)
- Building non-React frontends (check official docs for Svelte/Vue)
- Need advanced topics like Generative UI (link to docs)
- Building native apps (different SDK)

**Related Skills:**
- Use **ai-sdk-core** for backend/server-side AI
- Compose both for full-stack AI apps

### 11. Dependencies & Versions

**Required Packages:**
```json
{
  "dependencies": {
    "ai": "^5.0.76",
    "@ai-sdk/openai": "^2.0.53",
    "react": "^18.2.0 || ^19.0.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.3.3"
  }
}
```

**Next.js:**
```json
{
  "dependencies": {
    "next": "^14.0.0 || ^15.0.0",
    "react": "^18.2.0 || ^19.0.0",
    "react-dom": "^18.2.0 || ^19.0.0"
  }
}
```

**Version Notes:**
- AI SDK v5.0.76+ (stable)
- React 18+ or React 19 RC
- Next.js 14+ (App Router) or 13+ (Pages Router)

### 12. Links to Official Documentation

**Core UI Docs:**
- AI SDK UI Overview: https://ai-sdk.dev/docs/ai-sdk-ui/overview
- useChat: https://ai-sdk.dev/docs/ai-sdk-ui/chatbot
- useCompletion: https://ai-sdk.dev/docs/ai-sdk-ui/completion
- useObject: https://ai-sdk.dev/docs/ai-sdk-ui/object-generation

**Advanced Topics (Link Only):**
- Generative UI (RSC): https://ai-sdk.dev/docs/ai-sdk-rsc/overview
- Stream Protocols: https://ai-sdk.dev/docs/ai-sdk-ui/stream-protocols
- Message Metadata: https://ai-sdk.dev/docs/ai-sdk-ui/message-metadata
- Custom Transports: https://ai-sdk.dev/docs/ai-sdk-ui/transports

**Next.js Integration:**
- Next.js App Router: https://ai-sdk.dev/docs/getting-started/nextjs-app-router
- Next.js Pages Router: https://ai-sdk.dev/docs/getting-started/nextjs-pages-router

**Migration & Troubleshooting:**
- v4→v5 Migration: https://ai-sdk.dev/docs/migration-guides/migration-guide-5-0
- Troubleshooting: https://ai-sdk.dev/docs/troubleshooting
- Common Issues: https://ai-sdk.dev/docs/troubleshooting/common-issues

**Vercel Deployment:**
- Vercel Functions: https://vercel.com/docs/functions
- Streaming on Vercel: https://vercel.com/docs/functions/streaming
- AI SDK Blog: https://vercel.com/blog/ai-sdk-5

---

## README.md Keywords

### Primary Keywords (High Weight)
- `ai sdk ui`, `useChat`, `useCompletion`, `useObject`
- `react ai chat`, `ai chat interface`, `chat ui react`
- `ai sdk react`, `vercel ai ui`, `ai react hooks`
- `streaming ai ui`, `react streaming chat`
- `nextjs ai chat`, `nextjs ai`, `next.js chat`
- `ai chat component`, `react ai components`

### Secondary Keywords (Medium Weight)
- `nextjs app router ai`, `nextjs pages router ai`
- `chat message state`, `message persistence ai`
- `ai file attachments`, `file upload ai chat`
- `streaming chat react`, `real-time ai chat`
- `tool calling ui`, `ai tools react`
- `ai completion react`, `text completion ui`
- `structured data streaming`, `useObject streaming`

### Error Keywords (Trigger on Errors)
- `useChat failed to parse stream`, `parse stream error`
- `useChat no response`, `chat hook no response`
- `unclosed streams ai`, `stream not closing`
- `streaming not working deployed`, `vercel streaming issue`
- `streaming not working proxied`, `proxy buffering`
- `strange stream output`, `0: characters stream`
- `stale body values useChat`, `body not updating`
- `custom headers not working useChat`
- `react maximum update depth`, `infinite loop useChat`
- `repeated assistant messages`, `duplicate messages`
- `onFinish not called`, `stream aborted`
- `v5 migration useChat`, `useChat breaking changes`
- `input handleInputChange removed`, `sendMessage v5`

### Framework Keywords
- `nextjs ai integration`, `next.js ai sdk`
- `react chat app`, `react ai application`
- `vite react ai`, `remix ai chat`
- `vercel ai deployment`

---

## Templates to Create

### 1. use-chat-basic.tsx
Basic chat implementation with manual input management (v5 style).

### 2. use-chat-tools.tsx
Chat with tool calling and UI rendering of tool results.

### 3. use-chat-attachments.tsx
File attachments support with experimental_attachments.

### 4. use-completion-basic.tsx
Basic text completion with streaming.

### 5. use-object-streaming.tsx
Streaming structured data with Zod schema.

### 6. nextjs-chat-app-router.tsx
Complete Next.js App Router chat example.

### 7. nextjs-chat-pages-router.tsx
Complete Next.js Pages Router chat example.

### 8. nextjs-api-route.ts
API route handler for chat (both App Router and Pages Router).

### 9. message-persistence.tsx
Save/load chat history to localStorage.

### 10. custom-message-renderer.tsx
Custom message components with markdown, code highlighting, etc.

### 11. package.json
Dependencies template for AI SDK UI projects.

---

## References to Create

### 1. use-chat-migration.md
- Complete v4→v5 useChat migration guide
- Before/after code examples
- Breaking changes checklist
- Common migration errors

### 2. streaming-patterns.md
- UI streaming best practices
- Performance optimization
- Error handling
- UX patterns
- Message rendering

### 3. top-ui-errors.md
- Top 10-12 errors with solutions
- Each error includes:
  - Error description
  - Cause
  - Solution
  - Code example
  - Links to GitHub issues/docs

### 4. nextjs-integration.md
- App Router setup
- Pages Router setup
- API routes
- Deployment considerations
- Environment variables
- Link to Vercel docs for CI/CD

### 5. links-to-official-docs.md
- Organized list of official docs
- When to use each resource
- Advanced topics links

---

## Scripts to Create

### check-versions.sh
```bash
#!/bin/bash
echo "Checking AI SDK UI package versions..."
echo ""

packages=(
  "ai"
  "@ai-sdk/openai"
  "react"
  "next"
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

## Token Savings Calculation

**Manual Setup (No Skill):**
- Research AI SDK UI: ~2500 tokens
- Find v5 useChat changes: ~2000 tokens
- Implement useChat: ~2000 tokens
- Setup Next.js routes: ~2000 tokens
- Message rendering: ~1500 tokens
- Tool calling UI: ~1500 tokens
- Error handling: ~1500 tokens
- Fix common errors: ~2500 tokens
- Total: ~15,500 tokens

**With Skill:**
- Skill discovery: ~500 tokens
- Read relevant sections: ~2500 tokens
- Copy templates: ~2000 tokens
- Customize: ~2000 tokens
- Total: ~7,000 tokens

**Savings: ~55% (8,500 tokens saved)**

---

## Success Criteria

A skill is complete when:

- [x] SKILL.md has valid YAML frontmatter
- [x] All 3 hooks covered (useChat, useCompletion, useObject)
- [x] v5 breaking changes documented
- [x] 11 working templates
- [x] Top 10-12 UI errors documented
- [x] Next.js App Router example
- [x] Next.js Pages Router example
- [x] Message persistence example
- [x] Tool calling UI example
- [x] Links to advanced topics
- [x] README.md has comprehensive keywords
- [x] Production-tested examples
- [x] Token savings >= 50%

---

## Notes for Implementation

**What to Emphasize:**
- v5 breaking changes (especially useChat input management)
- Practical Next.js examples (App Router + Pages Router)
- Common UI errors and solutions
- Streaming best practices
- Message rendering patterns

**What to De-Emphasize:**
- Generative UI / RSC (link only, advanced topic)
- Other frameworks (Svelte, Vue) - mention but don't detail
- Stream protocols internals (link to docs)
- Advanced transport customization
- CI/CD (link to Vercel docs)

**Critical Success Factors:**
- Templates must work copy-paste in Next.js projects
- v5 migration must be crystal clear (biggest pain point)
- Error solutions must be actionable
- Examples must show modern React patterns
- Links to official docs must be accurate

---

**Ready for execution with fresh context!**
