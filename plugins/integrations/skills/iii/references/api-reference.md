# iii-sdk API Reference

> Full type definitions for `iii-sdk@0.2.0` | Engine modules reference

## Core SDK (`iii-sdk`)

### init()

```typescript
import { init, getContext } from "iii-sdk";

const sdk = init(address: string, options?: InitOptions);
// Returns: ISdk
```

### InitOptions

```typescript
type InitOptions = {
  workerName?: string;
  enableMetricsReporting?: boolean;
  invocationTimeoutMs?: number; // default: 30000
  reconnectionConfig?: Partial<IIIReconnectionConfig>;
  otel?: Omit<OtelConfig, 'engineWsUrl'>;
};

interface IIIReconnectionConfig {
  initialDelayMs: number;    // default: 1000
  maxDelayMs: number;        // default: 30000
  backoffMultiplier: number; // default: 2
  jitterFactor: number;      // default: 0.3
  maxRetries: number;        // default: -1 (infinite)
}
```

### ISdk Interface

```typescript
interface ISdk {
  registerFunction(func: RegisterFunctionInput, handler: RemoteFunctionHandler): FunctionRef;
  registerTrigger(trigger: RegisterTriggerInput): Trigger;
  registerTriggerType<TConfig>(triggerType: RegisterTriggerTypeInput, handler: TriggerHandler<TConfig>): void;
  unregisterTriggerType(triggerType: RegisterTriggerTypeInput): void;
  call<TInput, TOutput>(function_id: string, data: TInput): Promise<TOutput>;
  callVoid<TInput>(function_id: string, data: TInput): void;
  createStream<TData>(streamName: string, stream: IStream<TData>): void;
  onFunctionsAvailable(callback: FunctionsAvailableCallback): () => void;
  onLog(callback: LogCallback, config?: LogConfig): () => void;
  on(event: string, callback: (arg?: unknown) => void): void;
  shutdown(): Promise<void>;
}
```

### Function Registration Types

```typescript
type RegisterFunctionInput = {
  id: string;
  description?: string;
  request_format?: RegisterFunctionFormat;
  response_format?: RegisterFunctionFormat;
  metadata?: Record<string, unknown>;
};

type RegisterFunctionFormat = {
  name: string;
  description?: string;
  type: 'string' | 'number' | 'boolean' | 'object' | 'array' | 'null' | 'map';
  body?: RegisterFunctionFormat[];
  items?: RegisterFunctionFormat;
  required?: boolean;
};

type FunctionRef = { id: string; unregister: () => void };
type RemoteFunctionHandler<TInput = any, TOutput = any> = (data: TInput) => Promise<TOutput>;
```

### Trigger Types

```typescript
type RegisterTriggerInput = {
  type: string;          // 'http', 'cron', 'event', or custom
  function_id: string;
  config: unknown;
};

// HTTP trigger config
{ api_path: string; http_method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'OPTIONS' }

// Cron trigger config (7 fields - seconds included)
{ expression: string }  // e.g. "*/30 * * * * * *"

type Trigger = { unregister(): void };
```

### Custom Trigger Types

```typescript
type RegisterTriggerTypeInput = { id: string; description: string };

type TriggerConfig<TConfig> = {
  id: string;
  function_id: string;
  config: TConfig;
};

type TriggerHandler<TConfig> = {
  registerTrigger(config: TriggerConfig<TConfig>): Promise<void>;
  unregisterTrigger(config: TriggerConfig<TConfig>): Promise<void>;
};
```

### Context & Logger

```typescript
type Context = { logger: Logger; trace?: Span };

declare const getContext: () => Context;
declare const withContext: <T>(fn: (context: Context) => Promise<T>, ctx: Context) => Promise<T>;

declare class Logger {
  info(message: string, data?: any): void;
  warn(message: string, data?: any): void;
  error(message: string, data?: any): void;
  debug(message: string, data?: any): void;
}
```

### API Request/Response

