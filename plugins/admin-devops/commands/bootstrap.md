---
name: bootstrap
description: Bootstrap admin-devops plugin on a fresh machine - install plugin, create profile, configure secrets
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "[--headless] [--admin-root PATH] [--pkg-mgr MGR] [--remote user@host]"
---

# /bootstrap Command

One-command setup for the admin-devops plugin on a fresh machine (local or remote Linux).

Handles: plugin installation, profile creation, and secrets backend configuration.

## Modes

### Interactive (default)

Runs TUI interview to gather preferences, then creates profile.

```
/bootstrap
```

### Headless (for remote/automated installs)

Skips all prompts, uses sensible defaults or explicit flags.

```
/bootstrap --headless
/bootstrap --headless --admin-root /home/deploy/.admin --pkg-mgr apt
```

### Remote (SSH to target, bootstrap there)

Bootstraps a remote machine by SSHing in and running setup.

```
/bootstrap --remote user@192.168.1.50
/bootstrap --remote root@kasm-htz-02 --headless
```

## Workflow

### Step 1: Detect Environment

Determine if running locally or targeting a remote host.

**If `--remote` specified:**
1. Test SSH connectivity: `ssh -o ConnectTimeout=5 USER@HOST 'echo ok'`
2. If SSH fails, halt with connection troubleshooting advice
3. Detect remote platform: `ssh USER@HOST 'uname -s && cat /etc/os-release 2>/dev/null'`
4. Check if Claude Code is installed remotely: `ssh USER@HOST 'command -v claude'`

**If local:**
1. Detect platform (same as test-admin-profile.sh logic)
2. Check if Claude Code is installed: `command -v claude`

### Step 2: Install Claude Code (if missing)

If Claude Code CLI is not found, offer to install it:

**Interactive:** Ask "Claude Code is not installed. Install it now?"

**Headless:** Install automatically.

```bash
# npm global install (most portable)
npm install -g @anthropic-ai/claude-code
```

If npm is not available, try:
```bash
# Direct install
curl -fsSL https://claude.ai/install.sh | sh
```

### Step 3: Install The Library

Check if The Library skill is installed at `~/.claude/skills/library/`.

```bash
if [[ ! -f ~/.claude/skills/library/SKILL.md ]]; then
    git clone git@github.com:evolv3ai/the-library.git ~/.claude/skills/library/ 2>/dev/null || \
      git clone https://github.com/evolv3ai/the-library.git ~/.claude/skills/library/
fi
```

### Step 4: Install Plugin

Check if the admin-devops plugin is registered with Claude Code.

```bash
# Check installed plugins
grep -q "admin-devops" ~/.claude/plugins/installed_plugins.json 2>/dev/null
```

**If not installed — clone and register:**

```bash
git clone git@github.com:evolv3ai/vibe-skills.git ~/dev/vibe-skills 2>/dev/null || \
  git clone https://github.com/evolv3ai/vibe-skills.git ~/dev/vibe-skills
claude plugin add ~/dev/vibe-skills/plugins/admin-devops
```

### Step 5: Create Profile (MUST come before reconcile)

**Interactive mode:** Proceed like `/setup-profile` (TUI interview).

**Headless mode:**

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/new-admin-profile.sh" \
  --admin-root "${ADMIN_ROOT:-$HOME/.admin}" \
  --pkg-mgr "${PKG_MGR:-apt}" \
  --py-mgr "${PY_MGR:-uv}" \
  --node-mgr "${NODE_MGR:-npm}" \
  --shell-default "${SHELL_DEFAULT:-bash}" \
  --run-inventory \
  --force
```

The profile must exist before reconcile (Step 6) because reconcile reads `consumer.type` from the profile.

### Step 6: Reconcile Library

Determine what this device needs based on its consumer type and trust boundary:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/reconcile-library.sh" --json
```

Returns a JSON array of `{name, type, action, installPolicy}`. For each entry with `action: "should_install"`, run `/library use <name>`. The post-use hook writes bindings into the profile.

### Step 7: Configure Secrets Backend

**Interactive:** Ask which secrets backend to use.

**Headless:** Use `vault` as default unless `--secrets-backend` flag is provided.

### Step 8: Render Runtime

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/render-runtime.sh" --skip-unresolvable
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/render-mcp-config.sh" --skip-unresolvable
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/generate-agents-md.sh"
```

The `--skip-unresolvable` flag allows bootstrap to complete even before Infisical is configured. Unresolved secrets are marked as pending.

### Step 9: Verify Installation

Run the profile gate to confirm everything works:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/admin/scripts/test-admin-profile.sh"
```

Expected output: `{"exists":true,"device":"...","adminRoot":"...","platform":"..."}`

### Step 10: Report

**Success:**
```
Bootstrap Complete
══════════════════════════

  Plugin:      admin-devops (installed at ~/dev/vibe-skills/plugins/admin-devops)
  Profile:     ~/.admin/profiles/HOSTNAME.json
  Platform:    linux (Ubuntu 24.04)
  Secrets:     vault (age-encrypted)
  Tools found: git, node, python, docker, ssh

  Next steps:
  - Test: /install jq
  - View profile: /setup-profile
  - Provision a server: /provision
```

**Failure:**
```
Bootstrap Failed
══════════════════════════

  Step failed: Install Claude Code
  Error:       npm not found and curl install failed
  Fix:         Install Node.js first: sudo apt install -y nodejs npm
               Then retry: /bootstrap
```

## Remote Bootstrap Workflow

For remote machines (KASM runtimes, customer PCs), the full remote workflow:

```
/bootstrap --remote root@kasm-htz-02 --headless --pkg-mgr apt
```

This:
1. SSH to target
2. Install Claude Code (if missing)
3. Clone vibe-skills repo
4. Register admin-devops plugin
5. Create profile with headless defaults
6. Configure vault as secrets backend
7. Report results

For machines that need Infisical machine identity access:
```
/bootstrap --remote deploy@customer-pc --headless --secrets-backend infisical --machine-identity customer-larrysinteriors-pc
```

## Flag Reference

| Flag | Default | Description |
|------|---------|-------------|
| `--headless` | false | Skip all TUI prompts, use defaults |
| `--remote USER@HOST` | (local) | SSH to target machine |
| `--admin-root PATH` | `$HOME/.admin` | Admin root directory |
| `--pkg-mgr MGR` | auto-detect | Package manager: apt, brew, dnf |
| `--py-mgr MGR` | uv | Python manager: uv, pip, conda |
| `--node-mgr MGR` | npm | Node manager: npm, pnpm, yarn |
| `--shell-default SH` | auto-detect | Default shell |
| `--secrets-backend` | vault | Secrets backend: vault, infisical, env |
| `--machine-identity ID` | (none) | Infisical machine identity name |
| `--skip-claude-install` | false | Don't install Claude Code CLI |
| `--skip-profile` | false | Don't create profile (plugin only) |
| `--force` | false | Overwrite existing profile |

## Error Handling

- **SSH connection failed**: Show connection command, suggest key setup
- **Git clone failed**: Try HTTPS fallback, check network
- **npm not found**: Suggest installing Node.js first
- **Claude Code install failed**: Show manual install instructions
- **Profile already exists**: Skip unless `--force` (headless) or ask (interactive)
- **Permission denied**: Suggest `sudo` or correct directory permissions
