# Provider Error Mapping

Map raw provider/API errors into the canonical error codes defined in `contracts/errors.v1.json`. Wrappers should normalize via `scripts/lib/error-format.sh`.

| Raw Error Pattern | Canonical Code | Remediation |
|---|---|---|
| `auth failed` / `unauthorized` / `401` | `PROVIDER_AUTH_FAILED` | Re-authenticate provider CLI and retry |
| `timeout` / `connection reset` / `429` | `PROVIDER_RETRY_EXHAUSTED` | Retry with backoff; check provider status |
| `profile not found` | `PROFILE_MISSING` | Run `/bootstrap` or `/setup-profile` |
| schema/validation failure | `PROFILE_INVALID` | Run `profile-preflight.sh --fix-suggestions` |
| `policy denied` / `forbidden` | `NON_RETRYABLE` | Inspect policy; do not retry |
| dep-graph violation | `DEPENDENCY_GRAPH_INVALID` | Run `validate-dep-graph.sh` |
