#!/usr/bin/env bash
# =============================================================================
# Resolve Secret Ref - Parse infisical:// URIs and fetch secrets
# =============================================================================
# Parses URIs of the form: infisical://PROJECT/ENV/FOLDER/KEY
# Resolves project slug → ID via mapping file, calls infisical secrets get
# with --path and --projectId, falls back to vault.
#
# Usage:
#   resolve-secret-ref.sh "infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN"
#   resolve-secret-ref.sh --uri "infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN"
#   resolve-secret-ref.sh --project admin-operator --env prod --path /providers/hetzner --key HCLOUD_TOKEN
#   resolve-secret-ref.sh --method universal-auth --uri "infisical://..."
#
# Environment:
#   ADMIN_ROOT          - Admin root directory
#   INFISICAL_PROJECTS  - Path to infisical-projects.json (default: $ADMIN_ROOT/config/infisical-projects.json)
# =============================================================================

set -euo pipefail

# --- Resolve paths from satellite .env ---
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

resolve_age_key() {
    if [[ -n "${AGE_KEY_PATH:-}" ]]; then echo "$AGE_KEY_PATH"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local key_path
        key_path=$(grep "^AGE_KEY_PATH=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$key_path" ]]; then echo "$key_path"; return; fi
    fi
    echo "${HOME}/.age/key.txt"
}

ADMIN_ROOT="$(resolve_admin_root)"
AGE_KEY="$(resolve_age_key)"
VAULT_FILE="${ADMIN_ROOT}/vault.age"
PROJECTS_FILE="${INFISICAL_PROJECTS:-${ADMIN_ROOT}/config/infisical-projects.json}"

