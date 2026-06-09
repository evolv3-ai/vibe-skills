#!/usr/bin/env bash
# Shared provider orchestration dispatcher (QA #6).
# Usage: provider-core.sh <adapter-script> <action> [args...]
set -euo pipefail
adapter="${1:?adapter script required}"
action="${2:?action required}"
shift 2 || true
case "$action" in
  discover_capabilities|validate_prereqs|provision|teardown|health_check)
    "$adapter" "$action" "$@"
    ;;
  *)
    echo "{\"error_code\":\"UNKNOWN_ACTION\",\"action\":\"$action\"}" >&2
    exit 1
    ;;
esac
