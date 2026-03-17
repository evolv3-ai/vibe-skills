#!/usr/bin/env bash
# =============================================================================
# Library Post-Use Hook - Write profile bindings after /library use
# =============================================================================
# Called by The Library after `/library use` completes. Writes the component
# binding into the device profile. The Library stays generic — this hook is
# the integration point owned by admin-devops.
#
# Usage (called by Library, not directly):
#   library-post-use-hook.sh ENTRY_NAME ENTRY_TYPE [LIBRARY_JSON_PATH]
#
# Example:
#   library-post-use-hook.sh simplemem mcp ~/.claude/skills/library/library.json
# =============================================================================

set -euo pipefail

ENTRY_NAME="${1:-}"
ENTRY_TYPE="${2:-}"
LIBRARY_JSON="${3:-${HOME}/.claude/skills/library/library.json}"

if [[ -z "$ENTRY_NAME" || -z "$ENTRY_TYPE" ]]; then
    echo "Usage: library-post-use-hook.sh ENTRY_NAME ENTRY_TYPE [LIBRARY_JSON_PATH]" >&2
    exit 1
fi

SATELLITE_ENV="${HOME}/.admin/.env"
resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then echo "$ADMIN_ROOT"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local root; root=$(grep "^ADMIN_ROOT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}
resolve_device_name() {
    if [[ -n "${ADMIN_DEVICE:-}" ]]; then echo "$ADMIN_DEVICE"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local dev; dev=$(grep "^ADMIN_DEVICE=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$dev" ]]; then echo "$dev"; return; fi
    fi
    hostname
}

ADMIN_ROOT="$(resolve_admin_root)"
DEVICE_NAME="$(resolve_device_name)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_PATH="${ADMIN_ROOT}/profiles/${DEVICE_NAME}.json"

if ! command -v jq &>/dev/null; then echo "Error: jq required" >&2; exit 1; fi
if [[ ! -f "$PROFILE_PATH" ]]; then echo "Error: Profile not found: $PROFILE_PATH" >&2; exit 1; fi
if [[ ! -f "$LIBRARY_JSON" ]]; then echo "Error: library.json not found: $LIBRARY_JSON" >&2; exit 1; fi

# Map entry type to library section name
case "$ENTRY_TYPE" in
    skill) SECTION="skills" ;;
    agent) SECTION="agents" ;;
    prompt) SECTION="prompts" ;;
    mcp) SECTION="mcp" ;;
    *) echo "Error: Unknown type: $ENTRY_TYPE" >&2; exit 1 ;;
esac

# Check if binding already exists
existing=$(jq -r ".bindings.${ENTRY_TYPE}[\"${ENTRY_NAME}\"] // empty" "$PROFILE_PATH" 2>/dev/null)
if [[ -n "$existing" && "$existing" != "null" ]]; then
    echo "Binding already exists for ${ENTRY_TYPE}:${ENTRY_NAME} (updating lastSyncedAt)"
    jq --arg type "$ENTRY_TYPE" --arg name "$ENTRY_NAME" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.bindings[$type][$name].lastSyncedAt = $ts' \
        "$PROFILE_PATH" > "${PROFILE_PATH}.tmp" && mv "${PROFILE_PATH}.tmp" "$PROFILE_PATH"
    exit 0
fi

# Find the entry in library.json
entry=$(jq ".library.${SECTION}[] | select(.name == \"${ENTRY_NAME}\")" "$LIBRARY_JSON" 2>/dev/null)
if [[ -z "$entry" || "$entry" == "null" ]]; then
    echo "Warning: ${ENTRY_NAME} not found in library.json section ${SECTION}" >&2
    # Still create a minimal binding
    entry="{}"
fi

# Extract install policy
install_policy=$(echo "$entry" | jq -r '.installPolicy // "library"')

# Build the binding object
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
binding=$(jq -n --arg status "pending" --arg at "$TIMESTAMP" --arg policy "$install_policy" \
    '{"status": $status, "installedAt": $at, "lastSyncedAt": $at, "installPolicy": $policy}')

# Add secretRefs from requiredSecrets defaults
secret_refs=$(echo "$entry" | jq '
    (.requiredSecrets // {}) | to_entries |
    map({key: .key, value: (.value.defaultUri // "")}) |
    from_entries |
    if . == {} then null else . end
' 2>/dev/null)

if [[ -n "$secret_refs" && "$secret_refs" != "null" ]]; then
    binding=$(echo "$binding" | jq --argjson refs "$secret_refs" '. + {"secretRefs": $refs}')
fi

# Add static env vars
env_vars=$(echo "$entry" | jq '.env // null' 2>/dev/null)
if [[ -n "$env_vars" && "$env_vars" != "null" && "$env_vars" != "{}" ]]; then
    binding=$(echo "$binding" | jq --argjson env "$env_vars" '. + {"env": $env}')
fi

# Ensure bindings.{type} exists in profile
jq --arg type "$ENTRY_TYPE" '
    if .bindings == null then .bindings = {} else . end |
    if .bindings[$type] == null then .bindings[$type] = {} else . end
' "$PROFILE_PATH" > "${PROFILE_PATH}.tmp" && mv "${PROFILE_PATH}.tmp" "$PROFILE_PATH"

# Write the binding
jq --arg type "$ENTRY_TYPE" --arg name "$ENTRY_NAME" --argjson binding "$binding" \
    '.bindings[$type][$name] = $binding' \
    "$PROFILE_PATH" > "${PROFILE_PATH}.tmp" && mv "${PROFILE_PATH}.tmp" "$PROFILE_PATH"

echo "Binding created: ${ENTRY_TYPE}:${ENTRY_NAME} (status: pending, policy: $install_policy)"

# For MCP entries, suggest rendering
if [[ "$ENTRY_TYPE" == "mcp" ]]; then
    echo "Run render-mcp-config.sh to activate this MCP server"
fi
