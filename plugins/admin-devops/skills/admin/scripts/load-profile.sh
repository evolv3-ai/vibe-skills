#!/usr/bin/env bash
# =============================================================================
# Admin Suite Profile Loader - Bash version for WSL/Unix
# =============================================================================
# Usage:
#   source load-profile.sh                    # Load default profile
#   source load-profile.sh vibeskills-oci    # Load profile + deployment
#   load_admin_profile                        # After sourcing, use functions
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolve ADMIN_ROOT from satellite .env or environment
SATELLITE_ENV="${HOME}/.admin/.env"

resolve_admin_root() {
    # Priority 1: Already set in environment
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        echo "$ADMIN_ROOT"; return
    fi

    # Priority 2: Satellite .env (primary mechanism)
    if [[ -f "$SATELLITE_ENV" ]]; then
        local root
        root=$(grep "^ADMIN_ROOT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then
            echo "$root"; return
        fi
    fi

    # Priority 3: Legacy fallback
    echo "${HOME}/.admin"
}

resolve_vault_mode() {
    if [[ -n "${ADMIN_VAULT:-}" ]]; then
        echo "$ADMIN_VAULT"; return
    fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local mode
        mode=$(grep "^ADMIN_VAULT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$mode" ]]; then
            echo "$mode"; return
        fi
    fi
    echo "disabled"
}

resolve_device_name() {
    if [[ -n "${ADMIN_DEVICE:-}" ]]; then
        echo "$ADMIN_DEVICE"; return
    fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local dev
        dev=$(grep "^ADMIN_DEVICE=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$dev" ]]; then
            echo "$dev"; return
        fi
    fi
    hostname
}

# Default paths - resolved from satellite .env
ADMIN_ROOT="$(resolve_admin_root)"
HOSTNAME="$(resolve_device_name)"
DEFAULT_PROFILE="${ADMIN_ROOT}/profiles/${HOSTNAME}.json"

# Global variables
export ADMIN_PROFILE_PATH=""
export ADMIN_PROFILE_JSON=""
export ADMIN_DEVICE_NAME=""
export ADMIN_PLATFORM=""

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show detected environment (useful for debugging)
show_environment() {
    echo ""
    echo -e "${CYAN}=== Environment Detection ===${NC}"
    if [[ -f "$SATELLITE_ENV" ]]; then
        local sat_platform
        sat_platform=$(grep "^ADMIN_PLATFORM=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        echo "Source:      Satellite .env ($SATELLITE_ENV)"
        echo "Platform:    ${sat_platform:-unknown}"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "Source:      Auto-detected (no satellite .env)"
        echo "Platform:    WSL"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "Source:      Auto-detected (no satellite .env)"
        echo "Platform:    macOS"
    else
        echo "Source:      Auto-detected (no satellite .env)"
        echo "Platform:    Native Linux"
    fi
    echo "Device:      $HOSTNAME"
    echo "ADMIN_ROOT:  $ADMIN_ROOT"
    echo "Profile:     $DEFAULT_PROFILE"
    echo "Exists:      $(test -f "$DEFAULT_PROFILE" && echo 'YES' || echo 'NO')"
    echo ""
}

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        log_info "Install with: sudo apt install jq"
        return 1
    fi
}

# --- Vault support ---
resolve_age_key() {
    if [[ -n "${AGE_KEY_PATH:-}" ]]; then
        echo "$AGE_KEY_PATH"; return
    fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local key_path
        key_path=$(grep "^AGE_KEY_PATH=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$key_path" ]]; then
            echo "$key_path"; return
        fi
    fi
    echo "${HOME}/.age/key.txt"
}

AGE_KEY="$(resolve_age_key)"
VAULT_FILE="${ADMIN_ROOT}/vault.age"
ADMIN_VAULT_MODE="$(resolve_vault_mode)"

check_vault_deps() {
    if ! command -v age &> /dev/null; then
        log_warn "age not installed (needed for vault). Install: sudo apt install age"
        return 1
    fi
    if [[ ! -f "$AGE_KEY" ]]; then
        log_warn "Age key not found at $AGE_KEY. Generate: age-keygen -o ~/.age/key.txt"
        return 1
    fi
    if [[ ! -f "$VAULT_FILE" ]]; then
        log_warn "Vault not found at $VAULT_FILE. Run: secrets --encrypt /path/to/.env"
        return 1
    fi
    return 0
}

