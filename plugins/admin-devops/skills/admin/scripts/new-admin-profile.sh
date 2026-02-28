#!/usr/bin/env bash
# =============================================================================
# New Admin Profile - Create profile (non-interactive, parameter-driven)
# =============================================================================
# Creates the Admin profile and directory structure based on provided parameters.
# Designed to be called by an AI agent after gathering preferences via TUI.
# No interactive prompts - all options passed as parameters.
#
# Usage:
#   ./new-admin-profile.sh [OPTIONS]
#
# Options:
#   -a, --admin-root PATH    Path to .admin directory (default: ~/.admin)
#   -m, --multi-device       Multi-device setup (cloud-synced storage)
#   -p, --pkg-mgr MGR        Package manager: brew/apt/dnf/pacman (default: auto-detect)
#   --win-pkg-mgr MGR        Windows package manager (WSL only): winget/scoop/choco (default: auto-detect)
#   --py-mgr MGR             Python manager: uv/pip/conda/poetry (default: uv)
#   -n, --node-mgr MGR       Node manager: npm/pnpm/yarn/bun (default: npm)
#   -s, --shell-default SH   Default shell: bash/zsh/fish (default: $SHELL)
#   -i, --run-inventory      Run tool inventory scan
#   -f, --force              Overwrite existing profile
#   -h, --help               Show this help
#
# Examples:
#   ./new-admin-profile.sh --run-inventory
#   ./new-admin-profile.sh --admin-root ~/Dropbox/.admin --multi-device --pkg-mgr brew
#   ./new-admin-profile.sh --admin-root "N:\Dropbox\08_Admin" --multi-device --win-pkg-mgr winget
# =============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

