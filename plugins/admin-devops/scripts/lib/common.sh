#!/usr/bin/env bash
# Shared helpers for admin-devops scripts (QA #1, #10).
set -euo pipefail

new_op_id() { date +%s%N; }

emit_json_log() {
  local component="$1" action="$2" target="$3" status="$4" latency_ms="$5" error_code="${6:-}"
  local op_id="${OP_ID:-$(new_op_id)}"
  printf '{"timestamp":"%s","op_id":"%s","component":"%s","action":"%s","target":"%s","status":"%s","latency_ms":%s,"error_code":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$op_id" "$component" "$action" "$target" "$status" "$latency_ms" "$error_code"
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}
