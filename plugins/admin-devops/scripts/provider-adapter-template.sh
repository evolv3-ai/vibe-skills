#!/usr/bin/env bash
# Provider adapter template (QA #6). Copy and replace echoes with provider calls.
set -euo pipefail
action="${1:-health_check}"
case "$action" in
  discover_capabilities) echo '{"capabilities":["compute","networking"]}' ;;
  validate_prereqs)      echo '{"ok":true}' ;;
  provision)             echo '{"state":"provisioning"}' ;;
  teardown)              echo '{"state":"decommissioned"}' ;;
  health_check)          echo '{"status":"ok"}' ;;
  *)                     echo "{\"error_code\":\"UNKNOWN_ACTION\",\"action\":\"$action\"}" >&2; exit 1 ;;
esac
