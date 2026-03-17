#!/usr/bin/env bash
# =============================================================================
# Diagnose MCP - Standalone read-only MCP health checker
# =============================================================================
# Reads configured MCP servers from client config files and checks health.
# Does NOT modify any config — purely diagnostic.
#
# Usage:
#   diagnose-mcp.sh                # Check all configured servers
#   diagnose-mcp.sh --server NAME  # Check one server
#   diagnose-mcp.sh --json         # Machine-readable output
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[i]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

MCP_CONFIG="${HOME}/.claude/.mcp.json"
TARGET_SERVER=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --server) TARGET_SERVER="$2"; shift 2 ;;
        --json) OUTPUT_JSON=true; shift ;;
        -h|--help)
            echo "Usage: diagnose-mcp.sh [--server NAME] [--json]"
            exit 0 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi

section "MCP Diagnostics"

# Check config exists
if [[ ! -f "$MCP_CONFIG" ]]; then
    err "MCP config not found: $MCP_CONFIG"
    exit 1
fi

# Validate JSON
if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    err "Invalid JSON in $MCP_CONFIG"
    exit 1
fi
ok "Config JSON valid: $MCP_CONFIG"

# Get server list
servers=$(jq -r '.mcpServers // {} | keys[]' "$MCP_CONFIG" 2>/dev/null)
if [[ -z "$servers" ]]; then
    warn "No MCP servers configured"
    exit 0
fi

json_results="[]"
healthy=0
degraded=0
broken=0

check_server() {
    local name="$1"
    local status="healthy"
    local details=""

    # Determine transport type
    local has_command has_url
    has_command=$(jq -r ".mcpServers[\"$name\"].command // empty" "$MCP_CONFIG")
    has_url=$(jq -r ".mcpServers[\"$name\"].url // empty" "$MCP_CONFIG")

    local transport="unknown"
    if [[ -n "$has_command" ]]; then
        transport="stdio"
    elif [[ -n "$has_url" ]]; then
        transport="http"
    fi

    echo -n "  $name ($transport)... "

    if [[ "$transport" == "stdio" ]]; then
        local cmd="$has_command"
        # Check if command exists
        if [[ "$cmd" == "npx" ]]; then
            if ! command -v npx &>/dev/null; then
                status="broken"; details="npx not found"
            else
                # Check node version
                local node_ver
                node_ver=$(node --version 2>/dev/null | tr -d 'v' || true)
                if [[ -z "$node_ver" ]]; then
                    status="degraded"; details="node not found (npx may fail)"
                fi
            fi
        elif ! command -v "$cmd" &>/dev/null; then
            status="broken"; details="command not found: $cmd"
        fi

        # Check args
        local args
        args=$(jq -r ".mcpServers[\"$name\"].args // [] | join(\" \")" "$MCP_CONFIG")

        # Check env vars are non-empty
        local env_keys
        env_keys=$(jq -r ".mcpServers[\"$name\"].env // {} | to_entries[] | select(.value == \"\") | .key" "$MCP_CONFIG" 2>/dev/null || true)
        if [[ -n "$env_keys" ]]; then
            status="degraded"; details="empty env vars: $env_keys"
        fi

    elif [[ "$transport" == "http" ]]; then
        local url="$has_url"
        # Check URL reachability (5s timeout)
        if command -v curl &>/dev/null; then
            local http_code
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
            if [[ "$http_code" == "000" ]]; then
                status="broken"; details="unreachable (timeout or DNS failure)"
            elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
                # Auth required — check if headers are configured
                local has_auth
                has_auth=$(jq -r ".mcpServers[\"$name\"].headers.Authorization // empty" "$MCP_CONFIG")
                if [[ -z "$has_auth" ]]; then
                    status="broken"; details="auth required but no Authorization header"
                else
                    status="healthy"; details="auth configured (HTTP $http_code expected)"
                fi
            elif [[ "$http_code" =~ ^[23] ]]; then
                status="healthy"; details="HTTP $http_code"
            else
                status="degraded"; details="unexpected HTTP $http_code"
            fi
        else
            status="degraded"; details="curl not available for URL check"
        fi
    else
        status="broken"; details="unknown transport (no command or url)"
    fi

    # Report
    case "$status" in
        healthy) ok "$name: $status${details:+ ($details)}"; healthy=$((healthy + 1)) ;;
        degraded) warn "$name: $status${details:+ ($details)}"; degraded=$((degraded + 1)) ;;
        broken) err "$name: $status${details:+ ($details)}"; broken=$((broken + 1)) ;;
    esac

    json_results=$(echo "$json_results" | jq --arg n "$name" --arg t "$transport" \
        --arg s "$status" --arg d "$details" \
        '. + [{"name": $n, "transport": $t, "status": $s, "details": $d}]')
}

for server in $servers; do
    if [[ -n "$TARGET_SERVER" && "$server" != "$TARGET_SERVER" ]]; then
        continue
    fi
    check_server "$server"
done

if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo "$json_results" | jq .
else
    section "Summary"
    echo "Healthy: $healthy  Degraded: $degraded  Broken: $broken"
fi
