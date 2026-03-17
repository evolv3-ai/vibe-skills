#!/usr/bin/env bash
# =============================================================================
# Render Secret File - Retrieve JSON blob from Infisical, write to file
# =============================================================================
# Fetches a base64-encoded JSON credential from Infisical and writes it
# to a local file with proper permissions.
#
# Usage:
#   render-secret-file.sh "infisical://admin-operator/prod/files/gcloud/ADC_KEY" /path/to/output.json
#   render-secret-file.sh --uri URI --output PATH [--mode 0600]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URI=""
OUTPUT=""
MODE="0600"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --uri) URI="$2"; shift 2 ;;
        --output|-o) OUTPUT="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: render-secret-file.sh [--uri] URI --output PATH [--mode 0600]"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2; exit 1 ;;
        *)
            if [[ -z "$URI" ]]; then URI="$1"
            elif [[ -z "$OUTPUT" ]]; then OUTPUT="$1"
            else echo "Error: Too many positional args" >&2; exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$URI" || -z "$OUTPUT" ]]; then
    echo "Usage: render-secret-file.sh URI OUTPUT_PATH [--mode 0600]" >&2
    exit 1
fi

# Resolve the secret (base64-encoded)
encoded=$("$SCRIPT_DIR/resolve-secret-ref.sh" "$URI" 2>/dev/null)
if [[ -z "$encoded" ]]; then
    echo "Error: Could not resolve secret from $URI" >&2
    exit 1
fi

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT")"

# Decode and write
echo "$encoded" | base64 -d > "$OUTPUT" 2>/dev/null || echo "$encoded" | base64 -D > "$OUTPUT" 2>/dev/null

# Set permissions
chmod "$MODE" "$OUTPUT"

echo "Rendered: $OUTPUT (mode: $MODE)"