```typescript
type ApiRequest<TBody = unknown> = {
  path_params: Record<string, string>;
  query_params: Record<string, string | string[]>;
  body: TBody;
  headers: Record<string, string | string[]>;
  method: string;
};

type ApiResponse<TStatus extends number = number, TBody = string | Buffer | Record<string, unknown>> = {
  status_code: TStatus;
  headers?: Record<string, string>;
  body: TBody;
};
```

### Event & Worker Types

```typescript
type FunctionInfo = {
  function_id: string;
  description?: string;
  request_format?: RegisterFunctionFormat;
  response_format?: RegisterFunctionFormat;
  metadata?: Record<string, unknown>;
};

type WorkerInfo = {
  id: string;
  name?: string;
  runtime?: string;
  version?: string;
  os?: string;
  ip_address?: string;
  status: WorkerStatus;
  connected_at_ms: number;
  function_count: number;
  functions: string[];
  active_invocations: number;
};

type WorkerStatus = 'connected' | 'available' | 'busy' | 'disconnected';
type IIIConnectionState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting' | 'failed';
```

### Engine Constants

```typescript
const EngineFunctions = {
  LIST_FUNCTIONS: "engine::functions::list",
  LIST_WORKERS: "engine::workers::list",
  REGISTER_WORKER: "engine::workers::register",
};

const LogFunctions = {
  INFO: "engine::log::info",
  WARN: "engine::log::warn",
  ERROR: "engine::log::error",
  DEBUG: "engine::log::debug",
};

const DEFAULT_INVOCATION_TIMEOUT_MS = 30000;
```

---

## Engine Built-in Functions

All engine built-in functions are called via `sdk.call(function_path, params)`.

### State Module Functions

| Function | Input | Output |
|----------|-------|--------|
| `state::get` | `{ scope: string, key: string }` | `T \| null` |
| `state::set` | `{ scope: string, key: string, value: any }` | `{ old_value?: T, new_value: T } \| null` |
| `state::delete` | `{ scope: string, key: string }` | `{ old_value?: any }` |
| `state::list` | `{ scope: string }` | `T[]` |
| `state::update` | `{ scope: string, key: string, ops: UpdateOp[] }` | `{ old_value?: T, new_value: T } \| null` |

### KV Server Functions

KV Server uses `index` (not `scope`) as its namespace parameter.

| Function | Input | Output |
|----------|-------|--------|
| `kv_server::get` | `{ index: string, key: string }` | `any \| null` |
| `kv_server::set` | `{ index: string, key: string, value: any }` | `object` |
| `kv_server::delete` | `{ index: string, key: string }` | `any \| null` |
| `kv_server::list` | `{ index: string, key: string }` | `any[]` |
| `kv_server::list_keys_with_prefix` | `{ prefix: string }` | `string[]` |

### Queue Functions

| Function | Input | Output |
|----------|-------|--------|
| `enqueue` | `{ topic: string, data: any }` | `null` |

### Stream Functions

| Function | Input | Output |
|----------|-------|--------|
| `stream::set` | `{ stream_name: string, group_id: string, item_id: string, data: any }` | `{ old_value?: T, new_value: T }` |
| `stream::get` | `{ stream_name: string, group_id: string, item_id: string }` | `T \| null` |
| `stream::delete` | `{ stream_name: string, group_id: string, item_id: string }` | `{ old_value?: any }` |
| `stream::list` | `{ stream_name: string, group_id: string }` | `T[]` |

### Engine Introspection

| Function | Input | Output |
|----------|-------|--------|
| `engine::functions::list` | `{}` | `FunctionInfo[]` |
| `engine::workers::list` | `{}` | `WorkerInfo[]` |
| `engine::workers::register` | `WorkerRegistration` | `void` |
| `engine::log::info` | `{ message: string, data?: any }` | `void` |
| `engine::log::warn` | `{ message: string, data?: any }` | `void` |
| `engine::log::error` | `{ message: string, data?: any }` | `void` |
| `engine::log::debug` | `{ message: string, data?: any }` | `void` |

### Bridge Module Functions

Available when `BridgeClientModule` is configured:

