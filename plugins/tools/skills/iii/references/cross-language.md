# iii Cross-Language Reference

> Cross-language calls, state management, streams, OpenTelemetry, environment variables, and upcoming SDK translation guide.

## Table of Contents

- [Cross-Language Calls](#cross-language-calls)
- [State Management](#state-management)
- [Streams](#streams)
- [OpenTelemetry Integration](#opentelemetry-integration)
- [Environment Variables](#environment-variables)
- [Ports](#ports)
- [Upcoming SDK (`@iii-dev/sdk`)](#upcoming-sdk-iii-devsdk)

---

## Cross-Language Calls

Functions registered in any language are callable from any other language.

### TypeScript calls Python

```typescript
// TypeScript service
const result = await call("data-service::transform", { data: myData });
```

### Python service

```python
from iii import III, InitOptions, get_context

iii = III("ws://localhost:49134", InitOptions(worker_name="data-service"))

async def transform_handler(payload: dict) -> dict:
    ctx = get_context()
    ctx.logger.info("Processing...")
    return {"transformed": payload, "source": "data-service"}

iii.register_function("data-service::transform", transform_handler)

async def main():
    await iii.connect()
    await asyncio.Future()  # Keep running
```

### Rust service

```rust
use iii_sdk::{III, Value};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let url = std::env::var("III_BRIDGE_URL")
        .unwrap_or_else(|_| "ws://localhost:49134".into());
    let iii = III::new(&url);
    iii.connect().await?;

    iii.register_function("compute-service::compute", |input: Value| async move {
        let n = input.get("n").and_then(|v| v.as_u64()).unwrap_or(10);
        Ok(serde_json::json!({ "result": n * 2, "source": "compute-service" }))
    });

    tokio::signal::ctrl_c().await?;
    Ok(())
}
```

---

## State Management

Shared key-value state accessible across all connected services.

### Via `call()` (recommended for most cases)

```typescript
// Set
await call("state::set", { scope: "shared", key: "VERSION", value: 1 });

// Get
const val = await call("state::get", { scope: "shared", key: "VERSION" });

// Works from any language - Python example:
result = await iii.call("state::get", {"scope": "shared", "key": "VERSION"})
```

### Via Direct State API (advanced)

See `references/api-reference.md` for the full `IState` interface with `get`, `set`, `delete`, `list`, and `update` operations including atomic update ops (`set`, `increment`, `decrement`, `remove`, `merge`).

---

## Streams

Real-time durable streams organized by stream name, group, and item. See `references/api-reference.md` for the full `IStream` interface.

### Stream Triggers

The Stream module adds `streams:join` and `streams:leave` trigger types, fired when clients connect/disconnect from stream subscriptions.

```typescript
registerFunction({ id: "presence::on-join" }, async (event) => {
  // event: { subscription_id, stream_name, group_id, id, context }
  const { logger } = getContext();
  logger.info("User joined stream", { stream: event.stream_name, group: event.group_id });
});

registerTrigger({
  trigger_type: "streams:join",
  function_id: "presence::on-join",
  config: {},  // No config needed
});

registerTrigger({
  trigger_type: "streams:leave",
  function_id: "presence::on-leave",
  config: {},
});
```

### Stream Adapters

**KvStore** (file-based, no external deps -- good for development):
```yaml
adapter:
  class: modules::stream::adapters::KvStore
  config:
    store_method: file_based
    file_path: ./data/streams_store
```

**Redis** (production, supports multi-instance via pub/sub):
```yaml
adapter:
  class: modules::streams::adapters::RedisAdapter
  config:
    redis_url: ${REDIS_URL:redis://localhost:6379}
```

---

## OpenTelemetry Integration

```typescript
import { initOtel, withSpan, getTracer, getMeter } from "iii-sdk/telemetry";

// Initialize (usually called once at startup)
initOtel({
  serviceName: "my-service",
  metricsEnabled: true,
});

// Create traced spans
const result = await withSpan("process-order", { kind: SpanKind.INTERNAL }, async (span) => {
  span.setAttribute("order.id", orderId);
  return await processOrder(orderId);
});

// Custom metrics
const meter = getMeter();
if (meter) {
  const counter = meter.createCounter("orders_processed");
  counter.add(1, { status: "success" });
}
```

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `III_BRIDGE_URL` | `ws://localhost:49134` | Engine WebSocket address |
| `OTEL_ENABLED` | `true` | Enable OpenTelemetry |
| `OTEL_SERVICE_NAME` | `iii-node` | Service name for telemetry |
| `SERVICE_VERSION` | `unknown` | Service version |
| `OTEL_METRICS_ENABLED` | - | Enable metrics export |
| `OTEL_EXPORTER_TYPE` | `memory` | Exporter type (`memory` or `otlp`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | OTLP endpoint |

---

## Ports

| Port | Service | Module |
|------|---------|--------|
| 3111 | REST API | `RestApiModule` |
| 49134 | WebSocket (worker connections) | Engine core |
| 3112 | Streams WebSocket | `StreamModule` |
| 9464 | Prometheus metrics | `OtelModule` |

---

## Upcoming SDK (`@iii-dev/sdk`)

The iii.dev docs reference `@iii-dev/sdk` with a `Bridge` class API. As of 2026-02-17, this package does **not exist on npm** (404). It likely represents a future SDK release.

### Key Differences from `iii-sdk@0.2.0`

| Aspect | `iii-sdk@0.2.0` (use this) | `@iii-dev/sdk` (docs only) |
|--------|----------------------------|---------------------------|
| Install | `npm install iii-sdk` | N/A -- npm 404 |
| Entry point | `init(address)` -> `ISdk` | `new Bridge(url)` |
| Function field | `id: "svc::fn"` | `function_path: "svc.fn"` |
| Trigger field | `type: "http"` (0.2.0) / `trigger_type: "api"` (0.3.0-alpha) | `trigger_type: "api"` |
| Invoke | `call()` / `callVoid()` | `invokeFunction()` / `invokeFunctionAsync()` |
| Separator | `::` (double colon) | `.` (dot) |

### Translating Docs Examples

When reading iii.dev docs code samples, translate to `iii-sdk@0.2.0`:

```typescript
// DOCS example (won't work -- @iii-dev/sdk not on npm):
// bridge.registerFunction({ function_path: "users.create", handler: fn })
// bridge.registerTrigger({ trigger_type: "api", function_path: "users.create", config: { ... } })

// CORRECT translation for iii-sdk@0.3.0-alpha:
registerFunction({ id: "users::create" }, fn);
registerTrigger({ trigger_type: "api", function_id: "users::create", config: { api_path: "users", http_method: "POST" } });
```

See `references/api-reference.md` for the full `@iii-dev/sdk` type sketch and more translation examples.