# --- Parse infisical:// URI ---
# Format: infisical://PROJECT_SLUG/ENV/FOLDER.../KEY
# Example: infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN
parse_uri() {
    local uri="$1"

    # Strip protocol
    if [[ "$uri" != infisical://* ]]; then
        echo "Error: URI must start with infisical://" >&2
        return 1
    fi

    local path="${uri#infisical://}"

    # Extract parts: PROJECT/ENV/FOLDER.../KEY
    # Minimum: project/env/key (3 parts)
    IFS='/' read -ra parts <<< "$path"
    local count=${#parts[@]}

    if [[ $count -lt 3 ]]; then
        echo "Error: URI must have at least project/env/key: $uri" >&2
        return 1
    fi

    URI_PROJECT="${parts[0]}"
    URI_ENV="${parts[1]}"
    URI_KEY="${parts[$((count - 1))]}"

    # Everything between env and key is the folder path
    if [[ $count -gt 3 ]]; then
        URI_PATH="/"
        for ((i = 2; i < count - 1; i++)); do
            URI_PATH+="${parts[$i]}/"
        done
        # Remove trailing slash
        URI_PATH="${URI_PATH%/}"
    else
        URI_PATH="/"
    fi
}

# --- Resolve project slug to ID ---
resolve_project_id() {
    local slug="$1"

    # Check if projects mapping file exists
    if [[ -f "$PROJECTS_FILE" ]]; then
        if command -v jq &>/dev/null; then
            local project_id
            project_id=$(jq -r ".projects[\"$slug\"].id // empty" "$PROJECTS_FILE" 2>/dev/null)
            if [[ -n "$project_id" ]]; then
                echo "$project_id"
                return 0
            fi
        fi
    fi

    # Fallback: check if slug is already a project ID (UUID-like)
    if [[ "$slug" =~ ^[0-9a-f-]{36}$ ]]; then
        echo "$slug"
        return 0
    fi

    # Fallback: check env var INFISICAL_PROJECT_ID_<SLUG> (uppercased, dashes to underscores)
    local env_var="INFISICAL_PROJECT_ID_$(echo "$slug" | tr '[:lower:]-' '[:upper:]_')"
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return 0
    fi

    # Legacy fallback: single project from satellite .env
    if [[ -f "$SATELLITE_ENV" ]]; then
        local legacy_id
        legacy_id=$(grep "^INFISICAL_PROJECT_ID=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$legacy_id" ]]; then
            echo "$legacy_id"
            return 0
        fi
    fi

    echo "Error: Cannot resolve project slug '$slug' to ID" >&2
    echo "Ensure $PROJECTS_FILE exists with a mapping for '$slug'" >&2
    return 1
}

# --- Fetch from Infisical ---
fetch_from_infisical() {
    local project_id="$1"
    local env_slug="$2"
    local folder_path="$3"
    local key="$4"
    local auth_method="${5:-}"

    if ! command -v infisical &>/dev/null; then
        return 1
    fi

    # Build command args
    local args=("secrets" "get" "$key" "--projectId" "$project_id" "--env" "$env_slug" "--plain")

    # Add folder path if not root
    if [[ "$folder_path" != "/" ]]; then
        args+=("--path" "$folder_path")
    fi

    # Handle auth method
    if [[ "$auth_method" == "universal-auth" ]]; then
        # Machine identity auth - credentials should be in env
        if [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" ]]; then
            # Try loading from vault
            if [[ -f "$VAULT_FILE" && -f "$AGE_KEY" ]]; then
                local client_id client_secret
                client_id=$(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null | grep "^INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=" | cut -d'=' -f2- | head -1 || true)
                client_secret=$(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null | grep "^INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=" | cut -d'=' -f2- | head -1 || true)
                if [[ -n "$client_id" && -n "$client_secret" ]]; then
                    export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="$client_id"
                    export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="$client_secret"
                fi
            fi
        fi
    fi

    infisical "${args[@]}" 2>/dev/null
}

# --- Vault fallback ---
vault_fallback() {
    local key="$1"

    if [[ ! -f "$VAULT_FILE" || ! -f "$AGE_KEY" ]]; then
        return 1
    fi

    local value
    value=$(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null | grep "^${key}=" | cut -d'=' -f2- | head -1 || true)
    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi
    return 1
}

# --- Main ---
URI=""
PROJECT=""
ENV_SLUG=""
FOLDER_PATH=""
KEY=""
AUTH_METHOD=""
QUIET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --uri)
            URI="$2"; shift 2 ;;
        --project)
            PROJECT="$2"; shift 2 ;;
        --env)
            ENV_SLUG="$2"; shift 2 ;;
        --path)
            FOLDER_PATH="$2"; shift 2 ;;
        --key)
            KEY="$2"; shift 2 ;;
        --method)
            AUTH_METHOD="$2"; shift 2 ;;
        --quiet|-q)
            QUIET=true; shift ;;
        -h|--help)
            echo "Usage: resolve-secret-ref.sh [--uri URI | --project SLUG --env ENV --path PATH --key KEY] [--method AUTH] [--quiet]"
            echo ""
            echo "URI format: infisical://PROJECT_SLUG/ENV/FOLDER.../KEY"
            echo ""
            echo "Examples:"
            echo "  resolve-secret-ref.sh 'infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN'"
            echo "  resolve-secret-ref.sh --project admin-operator --env prod --path /providers/hetzner --key HCLOUD_TOKEN"
            echo "  resolve-secret-ref.sh --method universal-auth --uri 'infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN'"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2; exit 1 ;;
        *)
            # Positional: treat as URI
            URI="$1"; shift ;;
    esac
done

# Parse URI if provided
if [[ -n "$URI" ]]; then
    parse_uri "$URI"
    PROJECT="$URI_PROJECT"
    ENV_SLUG="$URI_ENV"
    FOLDER_PATH="$URI_PATH"
    KEY="$URI_KEY"
fi

# Validate required fields
if [[ -z "$PROJECT" || -z "$KEY" ]]; then
    echo "Error: Must provide either a URI or --project + --key" >&2
    exit 1
fi

ENV_SLUG="${ENV_SLUG:-prod}"
FOLDER_PATH="${FOLDER_PATH:-/}"

# Resolve project slug to ID
project_id=""
project_id=$(resolve_project_id "$PROJECT") || true

# Try Infisical first
if [[ -n "$project_id" ]]; then
    value=$(fetch_from_infisical "$project_id" "$ENV_SLUG" "$FOLDER_PATH" "$KEY" "$AUTH_METHOD" 2>/dev/null || true)
    if [[ -n "$value" ]]; then
        echo "$value"
        exit 0
    fi
    if [[ "$QUIET" != "true" ]]; then
        echo "Warning: Infisical lookup failed, trying vault fallback" >&2
    fi
fi

# Vault fallback
value=$(vault_fallback "$KEY" || true)
if [[ -n "$value" ]]; then
    echo "$value"
    exit 0
fi

echo "Error: Secret '$KEY' not found in Infisical (project: $PROJECT, env: $ENV_SLUG, path: $FOLDER_PATH) or vault" >&2
exit 1
