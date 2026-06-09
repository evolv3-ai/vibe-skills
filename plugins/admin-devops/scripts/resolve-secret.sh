#!/usr/bin/env bash
# Centralized secret resolution state machine (QA #9).
# States: generated -> infisical -> vault -> env -> fail
# Outputs JSON metadata only — never prints secret values.
set -euo pipefail
key="${1:?secret key required}"
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy_file="${SECRETS_POLICY:-$BASE/policies/secrets-policy.json}"
consumer="${SECRETS_CONSUMER:-default}"

allow_list="generated infisical vault env"
require_primary="false"
primary="${PRIMARY_BACKEND:-generated}"

if [[ -f "$policy_file" ]] && command -v jq >/dev/null 2>&1; then
  rp=$(jq -r '.require_primary_backend // false' "$policy_file" 2>/dev/null || echo "false")
  [[ -n "$rp" ]] && require_primary="$rp"
  parsed=$(jq -r --arg c "$consumer" '(.consumer_rules[$c].allow // .consumers[$c].allow // []) | join(" ")' "$policy_file" 2>/dev/null || echo "")
  [[ -n "$parsed" ]] && allow_list="$parsed"
fi

selected="fail"
reason="MISSING"
for s in generated infisical vault env; do
  case " $allow_list " in *" $s "*) ;; *) continue ;; esac
  if [[ "$require_primary" == "true" && "$s" != "$primary" ]]; then continue; fi
  case "$s" in
    generated) var_name="GENERATED_$key" ;;
    infisical) var_name="INFISICAL_$key" ;;
    vault)     var_name="VAULT_$key" ;;
    env)       var_name="$key" ;;
  esac
  val="${!var_name:-}"
  if [[ -n "$val" ]]; then
    selected="$s"
    reason="SUCCESS"
    break
  fi
  reason="NOT_CONFIGURED"
done

if [[ "$selected" == "fail" ]]; then
  printf '{"key":"%s","state":"fail","reason_code":"SECRET_UNRESOLVED"}\n' "$key"
  exit 6
fi
printf '{"key":"%s","state":"%s","reason_code":"%s","redacted":"***"}\n' "$key" "$selected" "$reason"
