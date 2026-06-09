# Module Ownership Map

Per QA #8 — maps each script group to its responsibility, inputs, and outputs.

| Module | Responsibility | Inputs | Outputs |
|---|---|---|---|
| `contracts/*` | Source-of-truth schemas and payloads | JSON schemas/specs | Validated contract artifacts |
| `schemas/*` | Profile and incident schemas | JSON Schema docs | Used by validators |
| `policies/*` | Policy-as-code for secrets/trust | JSON policy docs | Read by `resolve-secret.sh` |
| `scripts/lib/common.sh` | Shared logging + op IDs | stdin/args | JSON log events |
| `scripts/lib/error-format.sh` | Normalize errors + remediation | code/msg/raw | Human stderr + JSON stdout |
| `scripts/lib/retry-lib.sh` | Resilience: retries + breaker | command + env knobs | Output of inner cmd or error JSON |
| `scripts/profile-preflight.{sh,ps1}` | Profile gate | profile path | pass/fail JSON |
| `scripts/resolve-secret.sh` | Secret state machine | key + env vars | source/reason JSON (redacted) |
| `scripts/transactional-write.sh` | Atomic write w/ validation | target + src | mv-replaced target |
| `scripts/render-sync.sh` | Incremental, hash-based render | inputs dir | generated index + manifest |
| `scripts/provider-core.sh` | Orchestration dispatcher | adapter + action | Adapter output |
| `scripts/doctor.{sh,ps1}` | Readiness score | filesystem + env | readiness JSON |
| `scripts/static-qa-gates.sh` | Release gate runner | n/a | per-gate pass/fail |
| `scripts/smoke-test.sh` | End-to-end wiring check | n/a | exit code + JSON |
