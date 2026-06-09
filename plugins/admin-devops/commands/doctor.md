# /doctor

## Prechecks
- Ensure profile exists and validates against `schemas/profile.schema.json`.
- Verify expected CLIs are reachable (`python3`, `jq`, `bash`).

## Plan
- Run health checks for profile/schema, secrets reachability, runtime freshness, MCP integrity, and provider CLI readiness.
- Emit a readiness score (0–100) plus a machine-readable JSON status.

## Execution
- Bash: `${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh --json`
- PowerShell: `${CLAUDE_PLUGIN_ROOT}/scripts/doctor.ps1 -Json`

## Post-steps
- If `readiness_score < 100`, address failing checks before running mutating commands.
- File an incident via `/troubleshoot new` if a check fails repeatedly (see `schemas/incident.schema.json`).
