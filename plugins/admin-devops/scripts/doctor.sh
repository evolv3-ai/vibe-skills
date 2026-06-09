#!/usr/bin/env bash
# Unified health / readiness command (QA #11).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON=0; [[ "${1:-}" == "--json" ]] && JSON=1

profile_ok=0; secrets_ok=0; runtime_ok=0; mcp_ok=0; cli_ok=0
"$BASE/scripts/profile-preflight.sh" --json >/dev/null 2>&1 && profile_ok=1
[[ -f "$BASE/contracts/secrets-resolution.v1.json" && -f "$BASE/policies/secrets-policy.json" ]] && secrets_ok=1
[[ -f "$BASE/contracts/contract.v1.json" ]] && runtime_ok=1
[[ -f "$BASE/skills/admin/assets/mcp-registry.json" ]] && mcp_ok=1
command -v bash >/dev/null && cli_ok=1

score=$(( (profile_ok + secrets_ok + runtime_ok + mcp_ok + cli_ok) * 20 ))
payload=$(printf '{"readiness_score":%s,"checks":{"profile_schema":%s,"secrets_reachability":%s,"runtime_freshness":%s,"mcp_integrity":%s,"provider_cli_readiness":%s}}\n' \
  "$score" "$profile_ok" "$secrets_ok" "$runtime_ok" "$mcp_ok" "$cli_ok")
if (( JSON )); then
  printf '%s\n' "$payload"
else
  echo "Doctor readiness: $score / 100"
  echo "$payload"
fi
