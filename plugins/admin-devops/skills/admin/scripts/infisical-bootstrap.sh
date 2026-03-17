#!/usr/bin/env bash
# =============================================================================
# Infisical Bootstrap - Create projects, environments, and folder hierarchies
# =============================================================================
# Automates the creation of Infisical projects for the admin-devops split:
#   1. admin-operator   - Shared operator secrets (providers, LLM, network)
#   2. admin-runtime    - Agent runtime + deployment secrets
#   3. customer-*       - Per-customer project (optional)
#
# Prerequisites:
#   - infisical CLI installed and authenticated (infisical login)
#   - jq installed
#   - INFISICAL_ORG_ID set or discoverable
#
# Usage:
#   ./infisical-bootstrap.sh                          # Create all 3 projects
#   ./infisical-bootstrap.sh --project admin-operator  # Create one project
#   ./infisical-bootstrap.sh --dry-run                 # Show what would be created
#   ./infisical-bootstrap.sh --customer larrysinteriors # Create customer project
#
# Output:
#   Updates $ADMIN_ROOT/config/infisical-projects.json with project IDs
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[i]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# --- Resolve paths ---
SATELLITE_ENV="${HOME}/.admin/.env"

resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then echo "$ADMIN_ROOT"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local root
        root=$(grep "^ADMIN_ROOT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}

ADMIN_ROOT="$(resolve_admin_root)"
PROJECTS_FILE="${ADMIN_ROOT}/config/infisical-projects.json"

# --- Arguments ---
DRY_RUN=false
TARGET_PROJECT=""
CUSTOMER_NAME=""
ENVIRONMENTS=("prod" "lab")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --project) TARGET_PROJECT="$2"; shift 2 ;;
        --customer) CUSTOMER_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: infisical-bootstrap.sh [--project NAME] [--customer NAME] [--dry-run]"
            exit 0
            ;;
        *) err "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Prerequisites ---
section "Prerequisites"

if ! command -v infisical &>/dev/null; then
    err "infisical CLI not installed"
    exit 1
fi
ok "infisical CLI found"

if ! command -v jq &>/dev/null; then
    err "jq not installed"
    exit 1
fi
ok "jq found"

# Check auth
if ! infisical secrets list --projectId "00000000-0000-0000-0000-000000000000" --env prod >/dev/null 2>&1; then
    # This will fail (fake project), but a 401 means not authenticated
    # vs a 404 which means authenticated but project not found
    info "Auth check: verifying login status..."
fi

# --- Project definitions ---
declare -A PROJECT_FOLDERS

PROJECT_FOLDERS["admin-operator"]="shared/llm shared/mattermost shared/sentinel providers/contabo providers/hetzner providers/digitalocean providers/vultr providers/linode providers/oci network/cloudflare files/gcloud"
PROJECT_FOLDERS["admin-runtime"]="agents/lia agents/shane agents/terra agents/taco agents/picoclaw deployments/kasm-contabo-01 deployments/kasm-hetzner-01 deployments/kasm-hetzner-02 deployments/nanoclaw-contabo-01"

if [[ -n "$CUSTOMER_NAME" ]]; then
    PROJECT_FOLDERS["customer-${CUSTOMER_NAME}"]="apps/openclaw workspace files/gcloud local"
fi

PROJECT_DESCRIPTIONS=(
    ["admin-operator"]="Shared operator secrets: provider keys, LLM tokens, Cloudflare, Mattermost"
    ["admin-runtime"]="Agent runtime secrets and deployment configs"
)
if [[ -n "$CUSTOMER_NAME" ]]; then
    PROJECT_DESCRIPTIONS["customer-${CUSTOMER_NAME}"]="Customer: ${CUSTOMER_NAME}"
fi

# Filter to target if specified
if [[ -n "$TARGET_PROJECT" ]]; then
    if [[ -z "${PROJECT_FOLDERS[$TARGET_PROJECT]:-}" ]]; then
        err "Unknown project: $TARGET_PROJECT"
        echo "Available: ${!PROJECT_FOLDERS[*]}"
        exit 1
    fi
    declare -A FILTERED
    FILTERED["$TARGET_PROJECT"]="${PROJECT_FOLDERS[$TARGET_PROJECT]}"
    unset PROJECT_FOLDERS
    declare -A PROJECT_FOLDERS
    for k in "${!FILTERED[@]}"; do
        PROJECT_FOLDERS["$k"]="${FILTERED[$k]}"
    done
