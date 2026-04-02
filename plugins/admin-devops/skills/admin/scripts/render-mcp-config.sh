#!/usr/bin/env bash
# =============================================================================
# Render MCP Config - Generate MCP client configs from Library + Profile
# =============================================================================
# Reads library.json MCP entries + profile bindings, resolves secrets,
# writes to ~/.claude/.mcp.json (Claude Code CLI).
#
# Usage:
#   render-mcp-config.sh                    # Render all eligible MCP configs
#   render-mcp-config.sh --dry-run          # Show what would be written
#   render-mcp-config.sh --skip-unresolvable # Write configs even if secrets fail
#   render-mcp-config.sh --post-verify      # Run diagnose-mcp.sh after render
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[i]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

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
LIBRARY_JSON="${LIBRARY_JSON_PATH:-${HOME}/.claude/skills/library/library.json}"
MCP_CONFIG="${HOME}/.claude/.mcp.json"

DRY_RUN=false
SKIP_UNRESOLVABLE=false
POST_VERIFY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --skip-unresolvable) SKIP_UNRESOLVABLE=true; shift ;;
        --post-verify) POST_VERIFY=true; shift ;;
        -h|--help)
            echo "Usage: render-mcp-config.sh [--dry-run] [--skip-unresolvable] [--post-verify]"
            exit 0 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$LIBRARY_JSON" ]]; then err "library.json not found at $LIBRARY_JSON"; exit 1; fi
if [[ ! -f "$PROFILE_PATH" ]]; then err "Profile not found: $PROFILE_PATH"; exit 1; fi

section "Render MCP Config"
info "Library: $LIBRARY_JSON"
info "Profile: $PROFILE_PATH"
info "Target:  $MCP_CONFIG"

# Read consumer type from profile
CONSUMER_TYPE=$(jq -r '.consumer.type // "workstation"' "$PROFILE_PATH")
TRUST_BOUNDARY=$(jq -r '.consumer.trustBoundary // "operator"' "$PROFILE_PATH")
info "Consumer: $CONSUMER_TYPE (trust: $TRUST_BOUNDARY)"

# Trust boundary hierarchy: operator > runtime > customer
trust_level() {
    case "$1" in
        operator) echo 3 ;; runtime) echo 2 ;; customer) echo 1 ;; *) echo 0 ;;
    esac
}

DEVICE_TRUST=$(trust_level "$TRUST_BOUNDARY")

# Read existing MCP config (preserve non-library entries)
existing_servers="{}"
if [[ -f "$MCP_CONFIG" ]]; then
    existing_servers=$(jq '.mcpServers // {}' "$MCP_CONFIG" 2>/dev/null || echo "{}")
fi

# Track which servers we manage (for merge logic)
library_managed=()
configured=0
skipped=0
pending=0

# Build new server configs
new_servers="$existing_servers"

