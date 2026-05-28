#!/usr/bin/env bash
# Resilience defaults (QA #5): bounded jittered retries, non-retryable
# classification, and a file-based circuit breaker with cooldown.
set -euo pipefail

retry_with_backoff() {
  local max="${MAX_RETRIES:-3}"
  local base_ms="${BASE_BACKOFF_MS:-300}"
  local max_ms="${MAX_BACKOFF_MS:-30000}"
  local non_retryable="${NON_RETRYABLE_CODES:-PROFILE_INVALID PROFILE_MISSING PROVIDER_AUTH_FAILED POLICY_DENIED}"
  local breaker="${CIRCUIT_BREAKER_FILE:-/tmp/admin-devops-cb}"
  local cooldown="${CIRCUIT_BREAKER_COOLDOWN_S:-60}"

  if [[ -f "$breaker" ]]; then
    local opened now
    opened=$(cat "$breaker")
    now=$(date +%s)
    if (( now - opened < cooldown )); then
      echo "{\"error_code\":\"CIRCUIT_OPEN\",\"cooldown_remaining_s\":$((cooldown - now + opened))}" >&2
      return 7
    fi
    rm -f "$breaker"
  fi

  local attempt=0 out rc
  while (( attempt < max )); do
    attempt=$((attempt + 1))
    out=$("$@" 2>&1) && rc=0 || rc=$?
    if (( rc == 0 )); then printf '%s\n' "$out"; return 0; fi
    for code in $non_retryable; do
      if [[ "$out" == *"$code"* ]]; then
        printf '%s\n' "$out" >&2
        echo "{\"error_code\":\"NON_RETRYABLE\",\"matched\":\"$code\"}" >&2
        return "$rc"
      fi
    done
    local backoff=$(( base_ms * (2 ** (attempt - 1)) ))
    (( backoff > max_ms )) && backoff=$max_ms
    local jitter=$(( RANDOM % (backoff / 2 + 1) ))
    local sleep_ms=$(( backoff + jitter ))
    awk -v ms="$sleep_ms" 'BEGIN{ system("sleep " ms/1000) }' >/dev/null 2>&1
  done
  date +%s > "$breaker"
  echo "{\"error_code\":\"PROVIDER_RETRY_EXHAUSTED\",\"retries\":$attempt,\"circuit\":\"opened\"}" >&2
  return 5
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  retry_with_backoff "$@"
fi
