#!/usr/bin/env bash
# =============================================================================
# Migrate Secrets Phase 5 - JSON credential files to Infisical
# =============================================================================
# Pushes Google ADC/OAuth JSON files as base64-encoded blobs to
# admin-operator/files/gcloud/ folder.
# Also creates render-secret-file.sh and Render-SecretFile.ps1.
#
# Usage:
#   ./migrate-secrets-phase5.sh [--dry-run] [--env ENV]
# =============================================================================

set -euo pipefail

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="${ADMIN_ROOT}/config/infisical-projects.json"

DRY_RUN=false
ENV_SLUG="prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --env) ENV_SLUG="$2"; shift 2 ;;
        -h|--help) echo "Usage: migrate-secrets-phase5.sh [--dry-run] [--env ENV]"; exit 0 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$PROJECTS_FILE" ]]; then err "Projects config not found"; exit 1; fi

PROJECT_ID=$(jq -r '.projects["admin-operator"].id // empty' "$PROJECTS_FILE")
if [[ -z "$PROJECT_ID" ]]; then err "admin-operator project ID not set"; exit 1; fi

section "Phase 5: Migrate JSON Credential Files"
info "Project ID: $PROJECT_ID"

# Scan for Google credential JSON files
# Common locations: ~/.config/gcloud/, $ADMIN_ROOT/credentials/
CRED_DIRS=(
    "${HOME}/.config/gcloud"
    "${ADMIN_ROOT}/credentials"
    "${ADMIN_ROOT}/config/gcloud"
)

migrated=0
skipped=0
failed=0

for cred_dir in "${CRED_DIRS[@]}"; do
    if [[ ! -d "$cred_dir" ]]; then continue; fi

    info "Scanning: $cred_dir"
    while IFS= read -r -d '' json_file; do
        filename=$(basename "$json_file" .json)
        # Sanitize filename for use as secret key
        secret_key="GCLOUD_$(echo "$filename" | tr '[:lower:]-. ' '[:upper:]___')"

        echo -n "  $json_file -> /files/gcloud/$secret_key... "

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN]"
            migrated=$((migrated + 1))
            continue
        fi

        # Check if already exists
        existing=$(infisical secrets get "$secret_key" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "/files/gcloud" --plain 2>/dev/null || true)
        if [[ -n "$existing" ]]; then
            echo "EXISTS"
            skipped=$((skipped + 1))
            continue
        fi

        # Base64 encode the JSON file
        encoded=$(base64 -w0 "$json_file" 2>/dev/null || base64 "$json_file" 2>/dev/null)

        if infisical secrets set "${secret_key}=${encoded}" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "/files/gcloud" >/dev/null 2>&1; then
            echo "OK"
            migrated=$((migrated + 1))
        else
            echo "FAILED"
            failed=$((failed + 1))
        fi
    done < <(find "$cred_dir" -name "*.json" -type f -print0 2>/dev/null)
done

section "Phase 5 Summary"
echo "Migrated: $migrated  Skipped: $skipped  Failed: $failed"

if [[ "$DRY_RUN" == "true" ]]; then
    warn "This was a dry run."
fi

echo ""
echo "Next: Run render-runtime.sh (Phase 6) to build generated/ output"
