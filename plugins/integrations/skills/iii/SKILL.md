---
name: iii
description: |
  Build cross-language backends with the iii engine. Register functions in TypeScript,
  Python, or Rust callable from any connected service via WebSocket. Covers iii-sdk,
  state, KV Server, streams, triggers (HTTP/cron/queue/log), Bridge Client mesh,
  OpenTelemetry, Docker deployment, iii Console, and Prometheus metrics.
  Use when: setting up iii engine, cross-language function calls, iii-sdk integration,
  registerTrigger configuration, KV Server storage, queue/log triggers, Docker deploy,
  or debugging "ECONNREFUSED 49134", "type_not_found", "@iii-dev/sdk 404".
---

# iii - Cross-Language Backend Engine

> **SDK 0.3.0-alpha Breaking Change (verified 2026-02-18)**: The `registerTrigger` field is `trigger_type` (NOT `type`). HTTP triggers use `trigger_type: "api"` (NOT `"http"`). Using `type: "http"` causes silent 404s on all routes. This was confirmed in the tac-4-go rewrite from motia to direct iii-sdk.

> **SDK Note**: The iii.dev docs reference `@iii-dev/sdk` with a `Bridge` class — this package does **not exist on npm** (404 as of 2026-02-17). Always install `iii-sdk` (no scope). The docs SDK uses different conventions (dot separators, `trigger_type`, `function_path`). See `references/cross-language.md` for translation guide.

---

## Core Concepts

iii has two fundamental primitives:

1. **Register** - Make a function callable by the engine
2. **Call** - Invoke any registered function regardless of language or process

Services connect to the iii engine over WebSocket. The engine handles routing, retries, observability, state, streams, cron, and HTTP API exposure.

---

## Quick Start

### 1. Install the Engine

```bash
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
iii --version
```

Or run via Docker:

```bash
docker pull iiidev/iii:latest
docker run -p 3111:3111 -p 49134:49134 \
  -v ./iii-config.yaml:/app/config.yaml:ro \
  iiidev/iii:latest
```

### 2. Create Engine Config (`iii-config.yaml`)

```yaml
modules:
  - class: modules::api::RestApiModule
    config:
      port: 3111
      host: 127.0.0.1
      default_timeout: 30000
      concurrency_request_limit: 1024
      cors:
        allowed_origins: ["*"]
        allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]

  - class: modules::state::StateModule
    config:
      adapter:
        class: modules::state::adapters::KvStore
        config:
          store_method: file_based
          file_path: ./data/state_store.db

  - class: modules::shell::ExecModule
    config:
      exec:
        - bun run --enable-source-maps worker.js
```

> See `references/engine-modules.md` for full module configuration including StreamModule, OtelModule, QueueModule, PubSubModule, CronModule, KvServer, LoggingModule, and BridgeClientModule.

### 3. Start the Engine

```bash
iii -c iii-config.yaml
```

### 4. Create a TypeScript Service

```bash
mkdir my-service && cd my-service
npm init -y
npm install iii-sdk
```

Set `"type": "module"` in `package.json`.

```typescript
// src/worker.ts
import { init, getContext } from "iii-sdk";

const { registerFunction, registerTrigger, call, callVoid } = init(
  process.env.III_BRIDGE_URL ?? "ws://localhost:49134"
);

// Register a function callable by any connected service
const health = registerFunction({ id: "my-service::health" }, async () => {
  const { logger } = getContext();
  logger.info("Health check OK");
  return { status: 200, body: { healthy: true, timestamp: Date.now() } };
});

// Expose as HTTP endpoint via the engine's REST API module
registerTrigger({
  trigger_type: "api",
  function_id: health.id,
  config: { api_path: "health", http_method: "GET" },
});

console.log("Service started - listening for calls");
```

Run with: `npx tsx src/worker.ts`

Test: `curl http://localhost:3111/health`

---

## Critical Rules

### Always Do

- Use `service-name::function-name` convention for function IDs (e.g., `"client::health"`, `"data-service::transform"`)
- Set `"type": "module"` in `package.json` (SDK uses ESM)
- Use `process.env.III_BRIDGE_URL ?? "ws://localhost:49134"` for the engine address
- Start the iii engine **before** starting services
- Use `getContext()` for logging inside function handlers (provides structured OTEL logging)
- Use `Promise.allSettled()` when calling multiple remote functions in parallel (graceful partial failure)
- Use `GET /health` on port 3111 to check engine health before connecting services
- Use `index` (not `scope`) for KV Server function parameters — `scope` is for the State module only

### Never Do

