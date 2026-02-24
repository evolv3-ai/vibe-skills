#!/usr/bin/env bash
# =============================================================================
# Admin Suite Issue Creator - Bash version for WSL/Unix
# =============================================================================
# Usage:
#   source new-admin-issue.sh
#   new_admin_issue "Audio driver not detected" "troubleshoot" "audio,driver"
# Or run directly:
#   ./new-admin-issue.sh "Node install failed" "install" "node,npm"
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

# Source the logging function
# shellcheck source=log-admin-event.sh
source "${SCRIPT_DIR}/log-admin-event.sh"

# Resolve ADMIN_ROOT from satellite .env or environment
_resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        echo "$ADMIN_ROOT"; return
    fi
    local satellite="${HOME}/.admin/.env"
    if [[ -f "$satellite" ]]; then
        local root
        root=$(grep "^ADMIN_ROOT=" "$satellite" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}

_resolve_platform() {
    if [[ -n "${ADMIN_PLATFORM:-}" ]]; then
        echo "$ADMIN_PLATFORM"; return
    fi
    local satellite="${HOME}/.admin/.env"
    if [[ -f "$satellite" ]]; then
        local plat
        plat=$(grep "^ADMIN_PLATFORM=" "$satellite" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$plat" ]]; then echo "$plat"; return; fi
    fi
    if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
    elif [[ "$(uname -s)" == "Darwin" ]]; then echo "macos"
    else echo "linux"
    fi
}

new_admin_issue() {
    local title="$1"
    local category="$2"
    local tags="${3:-}"

    if [[ -z "$title" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Title is required" >&2
        return 1
    fi

    if [[ -z "$category" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Category is required (troubleshoot|install|devenv|mcp|skills|devops)" >&2
        return 1
    fi

    # Validate category
    case "$category" in
        troubleshoot|install|devenv|mcp|skills|devops) ;;
        *)
            echo -e "\033[0;31m[ERROR]\033[0m Invalid category: $category" >&2
            echo "Valid categories: troubleshoot, install, devenv, mcp, skills, devops" >&2
            return 1
            ;;
    esac

    # Resolve ADMIN_ROOT
    local admin_root
    admin_root=$(_resolve_admin_root)

    # Ensure issues directory exists
    local issues_dir="${admin_root}/issues"
    mkdir -p "$issues_dir"

    # Generate ID components
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local iso_timestamp
    iso_timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

    # Create slug from title
    local slug
    slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//')
    if [[ ${#slug} -gt 30 ]]; then
        slug="${slug:0:30}"
        slug="${slug%_}"
    fi

    # Build ID and filename
    local issue_id="issue_${timestamp}_${slug}"
    local filename="${issue_id}.md"
    local filepath="${issues_dir}/${filename}"

    # Get device info
    local device_name
    device_name=$(hostname)
    local platform
    platform=$(_resolve_platform)

    # Format tags for YAML
    local tags_yaml="[]"
    if [[ -n "$tags" ]]; then
        # Convert comma-separated to JSON array
        tags_yaml="[$(echo "$tags" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/' )]"
    fi

    # Build issue content
    cat > "$filepath" <<EOF
---
id: $issue_id
device: $device_name
platform: $platform
status: open
category: $category
tags: $tags_yaml
created: $iso_timestamp
updated: $iso_timestamp
related_logs:
  - logs/operations.log
---

# $title

## Context


## Symptoms


## Hypotheses


## Actions Taken


## Resolution


## Verification


## Next Action

EOF

    # Log the creation
    log_admin_event "Issue created: $issue_id" "INFO"

    echo -e "\033[0;32m[OK]\033[0m Issue created: $filepath"

    echo "$filepath"
}

# If script is run directly (not sourced), execute with arguments
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    if [[ $# -ge 2 ]]; then
        new_admin_issue "$@"
    else
        echo "Usage: new-admin-issue.sh <title> <category> [tags]"
        echo "  category: troubleshoot, install, devenv, mcp, skills, devops"
        echo "  tags: comma-separated (e.g., 'audio,driver')"
        exit 1
    fi
fi