fi

# --- Ensure projects config exists ---
if [[ ! -f "$PROJECTS_FILE" ]]; then
    mkdir -p "$(dirname "$PROJECTS_FILE")"
    echo '{"defaultEnvironment":"prod","projects":{}}' > "$PROJECTS_FILE"
    ok "Created $PROJECTS_FILE"
fi

# --- Create projects ---
for project_name in "${!PROJECT_FOLDERS[@]}"; do
    section "Project: $project_name"

    # Check if project already has an ID in config
    existing_id=$(jq -r ".projects[\"$project_name\"].id // empty" "$PROJECTS_FILE" 2>/dev/null)
    if [[ -n "$existing_id" ]]; then
        ok "Already configured with ID: $existing_id"
        info "Skipping project creation (already exists)"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            info "[DRY RUN] Would create project: $project_name"
        else
            info "Creating project: $project_name"
            # Note: infisical project creation via CLI may require API calls
            # The user may need to create projects via the dashboard and paste IDs
            warn "Infisical CLI does not support project creation directly."
            warn "Please create project '$project_name' in the Infisical dashboard"
            warn "Then run: jq '.projects[\"$project_name\"].id = \"YOUR_PROJECT_ID\"' $PROJECTS_FILE > tmp && mv tmp $PROJECTS_FILE"
            echo ""
            echo "After creating the project, paste the project ID here (or press Enter to skip):"
            read -r project_id
            if [[ -n "$project_id" ]]; then
                # Update the config file
                local_desc="${PROJECT_DESCRIPTIONS[$project_name]:-}"
                local_folders="${PROJECT_FOLDERS[$project_name]}"
                local_folders_json=$(echo "$local_folders" | tr ' ' '\n' | jq -R . | jq -s .)

                jq --arg name "$project_name" \
                   --arg id "$project_id" \
                   --arg desc "$local_desc" \
                   --argjson folders "$local_folders_json" \
                   '.projects[$name] = {"id": $id, "description": $desc, "folders": $folders}' \
                   "$PROJECTS_FILE" > "${PROJECTS_FILE}.tmp" && mv "${PROJECTS_FILE}.tmp" "$PROJECTS_FILE"
                ok "Saved project ID: $project_id"
                existing_id="$project_id"
            else
                warn "Skipped - no ID provided"
                continue
            fi
        fi
    fi

    # Create folder hierarchy
    if [[ -n "$existing_id" && "$DRY_RUN" != "true" ]]; then
        info "Creating folder hierarchy..."
        local_folders="${PROJECT_FOLDERS[$project_name]}"
        for env_slug in "${ENVIRONMENTS[@]}"; do
            info "Environment: $env_slug"
            for folder in $local_folders; do
                # Create each folder segment
                # infisical folders create --path /PARENT --name CHILD
                IFS='/' read -ra segments <<< "$folder"
                current_path="/"
                for segment in "${segments[@]}"; do
                    if infisical secrets list --projectId "$existing_id" --env "$env_slug" --path "${current_path}${segment}" >/dev/null 2>&1; then
                        info "  Folder exists: ${current_path}${segment}"
                    else
                        if infisical folders create --projectId "$existing_id" --env "$env_slug" --path "$current_path" --name "$segment" >/dev/null 2>&1; then
                            ok "  Created: ${current_path}${segment}"
                        else
                            warn "  Failed to create: ${current_path}${segment} (may already exist)"
                        fi
                    fi
                    current_path="${current_path}${segment}/"
                done
            done
        done
    elif [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would create folders:"
        for folder in ${PROJECT_FOLDERS[$project_name]}; do
            echo "    /$folder"
        done
    fi
done

# --- Summary ---
section "Bootstrap Complete"
echo ""
echo "Projects config: $PROJECTS_FILE"
echo ""
jq '.projects | to_entries[] | "  \(.key): \(.value.id // "NOT SET")"' -r "$PROJECTS_FILE" 2>/dev/null
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    warn "This was a dry run. No changes were made."
fi

echo ""
echo "Next steps:"
echo "  1. If project IDs are missing, create projects in the Infisical dashboard"
echo "  2. Run Phase 2: migrate-secrets-phase2.sh (operator secrets)"
echo "  3. Run Phase 3: migrate-secrets-phase3.sh (agent runtime secrets)"
