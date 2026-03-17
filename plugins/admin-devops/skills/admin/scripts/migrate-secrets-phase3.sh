#!/usr/bin/env bash
# =============================================================================
# Migrate Secrets Phase 3 - Agent runtime secrets + profile schema update
# =============================================================================
# Pushes agent bot tokens/credentials to admin-runtime/agents/ folders.
# Updates profile JSON: secrets:[] -> secretRefs:{}, adds secretsConfig.
#
# Idempotent: checks if target exists before writing.
#
# Usage:
#   ./migrate-secrets-phase3.sh              # Migrate agent secrets
#   ./migrate-secrets-phase3.sh --dry-run    # Show what would be migrated
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

resolve_device_name() {
    if [[ -n "${ADMIN_DEVICE:-}" ]]; then echo "$ADMIN_DEVICE"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local dev
        dev=$(grep "^ADMIN_DEVICE=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$dev" ]]; then echo "$dev"; return; fi
    fi
    hostname
}

ADMIN_ROOT="$(resolve_admin_root)"
DEVICE_NAME="$(resolve_device_name)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="${ADMIN_ROOT}/config/infisical-projects.json"
PROFILE_PATH="${ADMIN_ROOT}/profiles/${DEVICE_NAME}.json"

DRY_RUN=false
ENV_SLUG="prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --env) ENV_SLUG="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: migrate-secrets-phase3.sh [--dry-run] [--env ENV]"
            exit 0
            ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$PROJECTS_FILE" ]]; then err "Projects config not found: $PROJECTS_FILE"; exit 1; fi

PROJECT_ID=$(jq -r '.projects["admin-runtime"].id // empty' "$PROJECTS_FILE")
if [[ -z "$PROJECT_ID" ]]; then
    err "admin-runtime project ID not set in $PROJECTS_FILE"
    exit 1
fi

section "Phase 3: Migrate Agent Runtime Secrets"
info "Project ID: $PROJECT_ID"
info "Environment: $ENV_SLUG"

# Agent secret mappings: FLAT_KEY -> FOLDER/NEW_KEY
# Format: agent_name:flat_key:target_key
AGENT_SECRETS=(
    "lia:LIA_MM_BOT_TOKEN:MM_BOT_TOKEN"
    "lia:LIA_GATEWAY_TOKEN:GATEWAY_TOKEN"
    "lia:LIA_AUTH_PASSWORD:AUTH_PASSWORD"
    "shane:SHANE_MM_BOT_TOKEN:MM_BOT_TOKEN"
    "shane:SHANE_GATEWAY_TOKEN:GATEWAY_TOKEN"
    "shane:SHANE_AUTH_PASSWORD:AUTH_PASSWORD"
    "terra:TERRA_MM_BOT_TOKEN:MM_BOT_TOKEN"
    "terra:TERRA_GATEWAY_TOKEN:GATEWAY_TOKEN"
    "terra:TERRA_AUTH_PASSWORD:AUTH_PASSWORD"
    "taco:TACO_MM_BOT_TOKEN:MM_BOT_TOKEN"
    "picoclaw:PICOCLAW_DISCORD_BOT_TOKEN:DISCORD_BOT_TOKEN"
    "picoclaw:PICOCLAW_MM_BOT_TOKEN:MM_BOT_TOKEN"
    "picoclaw:PICOCLAW_BRAVE_API_KEY:BRAVE_API_KEY"
)

get_current_value() {
    local key="$1"
    "$SCRIPT_DIR/secrets" "$key" 2>/dev/null || true
}

migrated=0
skipped=0
failed=0

for entry in "${AGENT_SECRETS[@]}"; do
    IFS=':' read -r agent flat_key target_key <<< "$entry"
    target_path="/agents/$agent"

    echo -n "  $flat_key -> $target_path/$target_key... "

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN]"
        migrated=$((migrated + 1))
        continue
    fi

    value=$(get_current_value "$flat_key")
    if [[ -z "$value" ]]; then
        echo "SKIP (not found)"
        skipped=$((skipped + 1))
        continue
    fi

    existing=$(infisical secrets get "$target_key" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" --plain 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
        echo "EXISTS"
        skipped=$((skipped + 1))
        continue
    fi

    if infisical secrets set "${target_key}=${value}" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" >/dev/null 2>&1; then
        echo "OK"
        migrated=$((migrated + 1))
    else
        echo "FAILED"
        failed=$((failed + 1))
    fi
done

# --- Update profile schema ---
section "Updating Profile: secretRefs"

if [[ -f "$PROFILE_PATH" && "$DRY_RUN" != "true" ]]; then
    # Build secretRefs object for agents
    AGENT_NAMES=("lia" "shane" "terra" "taco" "picoclaw")

    # Add secretRefs and secretsConfig to profile
    jq --arg env "$ENV_SLUG" '
    # Add secretRefs if not present
    if .secretRefs == null then
        .secretRefs = {}
    else . end |

    # Add secretsConfig
    .secretsConfig = {
        "backend": "infisical",
        "fallback": "vault",
        "multiProject": true,
        "projectsConfig": "config/infisical-projects.json"
    } |

    # Add agent secretRefs
    .secretRefs["lia_mm_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/lia/MM_BOT_TOKEN") |
    .secretRefs["lia_gateway_token"] = ("infisical://admin-runtime/" + $env + "/agents/lia/GATEWAY_TOKEN") |
    .secretRefs["lia_auth_password"] = ("infisical://admin-runtime/" + $env + "/agents/lia/AUTH_PASSWORD") |
    .secretRefs["shane_mm_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/shane/MM_BOT_TOKEN") |
    .secretRefs["shane_gateway_token"] = ("infisical://admin-runtime/" + $env + "/agents/shane/GATEWAY_TOKEN") |
    .secretRefs["shane_auth_password"] = ("infisical://admin-runtime/" + $env + "/agents/shane/AUTH_PASSWORD") |
    .secretRefs["terra_mm_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/terra/MM_BOT_TOKEN") |
    .secretRefs["terra_gateway_token"] = ("infisical://admin-runtime/" + $env + "/agents/terra/GATEWAY_TOKEN") |
    .secretRefs["terra_auth_password"] = ("infisical://admin-runtime/" + $env + "/agents/terra/AUTH_PASSWORD") |
    .secretRefs["taco_mm_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/taco/MM_BOT_TOKEN") |
    .secretRefs["picoclaw_discord_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/picoclaw/DISCORD_BOT_TOKEN") |
    .secretRefs["picoclaw_mm_bot_token"] = ("infisical://admin-runtime/" + $env + "/agents/picoclaw/MM_BOT_TOKEN") |
    .secretRefs["picoclaw_brave_api_key"] = ("infisical://admin-runtime/" + $env + "/agents/picoclaw/BRAVE_API_KEY") |

    # Bump schema version
    .schemaVersion = "4.0"
    ' "$PROFILE_PATH" > "${PROFILE_PATH}.tmp" && mv "${PROFILE_PATH}.tmp" "$PROFILE_PATH"

    ok "Profile updated with secretRefs and schemaVersion 4.0"
elif [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY RUN] Would update $PROFILE_PATH with secretRefs"
else
    warn "Profile not found: $PROFILE_PATH"
fi

section "Phase 3 Summary"
echo "Migrated: $migrated"
echo "Skipped:  $skipped"
echo "Failed:   $failed"

if [[ "$DRY_RUN" == "true" ]]; then
    warn "This was a dry run."
fi

echo ""
echo "Next: Run migrate-secrets-phase4.sh (deployment secrets) and migrate-secrets-phase5.sh (JSON files) in parallel"