# Process each MCP entry from library
mcp_count=$(jq '.library.mcp | length' "$LIBRARY_JSON")
for ((i = 0; i < mcp_count; i++)); do
    name=$(jq -r ".library.mcp[$i].name" "$LIBRARY_JSON")
    entry_targets=$(jq -r ".library.mcp[$i].targets | join(\",\")" "$LIBRARY_JSON")
    entry_trust=$(jq -r ".library.mcp[$i].trustBoundary // \"operator\"" "$LIBRARY_JSON")
    entry_policy=$(jq -r ".library.mcp[$i].installPolicy // \"library\"" "$LIBRARY_JSON")
    entry_type=$(jq -r ".library.mcp[$i].type // \"stdio\"" "$LIBRARY_JSON")

    echo -n "  $name... "

    # Skip manual entries
    if [[ "$entry_policy" == "manual" ]]; then
        echo "SKIP (manual)"
        skipped=$((skipped + 1)); continue
    fi

    # Check target eligibility
    if [[ ! ",$entry_targets," == *",$CONSUMER_TYPE,"* ]]; then
        echo "SKIP (target: $entry_targets, consumer: $CONSUMER_TYPE)"
        skipped=$((skipped + 1)); continue
    fi

    # Check trust boundary
    ENTRY_TRUST=$(trust_level "$entry_trust")
    if [[ "$DEVICE_TRUST" -lt "$ENTRY_TRUST" ]]; then
        echo "SKIP (trust: needs $entry_trust, have $TRUST_BOUNDARY)"
        skipped=$((skipped + 1)); continue
    fi

    # Check binding status in profile
    binding_status=$(jq -r ".bindings.mcp[\"$name\"].status // \"none\"" "$PROFILE_PATH" 2>/dev/null)
    if [[ "$binding_status" == "disabled" ]]; then
        echo "SKIP (disabled in profile)"
        skipped=$((skipped + 1)); continue
    fi

    library_managed+=("$name")

    # Resolve secrets
    secret_keys=$(jq -r ".library.mcp[$i].requiredSecrets // {} | keys[]" "$LIBRARY_JSON" 2>/dev/null || true)
    resolved_env="{}"
    all_resolved=true

    for secret_key in $secret_keys; do
        # Check profile binding override first, then library default
        secret_uri=$(jq -r ".bindings.mcp[\"$name\"].secretRefs[\"$secret_key\"] // empty" "$PROFILE_PATH" 2>/dev/null)
        if [[ -z "$secret_uri" ]]; then
            secret_uri=$(jq -r ".library.mcp[$i].requiredSecrets[\"$secret_key\"].defaultUri // empty" "$LIBRARY_JSON")
        fi

        if [[ -n "$secret_uri" ]]; then
            secret_value=$("$SCRIPT_DIR/resolve-secret-ref.sh" --quiet "$secret_uri" 2>/dev/null || true)
            if [[ -n "$secret_value" ]]; then
                resolved_env=$(echo "$resolved_env" | jq --arg k "$secret_key" --arg v "$secret_value" '. + {($k): $v}')
            else
                all_resolved=false
                if [[ "$SKIP_UNRESOLVABLE" != "true" ]]; then
                    echo "FAILED (secret: $secret_key)"
                    skipped=$((skipped + 1)); continue 2
                fi
            fi
        fi
    done

    # Add static env vars from library entry
    static_env=$(jq ".library.mcp[$i].env // {}" "$LIBRARY_JSON")
    # Add static env from profile binding
    binding_env=$(jq ".bindings.mcp[\"$name\"].env // {}" "$PROFILE_PATH" 2>/dev/null || echo "{}")
    merged_env=$(echo "$static_env $binding_env $resolved_env" | jq -s '.[0] + .[1] + .[2]')

    # Build server config based on transport type
    server_config=""
    case "$entry_type" in
        stdio)
            cmd=$(jq -r ".library.mcp[$i].command" "$LIBRARY_JSON")
            args=$(jq ".library.mcp[$i].args // []" "$LIBRARY_JSON")
            server_config=$(jq -n --arg cmd "$cmd" --argjson args "$args" --argjson env "$merged_env" \
                '{"command": $cmd, "args": $args, "env": $env}')
            ;;
        streamable-http|sse)
            url=$(jq -r ".library.mcp[$i].url" "$LIBRARY_JSON")
            # Build headers with resolved secrets
            headers="{}"
            header_format=$(jq -r ".library.mcp[$i].requiredSecrets // {} | to_entries[] | select(.value.headerFormat != null) | \"\(.key)=\(.value.headerFormat)\"" "$LIBRARY_JSON" 2>/dev/null || true)
            if [[ -n "$header_format" ]]; then
                while IFS='=' read -r hkey hformat; do
                    [[ -z "$hkey" ]] && continue
                    secret_val=$(echo "$resolved_env" | jq -r ".[\"$hkey\"] // empty")
                    if [[ -n "$secret_val" ]]; then
                        header_val="${hformat/\{value\}/$secret_val}"
                        headers=$(echo "$headers" | jq --arg k "Authorization" --arg v "$header_val" '. + {($k): $v}')
                    fi
                done <<< "$header_format"
            fi
            server_config=$(jq -n --arg url "$url" --argjson headers "$headers" \
                '{"url": $url, "headers": $headers}')
            ;;
    esac

    if [[ -n "$server_config" ]]; then
        new_servers=$(echo "$new_servers" | jq --arg name "$name" --argjson config "$server_config" '. + {($name): $config}')
        if [[ "$all_resolved" == "true" ]]; then
            echo "OK"
            configured=$((configured + 1))
        else
            echo "PENDING (some secrets unresolved)"
            pending=$((pending + 1))
        fi
    fi
done

# Write config
if [[ "$DRY_RUN" == "true" ]]; then
    section "Dry Run Output"
    echo "$new_servers" | jq '{mcpServers: .}'
else
    # Backup existing
    if [[ -f "$MCP_CONFIG" ]]; then
        cp "$MCP_CONFIG" "${MCP_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Write — use jq for safe JSON construction (avoids shell word-splitting on $new_servers)
    echo "$new_servers" | jq '{mcpServers: .}' > "$MCP_CONFIG"
    chmod 600 "$MCP_CONFIG"
    ok "Written: $MCP_CONFIG"
fi

section "Summary"
echo "Configured: $configured"
echo "Pending:    $pending"
echo "Skipped:    $skipped"

# Post-verify
if [[ "$POST_VERIFY" == "true" && -f "$SCRIPT_DIR/diagnose-mcp.sh" ]]; then
    "$SCRIPT_DIR/diagnose-mcp.sh"
fi