- Never hardcode `ws://localhost:49134` without env var fallback
- Never use `process.env` in function IDs (they must be static strings)
- Never assume all services are available - handle missing services gracefully
- Never use 6-field cron expressions - iii supports **7 fields** (seconds included): `"*/30 * * * * * *"`
- **iii-sdk 0.3.0-alpha**: Use `trigger_type` (NOT `type`) in `registerTrigger`. Use `"api"` (NOT `"http"`) for HTTP triggers. Use `"queue"` for queue triggers, `"cron"` for cron triggers
- **iii-sdk 0.2.0**: Use `type` (NOT `trigger_type`). Use `"http"` for HTTP triggers
- Never import from `iii-sdk/state` or `iii-sdk/stream` for basic state operations - use `sdk.call("state::set", ...)` instead. Removed in 0.3.0
- Never `npm install @iii-dev/sdk` — this scoped package does not exist on npm (404). Use `iii-sdk` instead
- Never use dot separators in engine function paths — use `::` (double colon). `"kv_server::get"` not `"kv_server.get"`

---

## SDK Entry Points

| Import | Purpose |
|--------|---------|
| `iii-sdk` | Core: `init`, `getContext`, `withContext`, `Logger` (+ types). `init()` returns `ISdk` with `registerFunction`, `registerTrigger`, `call`, `callVoid`, `shutdown` methods |
| `iii-sdk/state` | Advanced: Direct `IState` interface (get/set/delete/list/update) |
| `iii-sdk/stream` | Advanced: Direct `IStream` interface with groups |
| `iii-sdk/telemetry` | OpenTelemetry: `initOtel`, `withSpan`, `getTracer`, `getMeter` |

For most use cases, use the core SDK and `call("state::set", ...)` / `call("state::get", ...)` for state.

---

## Function Registration

```typescript
const fn = registerFunction(
  {
    id: "service::action",           // Required: unique function ID
    description: "What it does",     // Optional: for discovery
    request_format: { /* schema */ },  // Optional: input schema
    response_format: { /* schema */ }, // Optional: output schema
    metadata: { version: "1.0" },    // Optional: custom metadata
  },
  async (payload) => {
    const { logger } = getContext();
    logger.info("Processing", { payload });
    return { result: "done" };       // Return value sent back to caller
  }
);

// fn.id = "service::action"
// fn.unregister() - removes the function
```

---

## Calling Functions

```typescript
// Awaitable call (returns result)
const result = await call<InputType, OutputType>("other-service::action", { data: "hello" });

// Fire-and-forget (no return value)
callVoid("log-service::audit", { event: "user_login" });

// Parallel calls with graceful failure
const [a, b] = await Promise.allSettled([
  call("service-a::process", payload),
  call("service-b::process", payload),
]);
```

### Built-in Functions

```typescript
// State management (uses 'scope')
await call("state::set", { scope: "shared", key: "VERSION", value: 1 });
const val = await call("state::get", { scope: "shared", key: "VERSION" });
const items = await call("state::list", { scope: "shared" });

// KV Server (uses 'index' — NOT 'scope')
await call("kv_server::set", { index: "default", key: "user:123", value: { name: "Alice" } });
const user = await call("kv_server::get", { index: "default", key: "user:123" });
await call("kv_server::delete", { index: "default", key: "user:123" });
const keys = await call("kv_server::list_keys_with_prefix", { prefix: "user:" });

// Queue — enqueue a message to a topic
await call("enqueue", { topic: "user.created", data: { id: "123", email: "user@example.com" } });

// Engine introspection
const functions = await call("engine::functions::list", {});
const workers = await call("engine::workers::list", {});

// Health check (HTTP, not via SDK)
// curl http://localhost:3111/health

// Graceful shutdown (new in 0.2.0)
await sdk.shutdown();  // Closes WebSocket, cleans up resources
```

> **Note**: `shutdown()` was added in 0.2.0. Always call it during graceful process termination.

---

## Triggers

### HTTP Trigger (API)

Exposes a function as an HTTP endpoint on the engine's REST API (default port 3111).

```typescript
// iii-sdk 0.3.0-alpha (current working — use this)
registerTrigger({
  trigger_type: "api",
  function_id: "service::handler",
  config: {
    api_path: "users/:id",           // Path params supported
    http_method: "POST",             // GET, POST, PUT, DELETE, OPTIONS
  },
});
// Accessible at: http://localhost:3111/users/123
```

> **Warning**: Using `type: "http"` (0.2.0 syntax) with iii engine 0.4.0+ causes silent 404s on all routes. Always use `trigger_type: "api"` with 0.3.0-alpha SDK.

The handler receives an `ApiRequest` object:

```typescript
registerFunction({ id: "service::handler" }, async (req: ApiRequest) => {
  const { path_params, query_params, body, headers, method } = req;
  return {
    status_code: 200,
    headers: { "Content-Type": "application/json" },
    body: { id: path_params.id, data: body },
  };
});
```

### Cron Trigger

