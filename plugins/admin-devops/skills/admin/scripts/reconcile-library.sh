#!/usr/bin/env bash
# =============================================================================
# Reconcile Library - Compare catalog against device profile bindings
# =============================================================================
# Reads library.json catalog + profile bindings to determine what this device
# should have, what it has, and what it's not eligible for.
#
# Usage:
#   reconcile-library.sh               # Human-readable table (stderr)
#   reconcile-library.sh --json        # Machine-readable JSON (stdout)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[i]${NC} $1" >&2; }
ok() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
err() { echo -e "${RED}[-]${NC} $1" >&2; }

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
PROFILE_PATH="${ADMIN_ROOT}/profiles/${DEVICE_NAME}.json"
LIBRARY_JSON="${LIBRARY_JSON_PATH:-${HOME}/.claude/skills/library/library.json}"
PLUGINS_JSON="${HOME}/.claude/plugins/installed_plugins.json"

OUTPUT_JSON=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) OUTPUT_JSON=true; shift ;;
        -h|--help) echo "Usage: reconcile-library.sh [--json]" >&2; exit 0 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$LIBRARY_JSON" ]]; then err "library.json not found: $LIBRARY_JSON"; exit 1; fi
if [[ ! -f "$PROFILE_PATH" ]]; then err "Profile not found: $PROFILE_PATH"; exit 1; fi

# Read profile consumer info
CONSUMER_TYPE=$(jq -r '.consumer.type // "workstation"' "$PROFILE_PATH")
TRUST_BOUNDARY=$(jq -r '.consumer.trustBoundary // "operator"' "$PROFILE_PATH")

trust_level() {
    case "$1" in
        operator) echo 3 ;; runtime) echo 2 ;; customer) echo 1 ;; *) echo 0 ;;
    esac
}
DEVICE_TRUST=$(trust_level "$TRUST_BOUNDARY")

info "Device: $DEVICE_NAME ($CONSUMER_TYPE, trust: $TRUST_BOUNDARY)"

# Check if a plugin is installed
check_plugin_installed() {
    local name="$1"
    if [[ -f "$PLUGINS_JSON" ]]; then
        # Check if admin-devops plugin is installed (covers all plugin-managed entries)
        jq -e '.plugins["admin-devops@vibe-skills"] | length > 0' "$PLUGINS_JSON" &>/dev/null && return 0
    fi
    return 1
}

# Process all library entries
json_results="[]"
should_install=0
installed=0
not_eligible=0

process_entries() {
    local type_name="$1"  # skills, agents, prompts, mcp
    local bind_type="$2"  # skill, agent, prompt, mcp

    local count
    count=$(jq ".library.${type_name} | length" "$LIBRARY_JSON")

    for ((i = 0; i < count; i++)); do
        local name targets entry_trust policy
        name=$(jq -r ".library.${type_name}[$i].name" "$LIBRARY_JSON")
        targets=$(jq -r ".library.${type_name}[$i].targets | join(\",\")" "$LIBRARY_JSON")
        entry_trust=$(jq -r ".library.${type_name}[$i].trustBoundary // \"operator\"" "$LIBRARY_JSON")
        policy=$(jq -r ".library.${type_name}[$i].installPolicy // \"library\"" "$LIBRARY_JSON")

        local action="should_install"
        local reason=""

        # Check target eligibility
        if [[ ! ",$targets," == *",$CONSUMER_TYPE,"* ]]; then
            action="not_eligible"
            reason="target mismatch (needs: $targets)"
        fi

        # Check trust boundary
        if [[ "$action" != "not_eligible" ]]; then
            local ENTRY_TRUST
            ENTRY_TRUST=$(trust_level "$entry_trust")
            if [[ "$DEVICE_TRUST" -lt "$ENTRY_TRUST" ]]; then
                action="not_eligible"
                reason="trust mismatch (needs: $entry_trust)"
            fi
        fi

        # Check install status
        if [[ "$action" == "should_install" ]]; then
            local binding_status
            binding_status=$(jq -r ".bindings.${bind_type}[\"$name\"].status // \"none\"" "$PROFILE_PATH" 2>/dev/null)

            if [[ "$binding_status" == "active" || "$binding_status" == "pending" ]]; then
                action="installed"
                reason="binding: $binding_status"
            elif [[ "$policy" == "plugin" ]]; then
                if check_plugin_installed "$name"; then
                    action="installed"
                    reason="plugin (no binding yet)"
                fi
            fi
        fi

        # Count
        case "$action" in
            should_install) should_install=$((should_install + 1)) ;;
            installed) installed=$((installed + 1)) ;;
            not_eligible) not_eligible=$((not_eligible + 1)) ;;
        esac

        # Add to JSON results
        json_results=$(echo "$json_results" | jq --arg n "$name" --arg t "$bind_type" \
            --arg a "$action" --arg p "$policy" --arg r "$reason" \
            '. + [{"name": $n, "type": $t, "action": $a, "installPolicy": $p, "reason": $r}]')

        # Human-readable output
        if [[ "$OUTPUT_JSON" != "true" ]]; then
            local icon
            case "$action" in
                installed) icon="${GREEN}+${NC}" ;;
                should_install) icon="${YELLOW}?${NC}" ;;
                not_eligible) icon="${RED}-${NC}" ;;
            esac
            printf "  %b %-25s %-8s %-15s %s\n" "$icon" "$name" "$bind_type" "$action" "$reason" >&2
        fi
    done
}

if [[ "$OUTPUT_JSON" != "true" ]]; then
    echo "" >&2
    printf "  %-27s %-8s %-15s %s\n" "NAME" "TYPE" "STATUS" "REASON" >&2
    printf "  %-27s %-8s %-15s %s\n" "---" "----" "------" "------" >&2
fi

process_entries "skills" "skill"
process_entries "agents" "agent"
process_entries "prompts" "prompt"
process_entries "mcp" "mcp"

if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo "$json_results" | jq .
else
    echo "" >&2
    echo "Installed: $installed  Should install: $should_install  Not eligible: $not_eligible" >&2
fi