load_admin_secrets() {
    local export_vars="${1:-true}"

    if [[ "$ADMIN_VAULT_MODE" == "enabled" ]]; then
        if check_vault_deps; then
            log_info "Decrypting vault: $VAULT_FILE"
            local count=0
            local key value
            while IFS= read -r line || [[ -n "$line" ]]; do
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${line// }" ]] && continue
                [[ "$line" != *"="* ]] && continue

                key="${line%%=*}"
                [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

                value="${line#*=}"
                value="${value#\"}"; value="${value%\"}"
                value="${value#\'}"; value="${value%\'}"

                if [[ "$export_vars" == "true" ]]; then
                    export "$key=$value"
                fi
                count=$((count + 1))
            done < <(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null)
            log_ok "Loaded $count secrets from vault"
            return 0
        else
            log_warn "Vault enabled but deps missing - falling back to plaintext .env"
        fi
    fi

    # Fallback: load plaintext .env if it exists
    local master_env="${ADMIN_ROOT}/.env"
    if [[ -f "$master_env" ]]; then
        log_info "Loading secrets from plaintext .env"
        load_env_file "$master_env" "$export_vars"
    fi
}

load_admin_profile() {
    local profile_path="${1:-$DEFAULT_PROFILE}"
    
    check_dependencies || return 1
    
    if [[ ! -f "$profile_path" ]]; then
        log_error "Profile not found: $profile_path"
        log_warn "ADMIN_ROOT is: $ADMIN_ROOT"
        if grep -qi microsoft /proc/version 2>/dev/null; then
            log_warn "Running in WSL - profile should be on Windows side"
            log_warn "Expected: /mnt/c/Users/{WIN_USER}/.admin/profiles/$(hostname).json"
            log_warn "Create profile from Windows: Initialize-AdminProfile.ps1"
        else
            log_warn "Create profile with: Initialize-AdminProfile.ps1 (Windows)"
        fi
        return 1
    fi
    
    log_info "Loading profile: $profile_path"
    
    if ! jq empty "$profile_path" 2>/dev/null; then
        log_error "Invalid JSON in profile"
        return 1
    fi
    
    ADMIN_PROFILE_PATH="$profile_path"
    ADMIN_PROFILE_JSON=$(cat "$profile_path")
    ADMIN_DEVICE_NAME=$(echo "$ADMIN_PROFILE_JSON" | jq -r '.device.name')
    ADMIN_PLATFORM=$(echo "$ADMIN_PROFILE_JSON" | jq -r '.device.platform')
    
    local schema_version=$(echo "$ADMIN_PROFILE_JSON" | jq -r '.schemaVersion')
    if [[ "$schema_version" != "3.0" ]]; then
        log_warn "Profile schema version $schema_version - expected 3.0"
    fi
    
    local tool_count=$(echo "$ADMIN_PROFILE_JSON" | jq '.tools | length')
    local server_count=$(echo "$ADMIN_PROFILE_JSON" | jq '.servers | length')
    
    log_ok "Device: $ADMIN_DEVICE_NAME ($ADMIN_PLATFORM)"
    log_info "Tools: $tool_count registered"
    log_info "Servers: $server_count managed"
    
    return 0
}

load_deployment() {
    local deployment_name="$1"
    
    if [[ -z "$ADMIN_PROFILE_JSON" ]]; then
        log_error "Profile not loaded. Run load_admin_profile first"
        return 1
    fi
    
    local env_file=$(echo "$ADMIN_PROFILE_JSON" | jq -r ".deployments[\"$deployment_name\"].envFile // empty")
    
    if [[ -z "$env_file" ]]; then
        log_error "Deployment '$deployment_name' not found or has no envFile"
        log_warn "Available deployments:"
        echo "$ADMIN_PROFILE_JSON" | jq -r '.deployments | keys[]' | sed 's/^/  - /'
        return 1
    fi
    
    # Convert Windows paths to WSL if needed
    if [[ "$env_file" == *":"* ]]; then
        local drive=$(echo "$env_file" | cut -c1 | tr '[:upper:]' '[:lower:]')
        local path=$(echo "$env_file" | cut -c3- | sed 's|\\|/|g')
        env_file="/mnt/$drive$path"
    fi
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Env file not found: $env_file"
        return 1
    fi
    
    log_info "Loading deployment: $deployment_name"
    load_env_file "$env_file"
}

load_env_file() {
    local env_path="$1"
    local export_vars="${2:-true}"
    
    if [[ ! -f "$env_path" ]]; then
        log_error "Env file not found: $env_path"
        return 1
    fi
    
    log_info "Parsing: $env_path"
    
    local count=0
    local key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        [[ "$line" != *"="* ]] && continue

        key="${line%%=*}"
        # Validate key format
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        value="${line#*=}"
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"

        if [[ "$export_vars" == "true" ]]; then
            export "$key=$value"
        fi
        count=$((count + 1))
    done < "$env_path"
    
    log_ok "Loaded $count variables"
}

get_admin_tool() {
    local tool_name="$1"
    if [[ -z "$ADMIN_PROFILE_JSON" ]]; then log_error "Profile not loaded"; return 1; fi
    echo "$ADMIN_PROFILE_JSON" | jq ".tools[\"$tool_name\"]"
}

get_tool_path() {
    local tool_name="$1"
    echo "$ADMIN_PROFILE_JSON" | jq -r ".tools[\"$tool_name\"].path // empty"
}

is_tool_working() {
    local tool_name="$1"
    local status=$(echo "$ADMIN_PROFILE_JSON" | jq -r ".tools[\"$tool_name\"].installStatus // empty")
    [[ "$status" == "working" ]]
}

get_admin_server() {
    local filter_type="$1"
    local filter_value="$2"
    
    if [[ -z "$ADMIN_PROFILE_JSON" ]]; then log_error "Profile not loaded"; return 1; fi
    
    case "$filter_type" in
        id) echo "$ADMIN_PROFILE_JSON" | jq ".servers[] | select(.id == \"$filter_value\")" ;;
        role) echo "$ADMIN_PROFILE_JSON" | jq ".servers[] | select(.role == \"$filter_value\")" ;;
        provider) echo "$ADMIN_PROFILE_JSON" | jq ".servers[] | select(.provider == \"$filter_value\")" ;;
        *) echo "$ADMIN_PROFILE_JSON" | jq '.servers[]' ;;
    esac
}