| Function | Input | Output |
|----------|-------|--------|
| `bridge::invoke` | `{ function_path: string, data?: any, timeout_ms?: number }` | `any` |
| `bridge::invoke_async` | `{ function_path: string, data?: any }` | `void` |

---

## State Module (`iii-sdk/state`)

```typescript
interface IState {
  get<TData>(input: { scope: string; key: string }): Promise<TData | null>;
  set<TData>(input: { scope: string; key: string; data: any }): Promise<{ old_value?: TData; new_value: TData } | null>;
  delete(input: { scope: string; key: string }): Promise<{ old_value?: any }>;
  list<TData>(input: { scope: string }): Promise<TData[]>;
  update<TData>(input: { scope: string; key: string; ops: UpdateOp[] }): Promise<{ old_value?: TData; new_value: TData } | null>;
}

declare enum StateEventType {
  Created = "state:created",
  Updated = "state:updated",
  Deleted = "state:deleted",
}
```

---

## Stream Module (`iii-sdk/stream`)

```typescript
interface IStream<TData> {
  get(input: { stream_name: string; group_id: string; item_id: string }): Promise<TData | null>;
  set(input: { stream_name: string; group_id: string; item_id: string; data: any }): Promise<{ old_value?: TData; new_value: TData } | null>;
  delete(input: { stream_name: string; group_id: string; item_id: string }): Promise<{ old_value?: any }>;
  list(input: { stream_name: string; group_id: string }): Promise<TData[]>;
  listGroups(input: { stream_name: string }): Promise<string[]>;
  update(input: { stream_name: string; group_id: string; item_id: string; ops: UpdateOp[] }): Promise<{ old_value?: TData; new_value: TData } | null>;
}
```

### Update Operations (shared by State and Stream)

```typescript
type UpdateOp =
  | { type: 'set'; path: string; value: any }
  | { type: 'increment'; path: string; by: number }
  | { type: 'decrement'; path: string; by: number }
  | { type: 'remove'; path: string }
  | { type: 'merge'; path: string; value: any };
```

### Stream Auth & Join

```typescript
interface StreamAuthInput {
  headers: Record<string, string>;
  path: string;
  query_params: Record<string, string[]>;
  addr: string;
}

interface StreamAuthResult { context?: any }
interface StreamJoinLeaveEvent {
  subscription_id: string;
  stream_name: string;
  group_id: string;
  id?: string;
  context?: any;
}
interface StreamJoinResult { unauthorized: boolean }
```

---

## Telemetry Module (`iii-sdk/telemetry`)

### Init & Shutdown

```typescript
declare function initOtel(config?: OtelConfig): void;
declare function shutdownOtel(): Promise<void>;

interface OtelConfig {
  enabled?: boolean;
  serviceName?: string;
  serviceVersion?: string;
  serviceNamespace?: string;
  serviceInstanceId?: string;
  engineWsUrl?: string;
  instrumentations?: Instrumentation[];
  metricsEnabled?: boolean;
  metricsExportIntervalMs?: number; // default: 60000
  reconnectionConfig?: Partial<ReconnectionConfig>;
}
```

### Tracing

```typescript
declare function getTracer(): Tracer | null;
declare function withSpan<T>(name: string, options: { kind?: SpanKind; traceparent?: string }, fn: (span: Span) => Promise<T>): Promise<T>;
```

### Metrics

```typescript
declare function getMeter(): Meter | null;
declare function registerWorkerGauges(meter: Meter, options: { workerId: string; workerName?: string }): void;
declare function stopWorkerGauges(): void;
```

### W3C Trace Context Propagation

```typescript
declare function injectTraceparent(): string | undefined;
declare function extractTraceparent(traceparent: string): Context;
declare function injectBaggage(): string | undefined;
declare function extractBaggage(baggage: string): Context;
declare function currentTraceId(): string | undefined;
declare function currentSpanId(): string | undefined;
declare function getBaggageEntry(key: string): string | undefined;
declare function setBaggageEntry(key: string, value: string): Context;
```

### Log Events

