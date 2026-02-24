#!/usr/bin/env bash
# =============================================================================
# Admin Version Info - Displays skill and profile version information
# =============================================================================
# Shows the current admin skill version, profile schema version, and
# profile's adminSkillVersion. Warns if versions are mismatched.
#
# Usage:
#   ./get-admin-version.sh
#   source get-admin-version.sh && get_admin_version
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
SKILL_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
VERSION_FILE="${SKILL_ROOT}/VERSION"
CHANGELOG_FILE="${SKILL_ROOT}/CHANGELOG.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

get_admin_version() {
    # Read skill version
    local skill_version="unknown"
    if [[ -f "$VERSION_FILE" ]]; then
        skill_version=$(head -1 "$VERSION_FILE" | tr -d '[:space:]')
    fi

    # Resolve ADMIN_ROOT from satellite .env or environment
    local admin_root
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        admin_root="$ADMIN_ROOT"
    elif [[ -f "${HOME}/.admin/.env" ]]; then
        admin_root=$(grep "^ADMIN_ROOT=" "${HOME}/.admin/.env" 2>/dev/null | head -1 | cut -d'=' -f2-)
        admin_root="${admin_root:-${HOME}/.admin}"
    else
        admin_root="${HOME}/.admin"
    fi

    # Read profile
    local device_name="${ADMIN_DEVICE:-}"
    if [[ -z "$device_name" && -f "${HOME}/.admin/.env" ]]; then
        device_name=$(grep "^ADMIN_DEVICE=" "${HOME}/.admin/.env" 2>/dev/null | head -1 | cut -d'=' -f2-)
    fi
    device_name="${device_name:-$(hostname)}"
    local profile_path="${admin_root}/profiles/${device_name}.json"
    local profile_version=""
    local profile_schema_version=""
    local profile_exists=false

    if [[ -f "$profile_path" ]]; then
        profile_exists=true
        if command -v jq &>/dev/null; then
            profile_version=$(jq -r '.adminSkillVersion // empty' "$profile_path" 2>/dev/null || true)
            profile_schema_version=$(jq -r '.schemaVersion // empty' "$profile_path" 2>/dev/null || true)
        else
            # Fallback: grep for values
            profile_version=$(grep -o '"adminSkillVersion"[[:space:]]*:[[:space:]]*"[^"]*"' "$profile_path" 2>/dev/null | cut -d'"' -f4 || true)
            profile_schema_version=$(grep -o '"schemaVersion"[[:space:]]*:[[:space:]]*"[^"]*"' "$profile_path" 2>/dev/null | cut -d'"' -f4 || true)
        fi
    fi

    # Display
    echo ""
    echo -e "${CYAN}=== Admin Version Info ===${NC}"
    echo ""
    echo -e "Skill Version:    ${GREEN}${skill_version}${NC}"
    echo -e "${GRAY}Skill Location:   ${SKILL_ROOT}${NC}"
    echo ""

    if [[ "$profile_exists" == true ]]; then
        echo -e "${GRAY}Profile Found:    ${profile_path}${NC}"
        echo -e "Schema Version:   ${GREEN}${profile_schema_version}${NC}"

        if [[ -n "$profile_version" ]]; then
            echo -n "Profile Created By: "
            if [[ "$profile_version" == "$skill_version" ]]; then
                echo -e "${GREEN}${profile_version} (current)${NC}"
            else
                echo -e "${YELLOW}${profile_version}${NC}"
                echo ""
                echo -e "${YELLOW}[WARN] Profile was created by an older skill version${NC}"
                echo -e "${YELLOW}       Consider re-running setup-interview.sh to update${NC}"
            fi
        else
            echo -e "Profile Created By: ${YELLOW}(pre-versioning)${NC}"
            echo ""
            echo -e "${YELLOW}[WARN] Profile predates versioning system${NC}"
            echo -e "${YELLOW}       Run setup-interview.sh to create a versioned profile${NC}"
        fi

        # Display skill versions comparison
        echo ""
        echo -e "${CYAN}--- Suite Skill Versions ---${NC}"
        local skills_root
        skills_root="$(dirname "$SKILL_ROOT")"
        local sibling_skills=("admin" "devops" "oci" "hetzner" "contabo" "digital-ocean" "vultr" "linode" "coolify" "kasm")
        local has_mismatch=false

        for sname in "${sibling_skills[@]}"; do
            # Current version from VERSION file
            local current_ver="n/a"
            local ver_file="${skills_root}/${sname}/VERSION"
            if [[ -f "$ver_file" ]]; then
                current_ver=$(head -1 "$ver_file" | tr -d '[:space:]')
            fi

            # Profile version from skillVersions
            local profile_sv=""
            if command -v jq &>/dev/null; then
                profile_sv=$(jq -r ".skillVersions.\"${sname}\" // empty" "$profile_path" 2>/dev/null || true)
            else
                profile_sv=$(grep -o "\"${sname}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$profile_path" 2>/dev/null | head -1 | cut -d'"' -f4 || true)
            fi

            if [[ -z "$profile_sv" ]]; then
                printf "  %-16s ${YELLOW}%-10s${NC} (not in profile)\n" "$sname" "$current_ver"
                has_mismatch=true
            elif [[ "$profile_sv" == "$current_ver" ]]; then
                printf "  %-16s ${GREEN}%-10s${NC}\n" "$sname" "$current_ver"
            else
                printf "  %-16s ${YELLOW}%-10s${NC} -> ${GREEN}%-10s${NC}\n" "$sname" "$profile_sv" "$current_ver"
                has_mismatch=true
            fi
        done

        if [[ "$has_mismatch" == true ]]; then
            echo ""
            echo -e "${YELLOW}[WARN] Some skill versions differ from profile${NC}"
            echo -e "${YELLOW}       Re-run profile setup to update skillVersions${NC}"
        fi
    else
        echo -e "Profile:          ${YELLOW}Not found${NC}"
        echo -e "${GRAY}Expected:         ${profile_path}${NC}"
        echo ""
        echo -e "${CYAN}[INFO] Run setup-interview.sh to create a profile${NC}"
    fi

    echo ""
    echo -e "${GRAY}Changelog:        ${CHANGELOG_FILE}${NC}"
    echo ""
}

# Auto-run if executed directly
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    get_admin_version
fi
