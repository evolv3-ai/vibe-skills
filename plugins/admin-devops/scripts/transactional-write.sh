#!/usr/bin/env bash
# Idempotent transactional write (QA #4): temp -> validate -> atomic replace -> log.
# Usage: transactional-write.sh <target> <source> [--json|--text]
set -euo pipefail
target="${1:?target required}"
src="${2:?source content file required}"
mode="${3:---text}"
op_id="${OP_ID:-$(date +%s%N)}"

[[ -f "$src" ]] || { echo "{\"error_code\":\"SOURCE_MISSING\",\"src\":\"$src\"}" >&2; exit 4; }
tmp="${target}.tmp.$op_id"
cp "$src" "$tmp"

if [[ "$mode" == "--json" ]]; then
  if ! python3 -m json.tool "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "{\"error_code\":\"TRANSITION_INVALID\",\"reason\":\"payload is not valid JSON\"}" >&2
    exit 4
  fi
fi

mkdir -p "$(dirname "$target")"
mv "$tmp" "$target"
printf '{"ok":true,"op_id":"%s","target":"%s","mode":"%s"}\n' "$op_id" "$target" "$mode"
