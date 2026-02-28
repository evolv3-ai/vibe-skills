#!/usr/bin/env bash
# =============================================================================
# Admin Suite Session Start - Bash version for WSL/Unix
# =============================================================================
# Displays profile location, last 3 log entries, last 3 issues, and prompts
# the user for what they need help with. This is the core loop entry point.
#
# Usage:
#   source show-admin-session-start.sh
#   show_admin_session_start
# Or run directly:
#   ./show-admin-session-start.sh
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

# Source dependencies
# shellcheck source=load-profile.sh
source "${SCRIPT_DIR}/load-profile.sh"
# shellcheck source=log-admin-event.sh
source "${SCRIPT_DIR}/log-admin-event.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

show_admin_session_start() {
    # Resolve ADMIN_ROOT from satellite .env or environment
    local admin_root
    local device_name
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        admin_root="$ADMIN_ROOT"
        device_name="${ADMIN_DEVICE:-$(hostname)}"
    elif [[ -f "${HOME}/.admin/.env" ]]; then
        admin_root=$(grep "^ADMIN_ROOT=" "${HOME}/.admin/.env" 2>/dev/null | head -1 | cut -d'=' -f2-)
        device_name=$(grep "^ADMIN_DEVICE=" "${HOME}/.admin/.env" 2>/dev/null | head -1 | cut -d'=' -f2-)
        admin_root="${admin_root:-${HOME}/.admin}"
        device_name="${device_name:-$(hostname)}"
    else
        admin_root="${HOME}/.admin"
        device_name=$(hostname)
    fi

    local profile_path="${admin_root}/profiles/${device_name}.json"

    # Check if profile exists, run setup if not
    if [[ ! -f "$profile_path" ]]; then
        echo ""
        echo -e "${CYAN}=== Admin Session Start ===${NC}"
        echo -e "${YELLOW}[WARN]${NC} No profile found for $hostname"
        echo -e "${GRAY}Running setup interview...${NC}"

        local setup_script="${SCRIPT_DIR}/setup-interview.sh"
        if [[ -f "$setup_script" ]]; then
            # shellcheck source=setup-interview.sh
            bash "$setup_script"
        else
            echo -e "${RED}[ERROR]${NC} Setup script not found: $setup_script"
            return 1
        fi
    fi

    # Load profile (suppress output for cleaner display)
    load_admin_profile "$profile_path" > /dev/null 2>&1 || true

    if [[ -z "${ADMIN_PROFILE_JSON:-}" ]]; then
        echo -e "${RED}[ERROR]${NC} Failed to load profile"
        return 1
    fi

    local device_name
    device_name=$(echo "$ADMIN_PROFILE_JSON" | jq -r '.device.name // "unknown"')
    local platform
    platform=$(echo "$ADMIN_PROFILE_JSON" | jq -r '.device.platform // "unknown"')

    # Display header
    echo ""
    echo -e "${CYAN}=== Admin Session Start ===${NC}"
    echo "Profile: $device_name ($platform)"
    echo "Location: $admin_root"

    # Read last 3 log entries
    echo ""
    echo -e "${YELLOW}Recent Activity:${NC}"

    local log_path="${admin_root}/logs/operations.log"
    if [[ -f "$log_path" ]]; then
        local log_lines
        log_lines=$(tail -3 "$log_path" 2>/dev/null || true)

        if [[ -n "$log_lines" ]]; then
            while IFS= read -r line; do
                # Parse: [timestamp] [device] [platform] [level] message
                if [[ "$line" =~ ^\[([^\]]+)\]\ +\[[^\]]+\]\ +\[[^\]]+\]\ +\[([^\]]+)\]\ +(.+)$ ]]; then
                    local timestamp="${BASH_REMATCH[1]}"
                    local level="${BASH_REMATCH[2]}"
                    local message="${BASH_REMATCH[3]}"

                    # Simplify timestamp (take first 16 chars)
                    local display_time="${timestamp:0:16}"

                    local level_color
                    case "$level" in
                        ERROR) level_color="$RED" ;;
                        WARN)  level_color="$YELLOW" ;;
                        OK)    level_color="$GREEN" ;;
                        *)     level_color="$GRAY" ;;
                    esac

                    echo -e "  - ${GRAY}[$display_time]${NC} ${level_color}$message${NC}"
                else
                    echo -e "  - ${GRAY}$line${NC}"
                fi
            done <<< "$log_lines"
        else
            echo -e "  ${GRAY}(no logs yet)${NC}"
        fi
    else
        echo -e "  ${GRAY}(no logs yet)${NC}"
    fi

    # Read last 3 issues (by modification time)
    echo ""
    echo -e "${YELLOW}Open Issues:${NC}"

    local issues_dir="${admin_root}/issues"
    if [[ -d "$issues_dir" ]]; then
        # Find issue files sorted by modification time, newest first
        local issue_files
        issue_files=$(find "$issues_dir" -maxdepth 1 -name "issue_*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -3 | cut -d' ' -f2-)

        if [[ -n "$issue_files" ]]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue

                local basename
                basename=$(basename "$file" .md)

                # Read status from frontmatter
                local status="open"
                local title="$basename"

                if grep -q "^status:" "$file" 2>/dev/null; then
                    status=$(grep "^status:" "$file" | head -1 | sed 's/status:\s*//' | tr -d ' ')
                fi

                # Get title from first markdown heading
                local heading
                heading=$(grep -m1 "^# " "$file" 2>/dev/null | sed 's/^# //' || true)
                if [[ -n "$heading" ]]; then
                    title="$heading"
                fi

                # Color based on status
                local status_badge status_color
                if [[ "$status" == "open" ]]; then
                    status_badge="[OPEN]"
                    status_color="$YELLOW"
                else
                    status_badge="[DONE]"
                    status_color="$GREEN"
                fi

                echo -e "  - ${status_color}${status_badge}${NC} ${GRAY}$basename: $title${NC}"
            done <<< "$issue_files"
        else
            echo -e "  ${GRAY}(no issues)${NC}"
        fi
    else
        echo -e "  ${GRAY}(no issues directory)${NC}"
    fi

    # Prompt
    echo ""
    echo -e "${CYAN}What do you need help with?${NC}"
    echo -e "${GRAY}Categories: troubleshoot | install | devenv | mcp | skills | devops${NC}"
    echo ""

    # Log session start (suppress output)
    log_admin_event "Session started" "INFO" > /dev/null 2>&1 || true
}

# Auto-run if executed directly
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    show_admin_session_start
fi
