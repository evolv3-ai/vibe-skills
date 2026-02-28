# iii Engine Modules Reference

> Comprehensive configuration reference for all iii engine modules.
> Source: iii.dev/docs (scraped 2026-02-17) + iii-sdk@0.2.0 engine (verified)

---

## Module Class Paths

| Module | Class Path (0.2.0 confirmed) | Class Path (docs) | Notes |
|--------|------------------------------|-------------------|-------|
| REST API | `modules::api::RestApiModule` | `modules::api::RestApiModule` | Same |
| State | `modules::state::StateModule` | `modules::state::StateModule` | Same |
| Stream | `modules::stream::StreamModule` | `modules::streams::StreamModule` | Singular vs plural |
| Queue | `modules::queue::QueueModule` | `modules::queue::QueueModule` | Same |
| Cron | `modules::cron::CronModule` | `modules::cron::CronModule` | Same |
| PubSub | `modules::pubsub::PubSubModule` | — | Not in docs |
| OTel | `modules::observability::OtelModule` | — | Tracing + metrics |
| Logging | — | `modules::observability::LoggingModule` | Structured log capture |
| KV Server | — | `modules::kv_server::KvServer` | Persistent KV store |
| Bridge Client | — | `modules::bridge_client::BridgeClientModule` | Engine-to-engine mesh |
| Exec | — | `modules::shell::ExecModule` | Shell command runner |

> If you get `module class not found`, try switching between singular/plural (`stream` vs `streams`) or check engine version.

---

## REST API Module

```yaml
- class: modules::api::RestApiModule
  config:
    host: 127.0.0.1          # Bind address (default: 127.0.0.1)
    port: 3111                # HTTP port (default: 3111)
    default_timeout: 30000    # Request timeout ms
    concurrency_request_limit: 1024
    cors:
      allowed_origins: ["*"]
      allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]
```

Built-in endpoint: `GET /health` returns engine health status.

---

## State Module

```yaml
- class: modules::state::StateModule
  config:
    adapter:
      class: modules::state::adapters::KvStore
      config:
        store_method: file_based    # or: in_memory
        file_path: ./data/state_store.db
```

Functions: `state::get`, `state::set`, `state::delete`, `state::list`, `state::update`
Parameters: `{ scope: string, key: string }` — uses **scope** (not index).

---

## KV Server Module

```yaml
- class: modules::kv_server::KvServer
  config:
    store_method: file_based    # or: in_memory
    file_path: ./data/kv_store  # Directory for file_based storage
    save_interval_ms: 5000      # Auto-save interval (default: 5000)
```

Functions: `kv_server::get`, `kv_server::set`, `kv_server::delete`, `kv_server::list`, `kv_server::list_keys_with_prefix`
Parameters: `{ index: string, key: string }` — uses **index** (not scope).

### KV Server vs State Module

| Aspect | KV Server | State Module |
|--------|-----------|--------------|
| Namespace param | `index` | `scope` |
| Prefix search | `kv_server::list_keys_with_prefix` | N/A |
| Atomic updates | N/A | `state::update` with ops |
| State events | N/A | `state:created`, `state:updated`, `state:deleted` |
| Use case | Simple KV cache, lookups | Complex state with atomic ops and events |

---

## Stream Module

```yaml
# 0.2.0 engine (confirmed working)
- class: modules::stream::StreamModule
  config:
    port: ${STREAMS_PORT:3112}
    host: 127.0.0.1
    auth_function: my-service.streams.authenticate  # Optional
    adapter:
      class: modules::stream::adapters::KvStore
      config:
        store_method: file_based
        file_path: ./data/streams_store
```

### Adapters

**KvStore (file-based, no external deps)**:
```yaml
adapter:
  class: modules::stream::adapters::KvStore   # or modules::streams::adapters::KvStore
  config:
    store_method: file_based   # or: in_memory
    file_path: ./data/streams_store
```

**Redis (production, multi-instance)**:
```yaml
adapter:
  class: modules::streams::adapters::RedisAdapter
  config:
    redis_url: ${REDIS_URL:redis://localhost:6379}
```

### Trigger Types

| Trigger Type | Config | Description |
|-------------|--------|-------------|
| `streams:join` | `{}` | Fires when a client joins a stream subscription |
| `streams:leave` | `{}` | Fires when a client leaves a stream subscription |

Handler receives: `{ subscription_id, stream_name, group_id, id, context }`

---

## Queue Module

```yaml
- class: modules::queue::QueueModule
  config:
    adapter:
      class: modules::queue::BuiltinQueueAdapter
```

Functions: `enqueue` — `{ topic: string, data: any }` returns `null`

### Queue Trigger

