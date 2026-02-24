#!/usr/bin/env bash
# =============================================================================
# Test Admin Profile - Checks if admin profile exists
# =============================================================================
# Checks for the satellite .env at ~/.admin/.env, reads ADMIN_ROOT, ADMIN_DEVICE,
# ADMIN_PLATFORM, and preference vars, then checks if the profile JSON exists.
#
# Resolution order:
#   1. ADMIN_ROOT env var (if already set)
#   2. ~/.admin/.env satellite file (primary mechanism)
#   3. Platform-based fallback (legacy, for pre-satellite setups)
#
# Returns JSON: {"exists":true|false,"path":"...","device":"...","adminRoot":"...",
#                "schemaVersion":"...","adminSkillVersion":"...","platform":"..."}
#
# Usage:
#   ./test-admin-profile.sh
#   source test-admin-profile.sh && test_admin_profile
# =============================================================================

set -eo pipefail

SATELLITE_ENV="${HOME}/.admin/.env"

# Detect Windows username from WSL (multiple fallback methods)
# Only used as legacy fallback when no satellite .env exists
detect_win_user() {
    local win_user=""

    # Method 1: cmd.exe (fastest, often fails in WSL)
    win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    if [[ -n "$win_user" && "$win_user" != "%USERNAME%" ]]; then
        echo "$win_user"; return
    fi

    # Method 2: PowerShell
    win_user=$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r')
    if [[ -n "$win_user" ]]; then
        echo "$win_user"; return
    fi

    # Method 3: wslvar (if wslu is installed)
    win_user=$(wslvar USERNAME 2>/dev/null | tr -d '\r')
    if [[ -n "$win_user" ]]; then
        echo "$win_user"; return
    fi

    # Method 4: Parse /mnt/c/Users (heuristic)
    win_user=$(ls /mnt/c/Users/ 2>/dev/null | grep -v -E "^(Public|Default|All Users|Default User|desktop.ini)$" | head -1)
    if [[ -n "$win_user" ]]; then
        echo "$win_user"; return
    fi

    echo ""  # All methods failed
}

# Read a variable from the satellite .env file
read_satellite_var() {
    local var_name="$1"
    local env_file="$2"
    grep "^${var_name}=" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2-
}

test_admin_profile() {
    local admin_root=""
    local device_name=""
    local platform=""
    local pkg_mgr=""
    local win_pkg_mgr=""
    local py_mgr=""
    local node_mgr=""
    local shell_pref=""

    # Priority 1: ADMIN_ROOT env var already set
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        admin_root="$ADMIN_ROOT"
        device_name="${ADMIN_DEVICE:-$(hostname)}"
        platform="${ADMIN_PLATFORM:-}"

    # Priority 2: Satellite .env file (primary mechanism)
    elif [[ -f "$SATELLITE_ENV" ]]; then
        admin_root=$(read_satellite_var "ADMIN_ROOT" "$SATELLITE_ENV")
        device_name=$(read_satellite_var "ADMIN_DEVICE" "$SATELLITE_ENV")
        platform=$(read_satellite_var "ADMIN_PLATFORM" "$SATELLITE_ENV")
        pkg_mgr=$(read_satellite_var "ADMIN_PKG_MGR" "$SATELLITE_ENV")
        win_pkg_mgr=$(read_satellite_var "ADMIN_WIN_PKG_MGR" "$SATELLITE_ENV")
        py_mgr=$(read_satellite_var "ADMIN_PY_MGR" "$SATELLITE_ENV")
        node_mgr=$(read_satellite_var "ADMIN_NODE_MGR" "$SATELLITE_ENV")
        shell_pref=$(read_satellite_var "ADMIN_SHELL" "$SATELLITE_ENV")
        device_name="${device_name:-$(hostname)}"

    # Priority 3: Legacy fallback (no satellite .env yet)
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user
        win_user=$(detect_win_user)
        if [[ -n "$win_user" ]]; then
            admin_root="/mnt/c/Users/$win_user/.admin"
        else
            admin_root="${HOME}/.admin"
        fi
        device_name=$(hostname)
    else
        admin_root="${HOME}/.admin"
        device_name=$(hostname)
    fi

    # Build profile path
    local profile_path="${admin_root}/profiles/${device_name}.json"

    # Check existence and read metadata
    local exists="false"
    local schema_version=""
    local skill_version=""

    if [[ -f "$profile_path" ]]; then
        exists="true"
        if command -v jq &>/dev/null; then
            schema_version=$(jq -r '.schemaVersion // empty' "$profile_path" 2>/dev/null || true)
            skill_version=$(jq -r '.adminSkillVersion // empty' "$profile_path" 2>/dev/null || true)
            # Read platform from profile if not set by satellite
            [[ -z "$platform" ]] && platform=$(jq -r '.device.platform // empty' "$profile_path" 2>/dev/null || true)
        fi
    fi

    # Build preferences JSON fragment
    local prefs_json=""
    if [[ -n "$pkg_mgr" || -n "$py_mgr" || -n "$node_mgr" || -n "$shell_pref" ]]; then
        prefs_json=',"preferences":{"packages":"'"${pkg_mgr}"'"'
        [[ -n "$win_pkg_mgr" ]] && prefs_json+=',"winPackages":"'"${win_pkg_mgr}"'"'
        prefs_json+=',"python":"'"${py_mgr}"'","node":"'"${node_mgr}"'","shell":"'"${shell_pref}"'"}'
    fi

    # Output JSON
    cat <<JSON
{"exists":${exists},"path":"${profile_path}","device":"${device_name}","adminRoot":"${admin_root}","schemaVersion":"${schema_version}","adminSkillVersion":"${skill_version}","platform":"${platform}"${prefs_json}}
JSON
}

# Auto-run if executed directly
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    test_admin_profile
fi