info() { echo -e "${GRAY}[i]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# Translate Windows paths to WSL paths (e.g., N:\Dropbox\08_Admin → /mnt/n/Dropbox/08_Admin)
# Only transforms on WSL; passthrough on other platforms.
translate_path() {
    local input_path="$1"

    # Only translate on WSL
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        echo "$input_path"
        return
    fi

    # Already a Unix path - no translation needed
    if [[ "$input_path" == /* ]]; then
        echo "$input_path"
        return
    fi

    # Try wslpath first (most reliable)
    if command -v wslpath &>/dev/null; then
        local translated
        translated=$(wslpath -u "$input_path" 2>/dev/null)
        if [[ $? -eq 0 && -n "$translated" ]]; then
            echo "$translated"
            return
        fi
    fi

    # Manual fallback: D:\Foo\Bar → /mnt/d/Foo/Bar
    if [[ "$input_path" =~ ^([A-Za-z]):[/\\] ]]; then
        local drive=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
        local rest="${input_path:2}"
        rest="${rest//\\//}"
        echo "/mnt/${drive}${rest}"
        return
    fi

    # Not a Windows path - return as-is
    echo "$input_path"
}

# Defaults
ADMIN_ROOT=""
MULTI_DEVICE=false
PKG_MGR=""
WIN_PKG_MGR=""
PY_MGR="uv"
NODE_MGR="npm"
SHELL_DEFAULT=""
RUN_INVENTORY=false
FORCE=false

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="${SKILL_ROOT}/VERSION"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--admin-root)
            ADMIN_ROOT="$2"
            shift 2
            ;;
        -m|--multi-device)
            MULTI_DEVICE=true
            shift
            ;;
        -p|--pkg-mgr)
            PKG_MGR="$2"
            shift 2
            ;;
        --win-pkg-mgr)
            WIN_PKG_MGR="$2"
            shift 2
            ;;
        --py-mgr)
            PY_MGR="$2"
            shift 2
            ;;
        -n|--node-mgr)
            NODE_MGR="$2"
            shift 2
            ;;
        -s|--shell-default)
            SHELL_DEFAULT="$2"
            shift 2
            ;;
        -i|--run-inventory)
            RUN_INVENTORY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            head -36 "$0" | tail -30
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Detect platform
detect_platform() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        echo "linux"
    else
        echo "unix"
    fi
}

PLATFORM=$(detect_platform)

# Detect Windows username from WSL (multiple fallback methods)
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

# --admin-root takes precedence over all auto-detection
if [[ -z "$ADMIN_ROOT" ]]; then
    if [[ "$PLATFORM" == "wsl" ]]; then
        # WSL: Use Windows user's home
        WIN_USER=$(detect_win_user)
        if [[ -n "$WIN_USER" ]]; then
            ADMIN_ROOT="/mnt/c/Users/$WIN_USER/.admin"
        else
            warn "Could not detect Windows username. Falling back to \$HOME/.admin"
            ADMIN_ROOT="${HOME}/.admin"
        fi
    else
        ADMIN_ROOT="${HOME}/.admin"
    fi
fi

# Translate Windows paths to WSL-compatible paths
ADMIN_ROOT=$(translate_path "$ADMIN_ROOT")

if [[ -z "$PKG_MGR" ]]; then
    case "$PLATFORM" in
        macos) PKG_MGR="brew" ;;
        wsl|linux)
            if command -v apt &>/dev/null; then PKG_MGR="apt"
            elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
            elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
            else PKG_MGR="apt"
            fi
            ;;
        *) PKG_MGR="apt" ;;
    esac
fi

# WSL: auto-detect Windows-side package manager if not specified
if [[ "$PLATFORM" == "wsl" && -z "$WIN_PKG_MGR" ]]; then
    if command -v winget.exe &>/dev/null; then WIN_PKG_MGR="winget"
    elif command -v scoop &>/dev/null || command -v scoop.exe &>/dev/null; then WIN_PKG_MGR="scoop"
    elif command -v choco.exe &>/dev/null; then WIN_PKG_MGR="choco"
    fi
fi

if [[ -z "$SHELL_DEFAULT" ]]; then
    SHELL_DEFAULT=$(basename "$SHELL")
fi

# Read version
ADMIN_SKILL_VERSION="0.1.0"
if [[ -f "$VERSION_FILE" ]]; then
    ADMIN_SKILL_VERSION=$(head -1 "$VERSION_FILE" | tr -d '[:space:]')
fi

# Read sibling skill VERSION files for skillVersions tracking
SKILLS_ROOT="$(dirname "$SKILL_ROOT")"
SIBLING_SKILLS=("admin" "devops" "oci" "hetzner" "contabo" "digital-ocean" "vultr" "linode" "coolify" "kasm")
SKILL_VERSIONS_JSON="{"
first_sv=true
for skill_name in "${SIBLING_SKILLS[@]}"; do
    ver_file="${SKILLS_ROOT}/${skill_name}/VERSION"
    ver="unknown"
    if [[ -f "$ver_file" ]]; then
        ver=$(head -1 "$ver_file" | tr -d '[:space:]')
    fi
    if [[ "$first_sv" == "true" ]]; then first_sv=false; else SKILL_VERSIONS_JSON+=","; fi
    SKILL_VERSIONS_JSON+="\"${skill_name}\":\"${ver}\""
done
SKILL_VERSIONS_JSON+="}"

DEVICE_NAME=$(hostname)
PROFILE_PATH="${ADMIN_ROOT}/profiles/${DEVICE_NAME}.json"

section "New Admin Profile"
echo "Device:      $DEVICE_NAME"
echo "AdminRoot:   $ADMIN_ROOT"
echo "Platform:    $PLATFORM"
echo "MultiDevice: $MULTI_DEVICE"

# Check existing profile
if [[ -f "$PROFILE_PATH" && "$FORCE" != "true" ]]; then
    warn "Profile already exists: $PROFILE_PATH"
    echo "Use --force to overwrite"
    echo '{"success":false,"error":"profile_exists","path":"'"$PROFILE_PATH"'","message":"Profile already exists. Use --force to overwrite."}'
    exit 1
fi

# Create directories
section "Creating Directories"
DIRS=(
    "$ADMIN_ROOT"
    "$ADMIN_ROOT/profiles"
    "$ADMIN_ROOT/logs"
    "$ADMIN_ROOT/logs/devices"
    "$ADMIN_ROOT/issues"
    "$ADMIN_ROOT/registries"
    "$ADMIN_ROOT/config"
    "$ADMIN_ROOT/backups"
    "$ADMIN_ROOT/scripts"
    "$ADMIN_ROOT/inbox"
)

for dir in "${DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        ok "Created: $dir"
    fi
done

# Gather system info
section "Detecting System"
OS_NAME="Unknown"
OS_VERSION=""
ARCH=$(uname -m)
CPU_INFO=""
RAM_GB=""

case "$PLATFORM" in
    macos)
        OS_NAME=$(sw_vers -productName 2>/dev/null || echo "macOS")
        OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "")
        CPU_INFO=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
        RAM_GB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
        ;;
    linux|wsl)
        if [[ -f /etc/os-release ]]; then
            OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
            OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
        fi
        CPU_INFO=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)
        RAM_GB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}') / 1048576 ))
        ;;
esac

ok "OS: $OS_NAME $OS_VERSION"
ok "CPU: $CPU_INFO"
ok "RAM: ${RAM_GB} GB"

# Initialize tool/package arrays
PKG_MANAGERS_JSON="{}"
TOOLS_JSON="{}"
CAPABILITIES_JSON="{}"

# Run inventory if requested
if [[ "$RUN_INVENTORY" == "true" ]]; then
    section "Running Inventory Scan"

    # Package managers
    declare -A PKG_MANAGERS

    # brew
    if command -v brew &>/dev/null; then
        BREW_VER=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
        PKG_MANAGERS["brew"]='{"present":true,"version":"'"$BREW_VER"'","path":"'"$(which brew)"'"}'
        ok "brew: $BREW_VER"
    fi

    # apt
    if command -v apt &>/dev/null; then
        APT_VER=$(apt --version 2>/dev/null | head -1 | awk '{print $2}')
        PKG_MANAGERS["apt"]='{"present":true,"version":"'"$APT_VER"'","path":"'"$(which apt)"'"}'
        ok "apt: $APT_VER"
    fi

    # npm
    if command -v npm &>/dev/null; then
        NPM_VER=$(npm --version 2>/dev/null)
        PKG_MANAGERS["npm"]='{"present":true,"version":"'"$NPM_VER"'","path":"'"$(which npm)"'"}'
        ok "npm: $NPM_VER"
    fi

    # pnpm
    if command -v pnpm &>/dev/null; then
        PNPM_VER=$(pnpm --version 2>/dev/null)
        PKG_MANAGERS["pnpm"]='{"present":true,"version":"'"$PNPM_VER"'","path":"'"$(which pnpm)"'"}'
        ok "pnpm: $PNPM_VER"
    fi

    # uv
    if command -v uv &>/dev/null; then
        UV_VER=$(uv --version 2>/dev/null | awk '{print $2}')
        PKG_MANAGERS["uv"]='{"present":true,"version":"'"$UV_VER"'","path":"'"$(which uv)"'"}'
        ok "uv: $UV_VER"
    fi

    # pip
    if command -v pip &>/dev/null; then
        PIP_VER=$(pip --version 2>/dev/null | awk '{print $2}')
        PKG_MANAGERS["pip"]='{"present":true,"version":"'"$PIP_VER"'","path":"'"$(which pip)"'"}'
        ok "pip: $PIP_VER"
    fi

    # Build package managers JSON
    PKG_MANAGERS_JSON="{"
    first=true
    for key in "${!PKG_MANAGERS[@]}"; do
        if [[ "$first" == "true" ]]; then first=false; else PKG_MANAGERS_JSON+=","; fi
        PKG_MANAGERS_JSON+='"'"$key"'":'"${PKG_MANAGERS[$key]}"
    done
    PKG_MANAGERS_JSON+="}"

    # Tools
    declare -A TOOLS

    # git
    if command -v git &>/dev/null; then
        GIT_VER=$(git --version 2>/dev/null | awk '{print $3}')
        TOOLS["git"]='{"present":true,"version":"'"$GIT_VER"'","path":"'"$(which git)"'"}'
        ok "git: $GIT_VER"
    fi

    # node
    if command -v node &>/dev/null; then
        NODE_VER=$(node --version 2>/dev/null | tr -d 'v')
        TOOLS["node"]='{"present":true,"version":"'"$NODE_VER"'","path":"'"$(which node)"'"}'
        ok "node: $NODE_VER"
    fi

    # python
    if command -v python3 &>/dev/null; then
        PYTHON_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
        TOOLS["python"]='{"present":true,"version":"'"$PYTHON_VER"'","path":"'"$(which python3)"'"}'
        ok "python: $PYTHON_VER"
    elif command -v python &>/dev/null; then
        PYTHON_VER=$(python --version 2>/dev/null | awk '{print $2}')
        TOOLS["python"]='{"present":true,"version":"'"$PYTHON_VER"'","path":"'"$(which python)"'"}'
        ok "python: $PYTHON_VER"
    fi

    # docker (validate output - WSL Docker Desktop shim can return error text)
    if command -v docker &>/dev/null; then
        DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        if [[ -n "$DOCKER_VER" && ! "$DOCKER_VER" =~ [[:space:]] && "$DOCKER_VER" =~ ^[0-9] ]]; then
            TOOLS["docker"]='{"present":true,"version":"'"$DOCKER_VER"'","path":"'"$(which docker)"'"}'
            CAPABILITIES_JSON='{"hasDocker":true,'
            ok "docker: $DOCKER_VER"
        else
            TOOLS["docker"]='{"present":false,"note":"docker found in PATH but not functional"}'
            CAPABILITIES_JSON='{"hasDocker":false,'
            warn "docker: found but not functional (WSL integration may be disabled)"
        fi
    else
        CAPABILITIES_JSON='{"hasDocker":false,'
    fi

    # ssh
    if command -v ssh &>/dev/null; then
        TOOLS["ssh"]='{"present":true,"path":"'"$(which ssh)"'"}'
        CAPABILITIES_JSON+='"hasSsh":true,'
        ok "ssh: available"
    else
        CAPABILITIES_JSON+='"hasSsh":false,'
    fi

    # claude
    if command -v claude &>/dev/null; then
        CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $NF}' | tr -d 'v')
        TOOLS["claude"]='{"present":true,"version":"'"$CLAUDE_VER"'","path":"'"$(which claude)"'"}'
        ok "claude: $CLAUDE_VER"
    fi

    CAPABILITIES_JSON+='"canRunBash":true}'

    # WSL: probe Windows-side package managers
    if [[ "$PLATFORM" == "wsl" ]]; then
        if command -v winget.exe &>/dev/null; then
            WINGET_VER=$(winget.exe --version 2>/dev/null | tr -d '\r\nv')
            PKG_MANAGERS["winget"]='{"present":true,"version":"'"$WINGET_VER"'","path":"winget.exe","side":"windows"}'
            ok "winget (win): $WINGET_VER"
        fi

        if command -v scoop &>/dev/null || command -v scoop.exe &>/dev/null; then
            PKG_MANAGERS["scoop"]='{"present":true,"side":"windows"}'
            ok "scoop (win): found"
        fi

        if command -v choco.exe &>/dev/null; then
            CHOCO_VER=$(choco.exe --version 2>/dev/null | tr -d '\r')
            PKG_MANAGERS["choco"]='{"present":true,"version":"'"$CHOCO_VER"'","path":"choco.exe","side":"windows"}'
            ok "choco (win): $CHOCO_VER"
        fi

        # Rebuild package managers JSON to include windows-side entries
        PKG_MANAGERS_JSON="{"
        first=true
        for key in "${!PKG_MANAGERS[@]}"; do
            if [[ "$first" == "true" ]]; then first=false; else PKG_MANAGERS_JSON+=","; fi
            PKG_MANAGERS_JSON+='"'"$key"'":'"${PKG_MANAGERS[$key]}"
        done
        PKG_MANAGERS_JSON+="}"
    fi

    # Build tools JSON
    TOOLS_JSON="{"
    first=true
    for key in "${!TOOLS[@]}"; do
        if [[ "$first" == "true" ]]; then first=false; else TOOLS_JSON+=","; fi
        TOOLS_JSON+='"'"$key"'":'"${TOOLS[$key]}"
    done
    TOOLS_JSON+="}"
else
    CAPABILITIES_JSON='{"hasDocker":false,"hasSsh":false,"canRunBash":true}'
fi

# Build preferences JSON
PREFERENCES_JSON='{"packages":{"manager":"'"$PKG_MGR"'"}'
if [[ -n "$WIN_PKG_MGR" ]]; then
    PREFERENCES_JSON+=',"winPackages":{"manager":"'"$WIN_PKG_MGR"'"}'
fi
PREFERENCES_JSON+=',"python":{"manager":"'"$PY_MGR"'"},"node":{"manager":"'"$NODE_MGR"'"},"shell":{"default":"'"$SHELL_DEFAULT"'"}}'

# Build profile JSON
section "Saving Profile"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$PROFILE_PATH" <<EOF
{
  "schemaVersion": "3.0",
  "adminSkillVersion": "$ADMIN_SKILL_VERSION",
  "multiDevice": $MULTI_DEVICE,
  "skillVersions": $SKILL_VERSIONS_JSON,
  "device": {
    "name": "$DEVICE_NAME",
    "platform": "$PLATFORM",
    "shell": "$SHELL_DEFAULT",
    "user": "$USER",
    "os": "$OS_NAME",
    "osVersion": "$OS_VERSION",
    "architecture": "$ARCH",
    "cpu": "$CPU_INFO",
    "ram": "${RAM_GB} GB",
    "timezone": "$(date +%Z)",
    "envType": "$PLATFORM",
    "created": "$TIMESTAMP",
    "lastUpdated": "$TIMESTAMP"
  },
  "paths": {
    "adminRoot": "$ADMIN_ROOT",
    "deviceProfile": "$PROFILE_PATH",
    "logs": "$ADMIN_ROOT/logs",
    "issuesDir": "$ADMIN_ROOT/issues",
    "registries": "$ADMIN_ROOT/registries",
    "config": "$ADMIN_ROOT/config",
    "backups": "$ADMIN_ROOT/backups",
    "scripts": "$ADMIN_ROOT/scripts",
    "inbox": "$ADMIN_ROOT/inbox",
    "mcpRegistry": "$ADMIN_ROOT/registries/mcp-registry.json",
    "skillsRegistry": "$ADMIN_ROOT/registries/skills-registry.json",
    "devopsRegistry": "$ADMIN_ROOT/registries/devops-registry.json"
  },
  "packageManagers": $PKG_MANAGERS_JSON,
  "tools": $TOOLS_JSON,
  "preferences": $PREFERENCES_JSON,
  "wsl": {},
  "docker": {},
  "mcp": {"servers": {}},
  "servers": [],
  "deployments": {},
  "issues": {"current": [], "resolved": []},
  "history": [
    {
      "date": "$TIMESTAMP",
      "action": "profile_create",
      "tool": "new-admin-profile.sh",
      "method": "tui-driven",
      "status": "success",
      "details": "Profile created via TUI interview"
    }
  ],
  "capabilities": $CAPABILITIES_JSON
}
EOF

ok "Profile: $PROFILE_PATH"

# Create/update ADMIN_ROOT .env (stores secrets, deployment refs)
ENV_FILE="$ADMIN_ROOT/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ADMIN_ROOT=$ADMIN_ROOT" > "$ENV_FILE"
else
    if grep -q "^ADMIN_ROOT=" "$ENV_FILE"; then
        sed -i.bak "s|^ADMIN_ROOT=.*|ADMIN_ROOT=$ADMIN_ROOT|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
        echo "ADMIN_ROOT=$ADMIN_ROOT" >> "$ENV_FILE"
    fi
fi

ok "ADMIN_ROOT .env updated: $ENV_FILE (ADMIN_ROOT only — device vars in satellite)"

# Write satellite .env to ~/.admin/.env
# This is the primary discovery mechanism for all scripts.
# On WSL: ~/.admin/ contains ONLY this .env (data lives at ADMIN_ROOT)
# On native: ~/.admin/.env may point to itself or to a network path
SATELLITE_DIR="${HOME}/.admin"
SATELLITE_ENV="${SATELLITE_DIR}/.env"
mkdir -p "$SATELLITE_DIR"
{
    echo "# Admin satellite config - points to centralized profile"
    echo "# Do not store secrets here. See \$ADMIN_ROOT/.env for credentials."
    echo "ADMIN_ROOT=$ADMIN_ROOT"
    echo "ADMIN_DEVICE=$DEVICE_NAME"
    echo "ADMIN_PLATFORM=$PLATFORM"
    echo ""
    echo "# Preferences (per-device, no JSON parsing needed)"
    echo "ADMIN_PKG_MGR=$PKG_MGR"
    [[ -n "$WIN_PKG_MGR" ]] && echo "ADMIN_WIN_PKG_MGR=$WIN_PKG_MGR"
    echo "ADMIN_PY_MGR=$PY_MGR"
    echo "ADMIN_NODE_MGR=$NODE_MGR"
    echo "ADMIN_SHELL=$SHELL_DEFAULT"
} > "$SATELLITE_ENV"
ok "Satellite .env written: $SATELLITE_ENV"

# Clean up legacy breadcrumb if it exists
[[ -f "${HOME}/.admin-root" ]] && rm -f "${HOME}/.admin-root"

# Export for current session
export ADMIN_ROOT="$ADMIN_ROOT"
export ADMIN_DEVICE="$DEVICE_NAME"
export ADMIN_PLATFORM="$PLATFORM"

# Copy AGENTS.md if exists
AGENTS_TEMPLATE="${SKILL_ROOT}/templates/AGENTS.md"
if [[ -f "$AGENTS_TEMPLATE" ]]; then
    cp "$AGENTS_TEMPLATE" "$ADMIN_ROOT/AGENTS.md"
    ok "AGENTS.md generated"
fi

# Summary
section "Profile Created Successfully"
echo -e "${GREEN}Profile:${NC}      $PROFILE_PATH"
echo -e "${GREEN}ADMIN_ROOT:${NC}   $ADMIN_ROOT"
echo -e "Multi-device: $MULTI_DEVICE"
echo ""
echo -e "${YELLOW}Preferences:${NC}"
echo "  Packages:     $PKG_MGR"
[[ -n "$WIN_PKG_MGR" ]] && echo "  Win packages: $WIN_PKG_MGR"
echo "  Python:       $PY_MGR"
echo "  Node:         $NODE_MGR"
echo "  Shell:        $SHELL_DEFAULT"
echo ""

# Output JSON for agent consumption
WIN_PKG_JSON=""
[[ -n "$WIN_PKG_MGR" ]] && WIN_PKG_JSON=',"winPackages":"'"$WIN_PKG_MGR"'"'
echo '{"success":true,"path":"'"$PROFILE_PATH"'","adminRoot":"'"$ADMIN_ROOT"'","device":"'"$DEVICE_NAME"'","preferences":{"packages":"'"$PKG_MGR"'"'"$WIN_PKG_JSON"',"python":"'"$PY_MGR"'","node":"'"$NODE_MGR"'","shell":"'"$SHELL_DEFAULT"'"}}'