```yaml
# Registered via SDK
type: "queue"                  # iii-sdk@0.2.0
function_id: "events::handler" # iii-sdk@0.2.0
config:
  topic: "user.created"        # Topic to subscribe to
```

---

## Cron Module

```yaml
- class: modules::cron::CronModule
  config:
    adapter:
      class: modules::cron::KvCronAdapter   # File-based, no Redis needed
```

For multi-instance deployments, use a Redis-backed adapter to prevent duplicate execution.

Cron expressions: **7 fields** with `iii-sdk@0.2.0` engine (seconds granularity):
`seconds minutes hours day-of-month month day-of-week year`

> Note: The iii.dev docs show 5-field standard cron. With the 0.2.0 engine, always use 7 fields.

---

## Logging Module

```yaml
- class: modules::observability::LoggingModule
  config:
    level: ${RUST_LOG:info}    # trace, debug, info, warn, error
    format: json               # or: default (plain text)
    adapter:
      class: modules::observability::adapters::FileLogger
      config:
        file_path: app.log
        save_interval_ms: 5000
```

### Adapters

**FileLogger**:
```yaml
adapter:
  class: modules::observability::adapters::FileLogger
  config:
    file_path: app.log
    save_interval_ms: 5000     # Flush interval ms
```

**RedisLogger**:
```yaml
adapter:
  class: modules::observability::adapters::RedisLogger
  config:
    redis_url: ${REDIS_URL:redis://localhost:6379}
```

### Log Trigger

Fires when log events match the configured level:

```yaml
# Registered via SDK
type: "log"                          # iii-sdk@0.2.0
function_id: "monitoring::on-error"  # iii-sdk@0.2.0
config:
  level: "error"                     # Optional: info, warn, error, debug (omit for all)
```

Log entry received by handler: `{ trace_id, message, level, function_name, date }`

---

## OTel Module

```yaml
- class: modules::observability::OtelModule
  config:
    enabled: true
    service_name: iii-engine
    exporter: memory           # or: otlp
    sampling_ratio: 1.0
    metrics_enabled: true
    logs_enabled: true
```

Exposes Prometheus metrics on port `9464` at `/metrics`.

> **OtelModule vs LoggingModule**: OtelModule provides OpenTelemetry tracing and metrics export. LoggingModule provides structured log capture with file/Redis backends and the `log` trigger type. They serve different purposes and can be used together.

---

## PubSub Module

```yaml
- class: modules::pubsub::PubSubModule
  config:
    adapter:
      class: modules::pubsub::LocalAdapter     # In-process, single instance
```

For multi-instance, use a Redis-backed adapter.

---

## Bridge Client Module

Connects two iii engine instances over WebSocket for engine-to-engine mesh networking.

```yaml
- class: modules::bridge_client::BridgeClientModule
  config:
    url: ${REMOTE_III_URL:ws://127.0.0.1:49134}
    service_id: bridge-client
    service_name: bridge-client
    expose:                      # Local functions to register on remote
      - local_function: logger::info
        remote_function: engine::log::info
    forward:                     # Remote functions to make locally callable
      - local_function: remote::kv::get
        remote_function: kv_server::get
        timeout_ms: 5000
      - local_function: remote::kv::set
        remote_function: kv_server::set
        timeout_ms: 5000
```

| Config Key | Type | Description |
|-----------|------|-------------|
| `url` | string | WebSocket URL of remote engine |
| `service_id` | string | Service ID to register on remote |
| `service_name` | string | Human-readable name (defaults to service_id) |
| `expose[].local_function` | string | Local function to expose on remote |
| `expose[].remote_function` | string | Name to register on remote (defaults to local) |
| `forward[].local_function` | string | Local alias to create |
| `forward[].remote_function` | string | Remote function to call when alias is invoked |
| `forward[].timeout_ms` | number | Invocation timeout (default: 30000) |

Functions: `bridge::invoke`, `bridge::invoke_async`

---

## Exec Module

Runs shell commands as part of engine startup. Useful for starting worker processes alongside the engine.

```yaml
- class: modules::shell::ExecModule
  config:
    exec:
      - bun run --enable-source-maps index-production.js
```

Multiple commands run sequentially in separate processes. Chain with `&&` for dependent commands:

```yaml
exec:
  - cd path/to/project && npm run build
  - node dist/server.js
```

---

## Ports Reference

| Port | Service | Module |
|------|---------|--------|
| 3111 | REST API | `RestApiModule` |
| 49134 | WebSocket (worker connections) | Engine core |
| 3112 | Streams WebSocket | `StreamModule` (0.2.0 default) |
| 31112 | Streams WebSocket | `StreamModule` (docs default) |
| 9464 | Prometheus metrics | `OtelModule` |
