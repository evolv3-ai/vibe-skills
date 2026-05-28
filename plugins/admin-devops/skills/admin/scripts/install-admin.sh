#!/usr/bin/env bash
# =============================================================================
# Install Admin — Bootstrap admin-devops on a fresh machine
# =============================================================================
# Single-command entrypoint for provisioning the full admin-devops stack.
# Designed for: curl -fsSL <url>/install-admin.sh | bash
#
# Usage:
#   ./install-admin.sh [OPTIONS]
#   curl -fsSL https://raw.githubusercontent.com/evolv3-ai/vibe-skills/main/plugins/admin-devops/skills/admin/scripts/install-admin.sh | bash
#
# Options:
#   --skip-claude-code       Don't install Claude Code CLI (already present)
#   --vibe-skills-path PATH  Use existing vibe-skills clone instead of cloning
#   --quiet                  Structured one-line-per-step output for CI
#   --force                  Overwrite existing profile
#   -h, --help               Show this help
#
# Environment:
#   INFISICAL_TOKEN          If set, configures Infisical secrets backend
#
# The script is idempotent — running it twice won't break anything.
# =============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Output helpers — quiet mode produces structured [OK]/[SKIP]/[FAIL] for CI
step_ok()   { if [[ "$QUIET" == "true" ]]; then echo "[OK] $1"; else echo -e "${GREEN}✓${NC} $1"; fi; }
step_skip() { if [[ "$QUIET" == "true" ]]; then echo "[SKIP] $1"; else echo -e "${YELLOW}⊘${NC} $1"; fi; }
step_fail() { if [[ "$QUIET" == "true" ]]; then echo "[FAIL] $1"; else echo -e "${RED}✗${NC} $1"; fi; exit 1; }
section()   { if [[ "$QUIET" != "true" ]]; then echo -e "\n${CYAN}=== $1 ===${NC}"; fi; }

# Defaults
SKIP_CLAUDE_CODE=false
VIBE_SKILLS_PATH=""
QUIET=false
FORCE=false
INTERACTIVE=true
[[ ! -t 0 ]] && INTERACTIVE=false  # pipe detection for: curl | bash

# Argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-claude-code)
            SKIP_CLAUDE_CODE=true
            shift
            ;;
        --vibe-skills-path)
            VIBE_SKILLS_PATH="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            head -28 "$0" | tail -22
            exit 0
            ;;
        *)
            step_fail "Unknown option: $1"
            ;;
    esac
done

# =============================================================================
# Step 1: Detect OS
# =============================================================================
section "Step 1: Detect OS"

case "$OSTYPE" in
    linux*)  OS="linux" ;;
    darwin*) OS="macos" ;;
    *)       step_fail "Step 1: Unsupported OS: $OSTYPE (Linux and macOS only)" ;;
esac
step_ok "OS: $OS ($(uname -m))"

# =============================================================================
# Step 2: Prerequisites — curl, git, node >= 18
# =============================================================================
section "Step 2: Prerequisites"

# curl
if ! command -v curl &>/dev/null; then
    if [[ "$OS" == "linux" ]]; then
        sudo apt-get update -qq && sudo apt-get install -y -qq curl \
            || step_fail "Step 2: Failed to install curl"
    else
        step_fail "Step 2: curl not found. Install it manually and retry."
    fi
fi
step_ok "curl: $(curl --version 2>/dev/null | head -1 | awk '{print $2}')"

# git
if ! command -v git &>/dev/null; then
    if [[ "$OS" == "linux" ]]; then
        sudo apt-get update -qq && sudo apt-get install -y -qq git \
            || step_fail "Step 2: Failed to install git"
    elif [[ "$OS" == "macos" ]]; then
        xcode-select --install 2>/dev/null || true  # triggers git install on macOS
        sleep 3  # give the dialog a moment
    fi
fi
command -v git &>/dev/null || step_fail "Step 2: git not found after install attempt"
step_ok "git: $(git --version | awk '{print $3}')"

# node — require >= 18; apt's default is too old, install via NodeSource
NODE_MIN=18
NEED_NODE=false
if ! command -v node &>/dev/null; then
    NEED_NODE=true
elif [[ $(node -v 2>/dev/null | tr -d 'v' | cut -d. -f1) -lt $NODE_MIN ]]; then
    NEED_NODE=true
fi