get_admin_preference() {
    local category="$1"
    echo "$ADMIN_PROFILE_JSON" | jq -r ".preferences[\"$category\"]"
}

get_preferred_manager() {
    local category="$1"
    echo "$ADMIN_PROFILE_JSON" | jq -r ".preferences[\"$category\"].manager // empty"
}

has_capability() {
    local capability="$1"
    local value=$(echo "$ADMIN_PROFILE_JSON" | jq -r ".capabilities[\"$capability\"] // false")
    [[ "$value" == "true" ]]
}

show_admin_summary() {
    if [[ -z "$ADMIN_PROFILE_JSON" ]]; then log_error "Profile not loaded"; return 1; fi
    
    echo ""
    echo -e "${CYAN}=== Admin Profile Summary ===${NC}"
    echo "Device:     $ADMIN_DEVICE_NAME ($ADMIN_PLATFORM)"
    echo "User:       $(echo "$ADMIN_PROFILE_JSON" | jq -r '.device.user')"
    echo "Shell:      $(echo "$ADMIN_PROFILE_JSON" | jq -r '.preferences.shell.preferred')"
    echo ""
    
    echo -e "${YELLOW}Preferences:${NC}"
    echo "  Python:   $(get_preferred_manager python)"
    echo "  Node:     $(get_preferred_manager node)"
    echo "  Packages: $(get_preferred_manager packages)"
    echo ""
    
    echo -e "${YELLOW}Capabilities:${NC}"
    local caps=""
    has_capability "hasWsl" && caps+="WSL "
    has_capability "hasDocker" && caps+="Docker "
    has_capability "mcpEnabled" && caps+="MCP "
    has_capability "canAccessDropbox" && caps+="Dropbox "
    echo "  $caps"
    echo ""
    
    echo -e "${YELLOW}Servers:${NC}"
    echo "$ADMIN_PROFILE_JSON" | jq -r '.servers[] | "  \(if .status == "active" then "✓" else "○" end) \(.name) (\(.role)) - \(.host)"'
    echo ""
    
    echo -e "${YELLOW}Deployments:${NC}"
    echo "$ADMIN_PROFILE_JSON" | jq -r '.deployments | to_entries[] | "  \(if .value.envFile then "✓" else "○" end) \(.key) (\(.value.type)/\(.value.provider)) - \(.value.status)"'
    echo ""
}

ssh_to_server() {
    local server_id="$1"
    shift
    
    local server=$(get_admin_server id "$server_id")
    
    if [[ -z "$server" || "$server" == "null" ]]; then
        log_error "Server not found: $server_id"
        return 1
    fi
    
    local host=$(echo "$server" | jq -r '.host')
    local user=$(echo "$server" | jq -r '.username')
    local port=$(echo "$server" | jq -r '.port // 22')
    local key=$(echo "$server" | jq -r '.keyPath // empty')
    
    if [[ -n "$key" && "$key" == *":"* ]]; then
        local drive=$(echo "$key" | cut -c1 | tr '[:upper:]' '[:lower:]')
        local path=$(echo "$key" | cut -c3- | sed 's|\\|/|g')
        key="/mnt/$drive$path"
    fi
    
    log_info "Connecting to $user@$host:$port"
    
    if [[ -n "$key" && -f "$key" ]]; then
        ssh -i "$key" -p "$port" "$user@$host" "$@"
    else
        ssh -p "$port" "$user@$host" "$@"
    fi
}

py() {
    local manager=$(get_preferred_manager python)
    case "$manager" in
        uv) uv "$@" ;;
        pip) pip "$@" ;;
        conda) conda "$@" ;;
        poetry) poetry "$@" ;;
        *) python "$@" ;;
    esac
}

if [[ "${1:-}" ]]; then
    load_admin_profile
    load_admin_secrets
    load_deployment "$1"
    show_admin_summary
fi