Supports **7-field cron expressions** (seconds granularity):

```typescript
registerTrigger({
  trigger_type: "cron",
  function_id: "service::cleanup",
  config: { expression: "*/30 * * * * * *" },  // Every 30 seconds
});
// Fields: seconds minutes hours day-of-month month day-of-week year
```

### Queue Trigger

Invokes a function when a message is enqueued to a specific topic. Requires `QueueModule` in engine config.

```typescript
const consumer = registerFunction(
  { id: "events::on-user-created" },
  async (data) => {
    console.log("User created", data);
    return { ok: true };
  }
);

registerTrigger({
  trigger_type: "queue",
  function_id: consumer.id,
  config: { topic: "user.created" },
});

// Enqueue from anywhere:
await call("enqueue", { topic: "user.created", data: { id: "123", email: "user@example.com" } });
```

### Log Trigger

Invokes a function when log events match a level. Requires `LoggingModule` in engine config.

```typescript
registerFunction({ id: "monitoring::on-error" }, async (logEntry) => {
  // logEntry: { trace_id, message, level, function_name, date }
  const { logger } = getContext();
  logger.info("Error captured", logEntry);
  // Send alert, store in database, etc.
});

registerTrigger({
  trigger_type: "log",
  function_id: "monitoring::on-error",
  config: { level: "error" },  // Optional: info, warn, error, debug (omit for all)
});
```

---

## References

| Need | File |
|------|------|
| Full SDK type definitions and state/stream APIs | `references/api-reference.md` |
| Engine module configuration schemas | `references/engine-modules.md` |
| Cross-language examples, OpenTelemetry, env vars | `references/cross-language.md` |
| Docker deployment and project structure | `references/docker-deployment.md` |

---

## Known Issues

- **Alpha software**: API may change between releases
- **Port 49134 conflicts**: The engine's WebSocket port is fixed at 49134; ensure nothing else uses it
- **Docker networking**: On Linux Docker <20.10, `host.docker.internal` requires explicit `extra_hosts` mapping
- **Reconnection**: SDK auto-reconnects with exponential backoff (1s initial, 30s max, infinite retries by default)
- **CJS support**: 0.2.0 adds CommonJS exports alongside ESM - both `import` and `require` now work

### 0.3.0-alpha Breaking Changes (confirmed working 2026-02-18)

These are **current reality** with `iii-sdk@0.3.0-alpha.20260210122502` + iii engine 0.4.0:

- **`trigger_type` replaces `type`** in `registerTrigger` — use `trigger_type: "api"` (NOT `type: "http"`)
- **`"api"` replaces `"http"`** as the HTTP trigger type name
- **`iii-sdk/state` export removed** — use `call("state::set", ...)` and `call("state::get", ...)`
- **`iii-sdk/stream` renamed to `iii-sdk/streams`** (plural)
- **`ISdk` type no longer exported** from the main entry point
- **SDK transition**: The docs-only `@iii-dev/sdk` (Bridge class, dot separators) may become the official SDK. Monitor npm for `@iii-dev/sdk` availability

> **Verified**: tac-4-go project uses direct iii-sdk 0.3.0-alpha with `trigger_type: "api"` and all 4 HTTP endpoints + queue + cron work correctly.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ECONNREFUSED 127.0.0.1:49134` | Engine not running | Start with `iii -c iii-config.yaml` |
| Function call times out (30s) | Target service not connected | Start the service; check `engine::workers::list` |
| `Cannot find module 'iii-sdk'` | SDK not installed | `npm install iii-sdk` |
| HTTP endpoint returns 404 | Wrong trigger field or type | With 0.3.0-alpha: use `trigger_type: "api"` (NOT `type: "http"`). Verify `api_path` matches URL |
| Cron not firing | Wrong expression format | Use 7-field format: `sec min hour dom mon dow year` |
| State returns null | Wrong scope or key | Check scope/key strings match exactly |
| `trigger_type_not_found` | SDK/engine version mismatch | 0.2.0: use `type`. 0.3.0-alpha: use `trigger_type` |
| All routes 404 (silent) | Used `type: "http"` with 0.3.0-alpha SDK | Change to `trigger_type: "api"` — motia sends `"http"`, iii engine 0.4.0 expects `"api"` |
| KV Server timeout | KV Server module not in config | Add `modules::kv_server::KvServer` to `iii-config.yaml` |
| `module class not found` | Wrong singular/plural path | Try `stream` vs `streams` in class path; check engine version |
| `@iii-dev/sdk` npm 404 | Package not published | Use `iii-sdk` (no scope). `@iii-dev/sdk` is docs-only |
| Queue messages not processing | Missing queue trigger or wrong topic | Verify `registerTrigger({ type: "queue", config: { topic } })` matches enqueue topic |