```typescript
type OtelLogEvent = {
  timestamp_unix_nano: number;
  observed_timestamp_unix_nano: number;
  severity_number: number;
  severity_text: string;
  body: string;
  attributes: Record<string, unknown>;
  trace_id?: string;
  span_id?: string;
  resource: Record<string, string>;
  service_name: string;
};

type LogSeverityLevel = 'trace' | 'debug' | 'info' | 'warn' | 'error' | 'fatal' | 'all';
type LogConfig = { level?: LogSeverityLevel };
```

### Worker Metrics Collector

```typescript
declare class WorkerMetricsCollector {
  constructor(options?: { eventLoopResolutionMs?: number });
  collect(): WorkerMetrics;
  stopMonitoring(): void;
}

type WorkerMetrics = {
  memory_heap_used?: number;
  memory_heap_total?: number;
  memory_rss?: number;
  memory_external?: number;
  cpu_user_micros?: number;
  cpu_system_micros?: number;
  cpu_percent?: number;
  event_loop_lag_ms?: number;
  uptime_seconds?: number;
  timestamp_ms: number;
  runtime: string;
};
```

---

## `@iii-dev/sdk` — Upcoming SDK (NOT on npm)

> **WARNING**: `@iii-dev/sdk` is documented at iii.dev/docs but does **not exist on npm** as of 2026-02-17. `npm install @iii-dev/sdk` returns 404. Use `iii-sdk@0.2.0` instead. This section is provided for forward-compatibility reference only.

### Bridge Class

```typescript
import { Bridge } from "@iii-dev/sdk";  // NOT ON NPM — future package

const bridge = new Bridge(process.env.III_BRIDGE_URL ?? "ws://localhost:49134");
```

### Key API Differences vs `iii-sdk@0.2.0`

| Aspect | `iii-sdk@0.2.0` (use this) | `@iii-dev/sdk` (docs only) |
|--------|----------------------------|---------------------------|
| Entry point | `init(address)` → `ISdk` | `new Bridge(url)` |
| Register function | `registerFunction({ id: "svc::fn" }, handler)` | `bridge.registerFunction({ function_path: "svc.fn", handler })` |
| Register trigger | `registerTrigger({ type: "http", function_id })` | `bridge.registerTrigger({ trigger_type: "api", function_path })` |
| Call function | `call<I, O>(function_id, data)` | `bridge.invokeFunction(function_path, data)` |
| Fire-and-forget | `callVoid(function_id, data)` | `bridge.invokeFunctionAsync(function_path, data)` |
| Register service | N/A | `bridge.registerService({ name, description })` |
| Separator | `::` (double colon) | `.` (dot) |
| HTTP trigger type | `"http"` | `"api"` |

### Methods (docs-only reference)

```typescript
// NOT ON NPM — for reference only
interface Bridge {
  registerFunction(input: { function_path: string; handler: Function }): void;
  registerTrigger(input: { trigger_type: string; function_path: string; config: unknown }): Trigger;
  registerService(input: { name: string; description?: string }): void;
  registerTriggerType<TConfig>(type: { id: string; description: string }, handler: TriggerHandler<TConfig>): void;
  unregisterTriggerType(type: { id: string }): void;
  invokeFunction<TInput, TOutput>(function_path: string, data: TInput): Promise<TOutput>;
  invokeFunctionAsync<TInput>(function_path: string, data: TInput): void;
}
```

### Translation Examples

```typescript
// @iii-dev/sdk style (docs) → iii-sdk@0.2.0 style (npm)

// Register function
// DOCS: bridge.registerFunction({ function_path: "users.create", handler: fn })
// NPM:  registerFunction({ id: "users::create" }, fn)

// Register trigger
// DOCS: bridge.registerTrigger({ trigger_type: "api", function_path: "users.create", config: { api_path: "/users", http_method: "POST" } })
// NPM:  registerTrigger({ type: "http", function_id: "users::create", config: { api_path: "users", http_method: "POST" } })

// Call function
// DOCS: await bridge.invokeFunction("kv_server::get", { index: "default", key: "user:123" })
// NPM:  await call("kv_server::get", { index: "default", key: "user:123" })
```
