#!/usr/bin/env bash
# Normalized error formatter (QA #3): writes human stderr + JSON stdout.
set -euo pipefail
code="${1:-UNKNOWN}"
msg="${2:-Unexpected error}"
remediation="${3:-Check logs and retry.}"
raw="${4:-}"
printf 'ERROR [%s] %s\nRemediation: %s\n' "$code" "$msg" "$remediation" >&2
[[ -n "$raw" ]] && printf 'Raw: %s\n' "$raw" >&2
if [[ -n "$raw" ]]; then
  printf '{"error_code":"%s","message":"%s","remediation":"%s","provider_raw_error":"%s"}\n' "$code" "$msg" "$remediation" "$raw"
else
  printf '{"error_code":"%s","message":"%s","remediation":"%s"}\n' "$code" "$msg" "$remediation"
fi
