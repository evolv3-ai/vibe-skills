# Skills Catalog

**97 production-ready skills** organized by category.

Total errors prevented: **611+**

*Auto-generated on 2026-02-02 by `scripts/generate-skills-catalog.py`*

---

## Quick Navigation

- [Cloudflare Platform](#cloudflare-platform) (17 skills)
- [AI & Machine Learning](#ai--machine-learning) (13 skills)
- [Frontend & UI](#frontend--ui) (15 skills)
- [Authentication](#authentication) (5 skills)
- [Database & Storage](#database--storage) (6 skills)
- [Content Management](#content-management) (3 skills)
- [MCP & Tooling](#mcp--tooling) (5 skills)
- [Planning & Workflow](#planning--workflow) (9 skills)
- [Google Cloud & Workspace](#google-cloud--workspace) (6 skills)
- [Desktop & Mobile](#desktop--mobile) (2 skills)
- [Python](#python) (2 skills)
- [Utilities](#utilities) (11 skills)
- [Developer Workflow](#developer-workflow) (3 skills)

---

## Cloudflare Platform (17 skills)

### cloudflare-agents
Build AI agents with Cloudflare Agents SDK on Workers + Durable Objects. Provides WebSockets, state persistence, scheduling, and multi-agent coordination.
**Prevents 23 errors.**

**Triggers**: `cloudflare agents`, `agents sdk`, `cloudflare agents sdk`, `agents package`

---

### cloudflare-browser-rendering
Add headless Chrome automation with Puppeteer/Playwright on Cloudflare Workers. Use when: taking screenshots, generating PDFs, web scraping, crawling sites, browser automation, or troubleshooting XPat

---

### cloudflare-d1
Build with D1 serverless SQLite database on Cloudflare's edge. Use when: creating databases, writing SQL migrations, querying D1 from Workers, handling relational data, or troubleshooting D1_ERROR, st
**Prevents 14 errors.**

---

### cloudflare-durable-objects
Build stateful Durable Objects for real-time apps, WebSocket servers, coordination, and persistent state.
**Prevents 20 errors.**

---

### cloudflare-hyperdrive
Connect Workers to PostgreSQL/MySQL with Hyperdrive's global pooling and caching. Use when: connecting to existing databases, setting up connection pools, using node-postgres/mysql2, integrating Drizz
**Prevents 11 errors.**

**Triggers**: `hyperdrive`, `cloudflare hyperdrive`, `workers hyperdrive`, `postgres workers`

---

### cloudflare-images
Store and transform images with Cloudflare Images API and transformations. Use when: uploading images, implementing direct creator uploads, creating variants, generating signed URLs, optimizing format

**Triggers**: `cloudflare images`, `image upload cloudflare`, `imagedelivery.net`, `cloudflare image transformations`

---

### cloudflare-kv
Store key-value data globally with Cloudflare KV's edge network. Use when: caching API responses, storing configuration, managing user preferences, handling TTL expiration, or troubleshooting KV_ERROR

**Triggers**: `kv storage`, `cloudflare kv`, `kv namespace`, `workers kv`

---

### cloudflare-mcp-server
Build MCP servers on Cloudflare Workers - the only platform with official remote MCP support. TypeScript-based with OAuth, Durable Objects, and WebSocket hibernation.
**Prevents 24 errors.**

**Triggers**: `Model Context Protocol server`, `MCP server deployment`, `Build MCP server`, `Remote MCP`

---

### cloudflare-python-workers
Build Python APIs on Cloudflare Workers using pywrangler CLI and WorkerEntrypoint class pattern. Includes Python Workflows for multi-step DAG automation.
**Prevents 11 errors.**

---

### cloudflare-queues
Build async message queues with Cloudflare Queues for background processing. Use when: handling async tasks, batch processing, implementing retries, configuring dead letter queues, managing consumer c
**Prevents 13 errors.**

**Triggers**: `cloudflare queues`, `queues workers`, `message queue`, `queue bindings`

---

### cloudflare-r2
Store objects with R2's S3-compatible storage on Cloudflare's edge. Use when: uploading/downloading files, configuring CORS, generating presigned URLs, multipart uploads, managing metadata, or trouble
**Prevents 13 errors.**

**Triggers**: `r2 storage`, `cloudflare r2`, `r2 upload`, `r2 download`

---

### cloudflare-turnstile
Add bot protection with Turnstile (CAPTCHA alternative). Use when: protecting forms, securing login/signup, preventing spam, migrating from reCAPTCHA, integrating with React/Next.js/Hono, implementing

---

### cloudflare-vectorize
Build semantic search with Cloudflare Vectorize V2. Covers async mutations, 5M vectors/index, 31ms latency, returnMetadata enum changes, and V1 deprecation.
**Prevents 14 errors.**

**Triggers**: `base`, `base-en-v1.5`, `embedding-3-small`, `embedding-3-large`

---

### cloudflare-worker-base
Set up Cloudflare Workers with Hono routing, Vite plugin, and Static Assets.
**Prevents 10 errors.**

---

### cloudflare-workers-ai
Run LLMs and AI models on Cloudflare's GPU network with Workers AI. Includes Llama 4, Gemma 3, Mistral 3.1, Flux images, BGE embeddings, streaming, and AI Gateway. Handles 2025 breaking changes. Preve
**Prevents 7 errors.**

**Triggers**: `workers ai`, `cloudflare ai`, `ai bindings`, `llm workers`

---

### cloudflare-workflows
Build durable workflows with Cloudflare Workflows (GA April 2025). Features step.do, step.sleep, waitForEvent, Vitest testing, automatic retries, and state persistence for long-running tasks. Prevents
**Prevents 12 errors.**

**Triggers**: `Cloudflare Workflows`, `workflows`, `durable execution`, `WorkflowEntrypoint`

---

### drizzle-orm-d1
Build type-safe D1 databases with Drizzle ORM. Includes schema definition, migrations with Drizzle Kit, relations, and D1 batch API patterns.
**Prevents 18 errors.**

---

## AI & Machine Learning (13 skills)

### OpenAI Apps MCP
Build ChatGPT apps with MCP servers on Cloudflare Workers. Extend ChatGPT with custom tools and interactive widgets (HTML/JS UI).

---

### ai-sdk-core
Build backend AI with Vercel AI SDK v6 stable. Covers Output API (replaces generateObject/streamObject), speech synthesis, transcription, embeddings, MCP tools with security guidance. Includes v4→v5 m

---

### ai-sdk-ui
Build React chat interfaces with Vercel AI SDK v6. Covers useChat/useCompletion/useObject hooks, message parts structure, tool approval workflows, and 18 UI error solutions. Prevents documented issues

---

### claude-agent-sdk
Build autonomous AI agents with Claude Agent SDK. Structured outputs guarantee JSON schema validation, with plugins system and hooks for event-driven workflows.
**Prevents 14 errors.**

---

### claude-api
Build with Claude Messages API using structured outputs for guaranteed JSON schema validation. Covers prompt caching (90% savings), streaming SSE, tool use, and model deprecations.
**Prevents 16 errors.**

---

### elevenlabs-agents
Build conversational AI voice agents with ElevenLabs Platform. Configure agents, tools, RAG knowledge bases, agent versioning with A/B testing, and MCP security. React, React Native, or Swift SDKs. Pr
**Prevents 34 errors.**

**Triggers**: `taking**`, `call webhook**`

---

### google-gemini-api
Integrate Gemini API with @google/genai SDK (NOT deprecated @google/generative-ai). Text generation, multimodal (images/video/audio/PDFs), function calling, thinking mode, streaming. 1M input tokens.
**Prevents 14 errors.**

**Triggers**: `gemini api`, `google gemini`, `@google/genai`, `gemini-2.5-pro`

---

### google-gemini-embeddings
Build RAG systems and semantic search with Gemini embeddings (gemini-embedding-001). 768-3072 dimension vectors, 8 task types, Cloudflare Vectorize integration.
**Prevents 13 errors.**

---

### google-gemini-file-search
Build document Q&A with Gemini File Search - fully managed RAG with automatic chunking, embeddings, and citations. Upload 100+ file formats, query with natural language.

**Triggers**: `file search`, `gemini rag`, `document search`, `knowledge base`

---

### openai-agents
Build AI applications with OpenAI Agents SDK - text agents, voice agents, multi-agent handoffs, tools with Zod schemas, guardrails, and streaming.
**Prevents 11 errors.**

**Triggers**: `triggers when you mention:`, `openai agents`, `openai agents sdk`, `openai agents js`

---

### openai-api
Build with OpenAI stateless APIs - Chat Completions (GPT-5.2, o3), Realtime voice, Batch API (50% savings), Embeddings, DALL-E 3, Whisper, and TTS.
**Prevents 16 errors.**

**Triggers**: `openai api`, `chat completions`, `chatgpt api`, `gpt-5`

---

### openai-assistants
Build stateful chatbots with OpenAI Assistants API v2 - Code Interpreter, File Search (10k files), Function Calling.
**Prevents 10 errors.**

---

### openai-responses
Build agentic AI with OpenAI Responses API - stateful conversations with preserved reasoning, built-in tools (Code Interpreter, File Search, Web Search), and MCP integration.
**Prevents 11 errors.**

**Triggers**: `responses api`, `openai responses`, `stateful openai`, `openai mcp`

---

## Frontend & UI (15 skills)

### accessibility
Build WCAG 2.1 AA compliant websites with semantic HTML, proper ARIA, focus management, and screen reader support. Includes color contrast (4.5:1 text), keyboard navigation, form labels, and live regi

---

### auto-animate
Zero-config animations for React, Vue, Solid, Svelte, Preact with @formkit/auto-animate (3.28kb).
**Prevents 15 errors.**

---

### hono-routing
Build type-safe APIs with Hono for Cloudflare Workers, Deno, Bun, Node.js. Routing, middleware, validation (Zod/Valibot), RPC, streaming (SSE), WebSocket, security (CSRF, secureHeaders).

---

### motion
Build React animations with Motion (Framer Motion) - gestures (drag, hover, tap), scroll effects, spring physics, layout animations, SVG. Bundle: 2.3 KB (mini) to 34 KB (full).

---

### nextjs
Build Next.js 16 apps with App Router, Server Components/Actions, Cache Components ("use cache"), and async route params. Includes proxy.ts and React 19.2.
**Prevents 25 errors.**

---

### react-hook-form-zod
Build type-safe validated forms using React Hook Form v7 and Zod v4. Single schema works on client and server with full TypeScript inference via z.infer.

---

### responsive-images
Implement performant responsive images with srcset, sizes, lazy loading, and modern formats (WebP, AVIF). Covers aspect-ratio for CLS prevention, picture element for art direction, and fetchpriority f

**Triggers**: `srcset`, `loading=`, `lazy`, `eager`

---

### tailwind-patterns
Production-ready Tailwind CSS patterns for common website components: responsive layouts, cards, navigation, forms, buttons, and typography. Includes spacing scale, breakpoints, mobile-first patterns,

**Triggers**: `Tailwind CSS`, `CSS utility classes`, `first CSS`, `shadcn/ui components`

---

### tailwind-v4-shadcn
Set up Tailwind v4 with shadcn/ui using @theme inline pattern and CSS variable architecture. Four-step pattern: CSS variables, Tailwind mapping, base styles, automatic dark mode.
**Prevents 8 errors.**

---

### tanstack-query
Manage server state in React with TanStack Query v5. Covers useMutationState, simplified optimistic updates, throwOnError, network mode (offline/PWA), and infiniteQueryOptions.

---

### tanstack-router
Build type-safe, file-based React routing with TanStack Router. Supports client-side navigation, route loaders, and TanStack Query integration.
**Prevents 20 errors.**

**Triggers**: `TanStack Router`, `tanstack router`, `@tanstack/react-router`, `type-safe routing`

---

### tanstack-start
Build full-stack React apps with TanStack Start on Cloudflare Workers. Type-safe routing, server functions, SSR/streaming, D1/KV/R2 integration.
**Prevents 9 errors.**

---

### tanstack-table
Build headless data tables with TanStack Table v8. Server-side pagination, filtering, sorting, and virtualization for Cloudflare Workers + D1.
**Prevents 12 errors.**

**Triggers**: `data table`, `datagrid`, `table component`, `server-side pagination`

---

### tiptap
Build rich text editors with Tiptap - headless editor framework with React and Tailwind v4. Covers SSR-safe setup, image uploads, prose styling, and collaborative editing.

---

### zustand-state-management
Build type-safe global state in React with Zustand. Supports TypeScript, persist middleware, devtools, slices pattern, and Next.js SSR with hydration handling.
**Prevents 6 errors.**

---

## Authentication (5 skills)

### azure-auth
Microsoft Entra ID (Azure AD) authentication for React SPAs with MSAL.js and Cloudflare Workers JWT validation using jose library. Full-stack pattern with Authorization Code Flow + PKCE.
**Prevents 8 errors.**

---

### better-auth
Self-hosted auth for TypeScript/Cloudflare Workers with social auth, 2FA, passkeys, organizations, RBAC, and 15+ plugins. Requires Drizzle ORM or Kysely for D1 (no direct adapter). Self-hosted alterna

**Triggers**: `better-auth`, `The library name`, `authentication with D1`, `Cloudflare D1 auth setup`

---

### clerk-auth
Clerk auth with API Keys beta (Dec 2025), Next.js 16 proxy.ts (March 2025 CVE context), API version 2025-11-10 breaking changes, clerkMiddleware() options, webhooks, production considerations (GCP out
**Prevents 15 errors.**

**Triggers**: `clerk`, `clerk auth`, `clerk authentication`, `@clerk/nextjs`

---

### firebase-auth
Build with Firebase Authentication - email/password, OAuth providers, phone auth, and custom tokens. Use when: setting up auth flows, implementing sign-in/sign-up, managing user sessions, protecting r
**Prevents 12 errors.**

---

### oauth-integrations
Implement OAuth 2.0 authentication with GitHub and Microsoft Entra (Azure AD) in Cloudflare Workers

**Triggers**: `GitHub OAuth`, `GitHub authentication`, `GitHub API`, `Microsoft OAuth`

---

## Database & Storage (6 skills)

### firebase-firestore
Build with Firestore NoSQL database - real-time sync, offline support, and scalable document storage. Use when: creating collections, querying documents, setting up security rules, handling real-time
**Prevents 10 errors.**

---

### firebase-storage
Build with Firebase Cloud Storage - file uploads, downloads, and secure access. Use when: uploading images/files, generating download URLs, implementing file pickers, setting up storage security rules
**Prevents 9 errors.**

---

### neon-vercel-postgres
Set up serverless Postgres with Neon or Vercel Postgres for Cloudflare Workers/Edge. Includes connection pooling, git-like branching, and Drizzle ORM integration.

---

### snowflake-platform
Build on Snowflake's AI Data Cloud with snow CLI, Cortex AI (COMPLETE, SUMMARIZE, AI_FILTER), Native Apps, and Snowpark. Covers JWT auth, account identifiers, Marketplace publishing.
**Prevents 11 errors.**

**Triggers**: `snowflake`, `snow cli`, `snowflake cli`, `snowflake connection`

---

### vercel-blob
Integrate Vercel Blob for file uploads and CDN-delivered assets in Next.js. Supports client-side uploads with presigned URLs and multipart transfers for large files.
**Prevents 16 errors.**

**Triggers**: `@vercel/blob`, `vercel blob`, `vercel storage`, `vercel file upload`

---

### vercel-kv
Integrate Redis-compatible Vercel KV for caching, session management, and rate limiting in Next.js. Powered by Upstash with strong consistency and TTL support.

**Triggers**: `@vercel/kv`, `vercel kv`, `vercel redis`, `upstash vercel`

---

## Content Management (3 skills)

### sveltia-cms
Set up Sveltia CMS - lightweight Git-backed CMS successor to Decap/Netlify CMS (300KB bundle, 270+ fixes). Framework-agnostic for Hugo, Jekyll, 11ty, Astro.
**Prevents 10 errors.**

---

### tinacms
Build content-heavy sites with Git-backed TinaCMS. Provides visual editing for blogs, documentation, and marketing sites. Supports Next.js, Vite+React, and Astro with TinaCloud or Node.js self-hosting
**Prevents 10 errors.**

---

### wordpress-plugin-core
Build secure WordPress plugins with hooks, database interactions, Settings API, custom post types, and REST API. Covers Simple, OOP, and PSR-4 architecture patterns plus the Security Trinity. Includes

---

## MCP & Tooling (5 skills)

### MCP OAuth Cloudflare
Add OAuth authentication to MCP servers on Cloudflare Workers. Uses @cloudflare/workers-oauth-provider with Google OAuth for Claude.ai-compatible authentication.
**Prevents 9 errors.**

**Triggers**: `mcp oauth`, `mcp authentication`, `mcp server auth`, `oauth mcp server`

---

### fastmcp
Build MCP servers in Python with FastMCP to expose tools, resources, and prompts to LLMs. Supports storage backends, middleware, OAuth Proxy, OpenAPI integration, and FastMCP Cloud deployment. Prevent

---

### mcp-cli-scripts
Build CLI scripts alongside MCP servers for terminal environments. File I/O, batch processing, caching, richer output formats. Templates for TypeScript scripts and SCRIPTS.md.

**Triggers**: `MCP server scripts`, `SCRIPTS.md`, `npx tsx scripts`, `MCP batch operations`

---

### ts-agent-sdk
Generate typed TypeScript SDKs for AI agents to interact with MCP servers. Converts JSON-RPC curl commands to clean function calls. Auto-generates types, client methods, and example scripts from MCP t

**Triggers**: `generate sdk for mcp`, `create agent sdk`, `typed mcp client`, `ts-agent-sdk`

---

### typescript-mcp
Build MCP servers with TypeScript on Cloudflare Workers. Covers tools, resources, prompts, tasks, authentication (API keys, OAuth, Zero Trust), and Cloudflare service integrations.
**Prevents 20 errors.**

---

## Planning & Workflow (9 skills)

### context-mate
Entry point to the Context Mate toolkit - skills, agents, and commands that work with Claude Code's

---

### docs-workflow
Four slash commands for documentation lifecycle: /docs, /docs-init, /docs-update, /docs-claude. Create, maintain, and audit CLAUDE.md, README.md, and docs/ structure with smart templates.

**Triggers**: `create CLAUDE.md`, `initialize documentation`, `docs init`, `update documentation`

---

### project-health
AI-agent readiness auditing for project documentation and workflows. Evaluates whether

**Triggers**: `AI readability`, `agent readiness`, `context auditor`, `workflow validator`

---

### project-planning
Generate structured planning docs for web projects with context-safe phases, verification criteria, and exit conditions. Creates IMPLEMENTATION_PHASES.md plus conditional docs.

**Triggers**: `new project`, `start a project`, `create app`, `build app`

---

### project-session-management
Track progress across sessions using SESSION.md with git checkpoints and concrete next actions. Converts IMPLEMENTATION_PHASES.md into trackable session state.

**Triggers**: `create SESSION.md`, `set up session tracking`, `manage session state`, `session handoff`

---

### project-workflow
Nine integrated slash commands for complete project lifecycle: /explore-idea, /plan-project, /plan-feature, /wrap-session, /continue-session, /workflow, /release, /brief, /reflect.

**Triggers**: `triggered by keywords.`, `Mention`, `start new project`, `/plan-project`

---

### skill-creator
Design effective Claude Code skills with optimal descriptions, progressive disclosure, and error prevention patterns. Covers freedom levels, token efficiency, and quality standards.

---

### skill-review
Audit claude-skills with systematic 9-phase review: standards compliance, official docs verification, code accuracy, cross-file consistency, and version drift detection.

**Triggers**: `review this skill`, `review the X skill`, `audit [skill-name]`, `check if X needs updates`

---

### sub-agent-patterns
Comprehensive guide to sub-agents in Claude Code: built-in agents (Explore, Plan, general-purpose), custom agent creation, configuration, and delegation patterns.

**Triggers**: `Agent Concepts:**`, `sub-agent`, `sub-agents`, `subagent`

---

## Google Cloud & Workspace (6 skills)

### django-cloud-sql-postgres
Deploy Django on Google App Engine Standard with Cloud SQL PostgreSQL. Covers Unix socket connections, Cloud SQL Auth Proxy for local dev, Gunicorn configuration, and production-ready settings.

---

### google-app-engine
Deploy Python applications to Google App Engine Standard/Flexible. Covers app.yaml configuration, Cloud SQL socket connections, Cloud Storage for static files, scaling settings, and environment variab

---

### google-chat-api
Build Google Chat bots and webhooks with Cards v2, interactive forms, and Cloudflare Workers. Covers Spaces/Members/Reactions APIs, bearer token verification, and dialog patterns.

**Triggers**: `google chat`, `chat bot`, `cards v2`, `chat forms`

---

### google-spaces-updates
Post team updates to Google Chat Spaces via webhook. Deployment notifications, bug fixes, feature announcements, questions. Reads config from .claude/settings.json, includes git context.

**Triggers**: `post to team`, `notify team`, `update the team`, `tell Deepinder`

---

### google-workspace
Build integrations with Google Workspace APIs (Gmail, Calendar, Drive, Sheets, Docs, Chat, Meet, Forms, Tasks, Admin SDK). Covers OAuth 2.0, service accounts, rate limits, batch operations, and Cloudf

**Triggers**: `google workspace`, `google oauth`, `wide delegation`, `google api rate limit`

---

### streamlit-snowflake
Build and deploy Streamlit apps natively in Snowflake. Covers snowflake.yml scaffolding, Snowpark sessions, multi-page structure, Marketplace publishing as Native Apps, and caller's rights connections

**Triggers**: `streamlit snowflake`, `streamlit in snowflake`, `SiS (Streamlit in Snowflake)`, `snow streamlit deploy`

---

## Desktop & Mobile (2 skills)

### electron-base
Build secure desktop applications with Electron 33, Vite, React, and TypeScript. Covers type-safe IPC via contextBridge, OAuth with custom protocol handlers, native module compatibility (better-sqlite

**Triggers**: `electron`, `electron-builder`, `electron-store`, `vite-plugin-electron`

---

### react-native-expo
Build React Native 0.76+ apps with Expo SDK 52-54. Covers mandatory New Architecture (0.82+/SDK 55+), React 19 changes, SDK 54 breaking changes (expo-av, expo-file-system, Reanimated v4), and Swift iO
**Prevents 16 errors.**

---

## Python (2 skills)

### fastapi
Build Python APIs with FastAPI, Pydantic v2, and SQLAlchemy 2.0 async. Covers project structure, JWT auth, validation, and database integration with uv package manager.
**Prevents 7 errors.**

**Triggers**: `FastAPI`, `Python API`, `Pydantic`, `uvicorn`

---

### flask
Build Python web apps with Flask using application factory pattern, Blueprints, and Flask-SQLAlchemy.
**Prevents 9 errors.**

**Triggers**: `Flask`, `Flask-SQLAlchemy`, `Flask-Login`, `Flask blueprints`

---

## Utilities (11 skills)

### color-palette
Generate complete, accessible color palettes from a single brand hex. Creates 11-shade scale (50-950), semantic tokens (background, foreground, card, muted), and dark mode variants. Includes WCAG cont

**Triggers**: `color palette`, `tailwind colors`, `css variables`, `hsl colors`

---

### email-gateway
Multi-provider email sending for Cloudflare Workers and Node.js applications.

**Triggers**: `resend`, `sendgrid`, `mailgun`, `smtp2go`

---

### favicon-gen
Generate custom favicons from logos, text, or brand colors - prevents launching with CMS defaults. Extract icons from logos, create monogram favicons from initials, or use branded shapes. Outputs all

---

### firecrawl-scraper
Convert websites into LLM-ready data with Firecrawl API. Features: scrape, crawl, map, search, extract, agent (autonomous), batch operations, and change tracking. Handles JavaScript, anti-bot bypass,
**Prevents 10 errors.**

---

### icon-design
Select semantically appropriate icons for websites using Lucide, Heroicons, or Phosphor. Covers concept-to-icon mapping, React/HTML templates, and tree-shaking patterns.

---

### image-gen
Generate website images with Gemini 3 Native Image Generation. Covers hero banners, service cards, infographics with legible text, and multi-turn editing. Includes Australian-specific imagery patterns
**Prevents 5 errors.**

**Triggers**: `gemini image generation`, `gemini-3-flash-image-generation`, `3-pro-image-generation`, `google genai`

---

### jquery-4
Migrate jQuery 3.x to 4.0.0 safely in WordPress and legacy web projects. Covers all breaking changes: removed APIs ($.isArray, $.trim, $.parseJSON, $.type), focus event order changes, slim build diffe

---

### office
Generate Office documents (DOCX, XLSX, PDF, PPTX) with TypeScript. Pure JS libraries that work everywhere: Claude Code CLI, Cloudflare Workers, browsers. Uses docx (Word), xlsx/SheetJS (Excel), pdf-li

---

### open-source-contributions
Create maintainer-friendly pull requests with clean code and professional communication.

**Triggers**: `submit PR to [project]`, `create pull request for [repo]`, `contribute to [project]`, `open source contribution`

---

### playwright-local
Build browser automation and web scraping with Playwright on your local machine.
**Prevents 10 errors.**

---

### seo-meta
Generate complete SEO meta tags for every page. Covers title patterns, meta descriptions, Open Graph, Twitter Cards, and JSON-LD structured data (LocalBusiness, Service, FAQ, BreadcrumbList).

**Triggers**: `seo`, `open graph`, `twitter cards`, `json-ld`

---

## Developer Workflow (3 skills)

### agent-development
Design and build custom Claude Code agents with effective descriptions, tool access patterns,

**Triggers**: `create agent`, `custom agent`, `build agent`, `agent description`

---

### deep-debug
Multi-agent investigation for stubborn bugs. Use when: going in circles debugging, need to investigate browser/API interactions, complex bugs resisting normal debugging, or when symptoms don't match e

---

### developer-toolbox
Essential development workflow agents for code review, debugging, testing, documentation, and git operations.

**Triggers**: `step`

---