if [[ "$NEED_NODE" == "true" ]]; then
    if [[ "$OS" == "linux" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - 2>/dev/null \
            || step_fail "Step 2: NodeSource setup failed"
        sudo apt-get install -y -qq nodejs \
            || step_fail "Step 2: Failed to install nodejs"
    elif [[ "$OS" == "macos" ]]; then
        if command -v brew &>/dev/null; then
            brew install node || step_fail "Step 2: Failed to install node via brew"
        else
            step_fail "Step 2: Node.js >= $NODE_MIN required. Install Homebrew first, or install Node manually from https://nodejs.org"
        fi
    fi
fi
step_ok "node: $(node -v)"

# =============================================================================
# Step 3: Claude Code CLI
# =============================================================================
section "Step 3: Claude Code CLI"

if [[ "$SKIP_CLAUDE_CODE" == "true" ]]; then
    step_skip "Claude Code CLI (--skip-claude-code)"
elif command -v claude &>/dev/null; then
    step_skip "Claude Code CLI already installed: $(claude --version 2>/dev/null | tail -1)"
else
    npm install -g @anthropic-ai/claude-code 2>/dev/null \
        || step_fail "Step 3: Failed to install Claude Code CLI"
    step_ok "Claude Code CLI installed: $(claude --version 2>/dev/null | tail -1)"
fi

# =============================================================================
# Step 4: Clone vibe-skills
# =============================================================================
section "Step 4: Clone vibe-skills"

if [[ -n "$VIBE_SKILLS_PATH" ]]; then
    VIBE_SKILLS_PATH="$(realpath "$VIBE_SKILLS_PATH" 2>/dev/null || echo "$VIBE_SKILLS_PATH")"
    if [[ ! -d "$VIBE_SKILLS_PATH" ]]; then
        step_fail "Step 4: --vibe-skills-path '$VIBE_SKILLS_PATH' does not exist"
    fi
    # Validate it's actually a vibe-skills clone
    if [[ ! -f "$VIBE_SKILLS_PATH/plugins/admin-devops/skills/admin/scripts/new-admin-profile.sh" ]]; then
        step_fail "Step 4: --vibe-skills-path '$VIBE_SKILLS_PATH' is not a valid vibe-skills clone (missing admin-devops plugin)"
    fi
    VIBE_SKILLS="$VIBE_SKILLS_PATH"
    step_skip "Using existing clone: $VIBE_SKILLS"
elif [[ -d "$HOME/dev/vibe-skills/.git" ]]; then
    VIBE_SKILLS="$HOME/dev/vibe-skills"
    step_skip "vibe-skills already cloned: $VIBE_SKILLS"
else
    mkdir -p "$HOME/dev"
    git clone https://github.com/evolv3-ai/vibe-skills.git "$HOME/dev/vibe-skills" \
        || step_fail "Step 4: Failed to clone vibe-skills"
    VIBE_SKILLS="$HOME/dev/vibe-skills"
    step_ok "Cloned vibe-skills to $VIBE_SKILLS"
fi

ADMIN_SCRIPTS="$VIBE_SKILLS/plugins/admin-devops/skills/admin/scripts"

# Ensure required scripts are executable
chmod +x "$ADMIN_SCRIPTS/new-admin-profile.sh" \
         "$ADMIN_SCRIPTS/reconcile-library.sh" \
         "$ADMIN_SCRIPTS/render-mcp-config.sh" \
         "$ADMIN_SCRIPTS/library-post-use-hook.sh" 2>/dev/null || true

# =============================================================================
# Step 5: Register admin-devops plugin
# =============================================================================
section "Step 5: Register admin-devops plugin"

INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"

if [[ -f "$INSTALLED_FILE" ]] && grep -q '"admin-devops"' "$INSTALLED_FILE" 2>/dev/null; then
    step_skip "admin-devops plugin already registered"
elif command -v claude &>/dev/null; then
    # Register the vibe-skills marketplace (idempotent — silently skips if already registered)
    claude plugin marketplace add evolv3-ai/vibe-skills 2>/dev/null || true
    claude plugin install admin-devops@vibe-skills 2>/dev/null \
        || step_fail "Step 5: Failed to register admin-devops plugin"
    step_ok "admin-devops plugin registered"
else
    step_skip "Claude Code not available — plugin registration deferred"
fi

# =============================================================================
# Step 6: Create admin profile
# =============================================================================
section "Step 6: Create admin profile"

PROFILE_ARGS=(--headless --preset ubuntu --run-inventory)
[[ "$FORCE" == "true" ]] && PROFILE_ARGS+=(--force)

"$ADMIN_SCRIPTS/new-admin-profile.sh" "${PROFILE_ARGS[@]}" \
    || step_fail "Step 6: Profile creation failed"
step_ok "Admin profile created: ~/.admin/profiles/$(hostname).json"

# =============================================================================
# Step 7: Library setup
# =============================================================================
section "Step 7: Library setup"

LIBRARY_DIR="$HOME/.claude/skills/library"

if [[ -d "$LIBRARY_DIR/.git" ]]; then
    step_skip "Library already cloned: $LIBRARY_DIR"
else
    mkdir -p "$(dirname "$LIBRARY_DIR")"
    git clone https://github.com/evolv3-ai/library.git "$LIBRARY_DIR" \
        || step_fail "Step 7: Failed to clone library"
    step_ok "Library cloned to $LIBRARY_DIR"
fi

# Wire post-use hook if not already linked
HOOK_DIR="$LIBRARY_DIR/hooks"
HOOK_TARGET="$ADMIN_SCRIPTS/library-post-use-hook.sh"
if [[ ! -d "$HOOK_DIR" ]]; then
    mkdir -p "$HOOK_DIR"
fi
if [[ ! -f "$HOOK_DIR/post-use.sh" && -f "$HOOK_TARGET" ]]; then
    ln -sf "$HOOK_TARGET" "$HOOK_DIR/post-use.sh"
    step_ok "Library post-use hook linked"
elif [[ -f "$HOOK_DIR/post-use.sh" ]]; then
    step_skip "Library post-use hook already linked"
fi

# Run reconcile — produces JSON to stdout, human table to stderr
if [[ -x "$ADMIN_SCRIPTS/reconcile-library.sh" ]]; then
    DRIFT=$("$ADMIN_SCRIPTS/reconcile-library.sh" --json 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
drift=[x for x in data if x['action']=='should_install']
if drift: print(str(len(drift))+' entries need binding: '+', '.join(x['name']+'('+x['type']+')' for x in drift))
" 2>/dev/null || true)
    if [[ -n "$DRIFT" ]]; then
        step_skip "Library reconcile: $DRIFT — run '/library use <name>' per entry"
    else
        step_ok "Library reconcile: all eligible entries bound"
    fi
else
    step_skip "reconcile-library.sh not found"
fi

# =============================================================================
# Step 8: Render MCP config
# =============================================================================
section "Step 8: Render MCP config"

if [[ -x "$ADMIN_SCRIPTS/render-mcp-config.sh" ]]; then
    if "$ADMIN_SCRIPTS/render-mcp-config.sh" --skip-unresolvable 2>/dev/null; then
        step_ok "MCP config rendered to ~/.claude/.mcp.json"
    else
        step_skip "Step 8: MCP render had warnings (expected before secrets are configured)"
    fi
else
    step_skip "render-mcp-config.sh not found"
fi

# =============================================================================
# Step 9: Infisical credentials (optional)
# =============================================================================
section "Step 9: Infisical credentials"

if [[ -n "${INFISICAL_TOKEN:-}" ]]; then
    if [[ -x "$ADMIN_SCRIPTS/infisical-bootstrap.sh" ]]; then
        "$ADMIN_SCRIPTS/infisical-bootstrap.sh" 2>/dev/null \
            || step_fail "Step 9: Infisical bootstrap failed"
        step_ok "Infisical 3-project hierarchy created"
    else
        step_skip "infisical-bootstrap.sh not found"
    fi
else
    step_skip "Infisical — \$INFISICAL_TOKEN not set. To configure: export INFISICAL_TOKEN=<token> and re-run, or use /bootstrap step 7b"
fi

# =============================================================================
# Step 10: Summary
# =============================================================================
section "Install Complete"

echo ""
if [[ "$QUIET" != "true" ]]; then
    echo -e "${GREEN}Admin-devops stack is ready.${NC}"
    echo ""
    echo "  Profile:     ~/.admin/profiles/$(hostname).json"
    echo "  Library:     $LIBRARY_DIR"
    echo "  MCP config:  ~/.claude/.mcp.json"
    echo "  Vibe-skills: $VIBE_SKILLS"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'claude' to start Claude Code with admin-devops loaded"
    echo "  2. Try '/bootstrap' to see the full bootstrap workflow"
    echo "  3. Run '/library list' to see available skills and MCP servers"
    if [[ -z "${INFISICAL_TOKEN:-}" ]]; then
        echo "  4. Configure secrets: export INFISICAL_TOKEN=<token> then re-run, or use '/bootstrap step 7b'"
    fi
    echo ""
else
    echo "[OK] install-admin complete"
fi
