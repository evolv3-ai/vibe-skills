# /command-name

## Prechecks
- Validate profile and prerequisites (`profile-preflight.sh --json`).
- Verify required CLIs are reachable.

## Plan
- Show intended changes and impacted artifacts.
- Surface op_id and correlation_id for tracing.

## Execution
- Apply mutations via shared script entrypoints only — no inline state writes.
- Use `transactional-write.sh` for any file mutation.
- Wrap external calls with `lib/retry-lib.sh` for resilience.

## Post-steps
- Print the next-best-action and verification command.
- Emit a structured log event via `lib/common.sh:emit_json_log`.
