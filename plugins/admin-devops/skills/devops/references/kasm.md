# KASM Deployment

_Consolidated from `skills/kasm` on 2026-02-02_

## Skill Body

# KASM Workspaces - Container VDI

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Purpose**: Install KASM Workspaces on a single Ubuntu server and configure secure browser-based desktops.

## Step 0: Gather Required Information (MANDATORY)

**STOP. Before ANY installation commands, collect ALL parameters from the user.**

Copy this checklist and confirm each item:

```
Required Parameters:
- [ ] KASM_SERVER_IP       - Target server IP address
- [ ] SSH_USER             - SSH username (default: ubuntu)
- [ ] SSH_KEY_PATH         - Path to SSH private key (default: ~/.ssh/id_rsa)
- [ ] KASM_ADMIN_PASSWORD  - Admin password (minimum 12 characters)
- [ ] KASM_ADMIN_EMAIL     - Admin email (default: admin@kasm.local)

Resource Parameters:
- [ ] Server RAM           - Minimum 8GB (4GB KASM + 4GB per concurrent session)
- [ ] SWAP_SIZE_GB         - Swap file size (default: 8GB, recommended for ARM64)

Conditional Parameters (ask user):
- [ ] Using Cloudflare Tunnel for HTTPS? (Y/N)
      If Y: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, TUNNEL_HOSTNAME
- [ ] Custom KASM port? (default: 443 after install, 8443 during install)
```

### Password Requirements (KASM enforced)

- Minimum 12 characters
- Recommended: use a password manager to generate

**DO NOT proceed to Step 1 until ALL required parameters are confirmed.**

---

## Step 1: Determine Installation Path

Based on user answers, follow the appropriate workflow:

### Path A: Fresh Installation
**Use when**: New server, no existing KASM installation.

1. Read `references/INSTALLATION.md`
2. Export all parameters collected in Step 0
3. Follow step-by-step installation

### Path B: Post-Installation Configuration
**Use when**: KASM already installed, need to configure modules.

1. Read `references/QUICKSTART.md`
2. Run post-installation wizard

---

## Step 2: Secure HTTPS Access

**Determine access method based on Step 0 answers:**

| Scenario | Action |
|----------|--------|
| Cloudflare Tunnel = Yes | Read `references/cloudflare-tunnel.md` (uses `noTLSVerify: true`) |
| Direct IP only (dev) | Access via `https://SERVER_IP` (accept self-signed cert) |

---

## Step 3: Verify Installation

Run this verification checklist:

```
Verification:
- [ ] KASM UI accessible at https://SERVER_IP (or tunnel hostname)
- [ ] Login with admin credentials works
- [ ] KASM containers running: 8 (v1.18+) or 10 (v1.17) via docker ps | grep kasm
- [ ] If tunnel: HTTPS working at TUNNEL_HOSTNAME
```

**If login fails**: Extract credentials from `install_log.txt` - see `references/INSTALLATION.md` section "Get Admin Credentials".

---

## Navigation

Detailed references (one level deep):
- Manual installation: `references/INSTALLATION.md`
- Cloudflare Tunnel: `references/cloudflare-tunnel.md`
- Post-installation wizard: `references/QUICKSTART.md`
- Wizard user guide: `references/README-WIZARD.md`
- Wizard spec (draft): `references/post-installation-interview-spec.md`

## Critical Rules

- **Always verify the latest KASM version** at https://kasm.com/downloads before installing.
- Ensure Docker CE >= v25.0.5 + Compose plugin >= v2.40.2 installed before KASM.
- Allocate sufficient RAM per concurrent session (2–4GB).
- Do not expose installer port 8443 publicly without HTTPS/tunnel.
- Prefer fresh install over in-place upgrade for single-server deployments.

## Logging Integration

```bash
log_admin "SUCCESS" "installation" "Installed KASM Workspaces" "version=1.x server=$SERVER_ID"
log_admin "SUCCESS" "operation" "Ran KASM post-install wizard" "modules=$MODULES"
```

## Related Skills

- `devops` for inventory and provisioning.
- Provider skills (oci, hetzner, contabo, etc.) for server setup.

## References

- KASM docs: https://docs.kasm.com/
- KASM downloads: https://kasm.com/downloads
- KASM GitHub: https://github.com/kasmtech

## Reference Appendices

### kasm: references/INSTALLATION.md

# KASM Workspaces Installation

Step‑by‑step installation for Ubuntu servers (x86_64 or ARM64). Use when you need a manual, repeatable install outside the post‑installation wizard.

**Version Policy**: Always check https://kasm.com/downloads for the latest release before installing. Do NOT hardcode a version without verifying it is current.

**Upgrade Policy**: For single-server deployments, prefer a fresh install on a new server over in-place upgrades. KASM upgrades can involve breaking changes (removed services, config path changes). A fresh install takes ~10 minutes and avoids migration issues entirely. Tear down the old server after verifying the new one works.

## Contents
- Prerequisites
- Installation Steps
- Verify Installation
- Get Admin Credentials
- Access KASM
- Firewall Rules

---

## Prerequisites

Verify before installing:

1. **Server access**
   ```bash
   ssh ubuntu@<SERVER_IP> "echo connected"
   ```
   If this fails, check SSH key and IP in `.env.local`.

2. **Minimum resources**
   ```bash
   ssh ubuntu@<SERVER_IP> "free -h | grep Mem"
   ```
   Required: 8GB+ RAM (4GB KASM + 4GB per session).

3. **Docker installed (or will be installed)**
   ```bash
   ssh ubuntu@<SERVER_IP> "docker --version"
   ```

4. **Required ports available**
   ```bash
   ssh ubuntu@<SERVER_IP> "sudo netstat -tlnp | grep -E ':(8443|3389)'"
   ```
   Ports:
   - 8443: KASM UI (installer listens here)
   - 443: KASM UI default after install
   - 3389: RDP (optional)
   - 3000–4000: session streaming

## Installation Steps

### Step 1: System update

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  sudo apt-get update && sudo apt-get upgrade -y
"
```

### Step 2: Install Docker and dependencies

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  # Install dependencies including expect (for EULA automation)
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release expect

  # Add Docker GPG key and repository
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl start docker && sudo systemctl enable docker
  sudo usermod -aG docker \$USER
"
```

### Step 3: Create swap file (8GB)

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  if ! sudo swapon --show | grep -q '/swapfile'; then
    sudo fallocate -l 8G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi
  free -h
"
```

### Step 4: Download and install KASM

**IMPORTANT**: Check https://kasm.com/downloads for the latest version before running this step. Replace the URL below if a newer version is available.

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  mkdir -p /tmp/kasm-install && cd /tmp/kasm-install
  curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.18.1.tar.gz
  tar -xf kasm_release_1.18.1.tar.gz
  cd kasm_release
  sudo bash install.sh -e -P \$KASM_ADMIN_PASSWORD -W
"
```

**Installer flags used:**
- `-e` / `--accept-eula` — Accept EULA non-interactively
- `-P` / `--admin-password` — Set admin password (min 12 chars)
- `-W` / `--default-images` — Seed and download default workspace images

For fully automated installs, add `--install-profile noninteractive` (skips port/disk checks, does NOT download images).

See all flags with: `bash install.sh --help`

## Verify Installation

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  docker ps | grep kasm | wc -l  # 1.18+: 8 containers, 1.17: 10 containers
  curl -k -s -o /dev/null -w '%{http_code}' https://localhost:443
"
```

## Get Admin Credentials

```bash
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "
  echo '=== KASM Admin Credentials ==='
  grep -A1 'admin@kasm.local' /opt/kasm/current/install_log.txt 2>/dev/null || \
  grep -A1 'admin@kasm.local' /tmp/kasm-install/kasm_release/install_log.txt 2>/dev/null
  echo ''
  grep -A1 'user@kasm.local' /opt/kasm/current/install_log.txt 2>/dev/null || \
  grep -A1 'user@kasm.local' /tmp/kasm-install/kasm_release/install_log.txt 2>/dev/null || echo 'No user@kasm.local found'
  echo '=== End Credentials ==='
"
```

Credentials appear on the line following the username. If not found in `/opt/kasm/current/`, check `/tmp/kasm-install/kasm_release/`.

## Access KASM

Open in browser: `https://$KASM_SERVER_IP` (default port 443, or `:$KASM_PORT` if custom).  
Accept the self‑signed certificate warning and login with admin credentials.

For secure public HTTPS access, use Cloudflare Tunnel: `references/cloudflare-tunnel.md`.

## Firewall Rules

```bash
sudo ufw --force enable
sudo ufw allow 22/tcp
sudo ufw allow 8443/tcp
sudo ufw allow 3389/tcp
sudo ufw allow 3000:4000/tcp
```

## Required Environment Variables

```bash
KASM_SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa
KASM_PORT=443   # Default KASM install uses 443, not 8443
RDP_PORT=3389
```

### kasm: references/QUICKSTART.md

# KASM Post-Installation Wizard - Quick Start

## Contents
- Run the Wizard
- What's Implemented
- Coming Soon
- Full Documentation
- Quick Examples
- Monitor Backups
- Help
- Status

---

## 🚀 Run the Wizard

```bash
cd .claude/skills/kasm
bash kasm-post-install-wizard.sh
```

## 📦 What's Implemented

### ✅ Module 03: Backup Configuration
Configure automated backups to cloud storage (Backblaze B2, AWS S3, local, or SFTP).

**What it does:**
- Asks simple questions about your backup preferences
- Installs and configures backup scripts automatically
- Sets up cron jobs for automated backups
- Verifies everything works

**To run:**
```bash
# Option 1: Via wizard menu
bash kasm-post-install-wizard.sh
# Select: 03

# Option 2: Direct module execution
bash modules/03-backup-configuration.sh

# Option 3: Automated with MCP variables
export KASM_BACKUP_RCLONE_REMOTE="backblaze"
export KASM_BACKUP_RCLONE_BUCKET="my-backups"
bash modules/03-backup-configuration.sh
```

## 🔜 Coming Soon

Modules 01, 02, 04-10 will follow the same pattern:
- Interactive questions
- Automatic configuration
- Verification checks
- State tracking

## 📚 Full Documentation

- **User Guide**: `README-WIZARD.md`
- **Integration Details**: `docs/kasm-backup-module-integration-summary.md`
- **Completion Summary**: `docs/kasm-wizard-completion-summary.md`
- **MCP Variables**: `assets/env-template`

## 🎯 Quick Examples

### Example 1: Configure Backups to Backblaze B2
```bash
# 1. Configure rclone first
rclone config

# 2. Run the wizard
bash kasm-post-install-wizard.sh

# 3. Select Module 03
# 4. Answer the questions:
#    - Enable backups? Yes
#    - What to backup? All of the above
#    - Destination? S3-compatible storage
#    - Remote name? backblaze
#    - Bucket? kasm-s3
#    - Frequency? Every 4 hours
#    - Retention? 7 daily, 4 weekly, 12 monthly
# 5. Done! Backups configured automatically
```

### Example 2: Local Backups (No Cloud)
```bash
bash kasm-post-install-wizard.sh
# Select: 03
# Choose: Local directory
# Path: /mnt/backups/kasm
# Frequency: Daily
```

### Example 3: Automated Setup (CI/CD)
```bash
#!/bin/bash
# Set all MCP variables
export KASM_BACKUP_ENABLED=true
export KASM_BACKUP_RCLONE_REMOTE=backblaze
export KASM_BACKUP_RCLONE_BUCKET=production-kasm
export KASM_BACKUP_INTERVAL_MINUTES=240
export KASM_BACKUP_MAX_RETRIES=5

# Run module non-interactively
bash modules/03-backup-configuration.sh
```

## 📊 Monitor Backups

After configuring Module 03:

```bash
# View live logs
tail -f /var/log/kasm-backup.log

# Check backup status
sudo /opt/kasm-sync/kasm-backup-monitor.sh stats

# Generate report
sudo /opt/kasm-sync/kasm-backup-monitor.sh report

# Manual backup test
sudo /opt/kasm-sync/kasm-backup-manager.sh
```

## ❓ Help

```bash
# Show wizard help
bash kasm-post-install-wizard.sh
# Select: H (Help)

# Or read the docs
cat README-WIZARD.md
```

## ✅ Status

- **Main Wizard**: ✅ Complete and tested
- **Module 03**: ✅ Complete and functional
- **Modules 01-02, 04-10**: 🔜 Framework ready, coming soon

---

**Ready to use!** The wizard provides an easy, interactive way to configure KASM advanced features without editing configuration files.

### kasm: references/README-WIZARD.md

# KASM Post-Installation Wizard

**Version**: 1.0
**Status**: Module 03 Implemented ✅
**Last Updated**: 2025-11-19

## Contents
- Overview
- Quick Start
- Available Modules
- MCP Variables
- Architecture
- Usage Examples
- Monitoring Backups
- Troubleshooting
- Development Guide
- Contributing
- Related Documentation
- Roadmap
- License
- Support

---

## Overview

The KASM Post-Installation Wizard is an interactive interview system that guides you through customizing and optimizing your KASM Workspaces installation. Instead of manually editing configuration files, you answer simple questions and the wizard automatically applies the settings.

### Features

- ✨ **Interactive Interview System** - No configuration file editing required
- 🎯 **Modular Design** - Each feature is a separate module you can run independently
- 💾 **State Persistence** - Configurations are saved and tracked
- 🔄 **Idempotent** - Safe to re-run modules without breaking existing configs
- 📝 **Documented** - Every step explains what it does and why
- ↩️ **Reversible** - Configurations can be modified or undone
- 🔌 **MCP Integration** - Supports environment variables for automation

---

## Quick Start

### 1. Run the Wizard

```bash
cd .claude/skills/kasm
bash kasm-post-install-wizard.sh
```

### 2. Select a Module

The wizard will show you a menu of available customization modules:

```
╔════════════════════════════════════════════════════════════╗
║  KASM Workspaces Post-Installation Wizard v1.0             ║
╚════════════════════════════════════════════════════════════╝

Installation Detected:
  ✓ KASM Version: 1.17.0
  ✓ Server IP: <SERVER_IP>
  ✓ Resources: 2 CPU, 12GB RAM
  ✓ Containers: 10 running

Select customization modules to configure:

  01) Persistent Profiles              [Coming Soon]
  02) Shared Storage                   [Coming Soon]
  03) Backup Configuration             [✓ Completed]
  04) Docker-in-Docker                 [Coming Soon]
  05) Storage Providers                [Coming Soon]
  06) SSL Certificates                 [Coming Soon]
  07) User Authentication              [Coming Soon]
  08) Resource Optimization            [Coming Soon]
  09) Monitoring Setup                 [Coming Soon]
  10) Workspace Templates              [Coming Soon]

  A) Select All Implemented Modules
  I) Show System Information
  S) Show Wizard State
  R) Reset Wizard State
  H) Help
  Q) Quit

Enter your choice:
```

### 3. Follow the Interview

Each module will ask you questions and apply the configuration automatically.

---

## Available Modules

### ✅ Module 03: Backup Configuration (Implemented)

Configure automated backups of KASM data to cloud storage.

**What it configures**:
- Backup destination (S3, Local, SFTP)
- Backup frequency (4 hours, daily, etc.)
- What to backup (database, config, user profiles)
- Retention policy (how long to keep backups)

**Usage**:
```bash
# Interactive mode
bash kasm-post-install-wizard.sh
# Select: 03

# Direct module execution
bash modules/03-backup-configuration.sh

# With MCP variables
export KASM_BACKUP_RCLONE_REMOTE="backblaze"
export KASM_BACKUP_RCLONE_BUCKET="my-backups"
bash modules/03-backup-configuration.sh
```

**Prerequisites**:
- `rclone` installed and configured (for S3 backups)
- `jq` installed

**Example Interview**:
```
Do you want to configure automated backups? [Y/n]: y

What should be backed up?
1) Database only
2) Configuration only
3) User profiles only
4) All of the above (recommended)
Enter choice [1-4]: 4

Select backup destination:
1) S3-compatible storage (Backblaze B2, AWS S3)
2) Local directory
3) SFTP server
Enter choice [1-3]: 1

Rclone remote name [backblaze]: backblaze
S3 bucket name [kasm-s3]: my-kasm-backups

Select backup frequency:
1) Every 4 hours (recommended)
2) Daily
3) Every 12 hours
4) Weekly
Enter choice [1-4]: 1

Keep how many daily backups? [7]: 7
Keep how many weekly backups? [4]: 4
Keep how many monthly backups? [12]: 12

Configure advanced options? [y/N]: n
```

### 🔜 Coming Soon Modules

The following modules are planned and will follow the same pattern:

- **Module 01**: Persistent Profiles
- **Module 02**: Shared Storage
- **Module 04**: Docker-in-Docker
- **Module 05**: Storage Providers (Nextcloud, S3)
- **Module 06**: SSL Certificates
- **Module 07**: User Authentication
- **Module 08**: Resource Optimization
- **Module 09**: Monitoring Setup
- **Module 10**: Workspace Templates

---

## MCP Variables

All modules support MCP (Model Context Protocol) environment variables for automation and non-interactive configuration.

### Backup Module Variables

```bash
# Enable automated backups
export KASM_BACKUP_ENABLED=true

# Rclone configuration
export KASM_BACKUP_RCLONE_REMOTE=backblaze
export KASM_BACKUP_RCLONE_BUCKET=kasm-s3

# Backup settings
export KASM_BACKUP_ROOT=/mnt
export KASM_BACKUP_INTERVAL_MINUTES=240
export KASM_BACKUP_MAX_RETRIES=3
export KASM_BACKUP_RETRY_DELAY=300

# Paths to backup
export KASM_BACKUP_PATHS="kasm_profiles:profiles,dev_shared:dev-shared"

# Log files
export KASM_BACKUP_LOG_FILE=/var/log/kasm-backup.log
export KASM_BACKUP_STATS_FILE=/var/log/kasm-backup-stats.json
export KASM_BACKUP_REPORT_FILE=/var/log/kasm-backup-report.txt
```

**See**: `assets/env-template` for complete list of variables

---

## Architecture

### Directory Structure

```
.claude/skills/kasm/
├── kasm-post-install-wizard.sh    # Main wizard orchestrator
├── README-WIZARD.md                # This file
│
├── modules/                        # Customization modules
│   ├── 03-backup-configuration.sh  # Module 03 (implemented)
│   └── [01-02, 04-10].sh          # Future modules
│
├── lib/                            # Shared libraries
│   ├── kasm-api.sh                # KASM API wrapper functions
│   ├── prompts.sh                 # Interactive prompt helpers
│   └── utils.sh                   # Common utilities
│
├── configs/                        # Configuration storage
│   └── interview-state.json       # Wizard state (auto-generated)
│
├── scripts/                        # Installation scripts
│   └── validate-env.sh            # Environment validation
│
├── assets/                         # Templates and resources
│   └── env-template               # Environment variable template
│
└── specs/                          # Specifications
    └── post-installation-interview-spec.md
```

### How It Works

1. **Main Wizard** (`kasm-post-install-wizard.sh`)
   - Displays menu of available modules
   - Tracks module completion status
   - Provides system information and help

2. **Modules** (`modules/*.sh`)
   - Each module handles one aspect of customization
   - Asks interview questions
   - Applies configuration automatically
   - Verifies installation
   - Updates wizard state

3. **Libraries** (`lib/*.sh`)
   - **kasm-api.sh**: Functions to interact with KASM API
   - **prompts.sh**: User-friendly interactive prompts
   - **utils.sh**: State management, validation, logging

4. **State Persistence**
   - Configurations saved to `configs/interview-state.json`
   - Prevents duplicate work
   - Allows resuming interrupted sessions

---

## Usage Examples

### Example 1: First-Time Setup

```bash
# Run the wizard
cd .claude/skills/kasm
bash kasm-post-install-wizard.sh

# Select option 03 (Backup Configuration)
# Answer the questions
# Wizard automatically installs and configures backups
```

### Example 2: Reconfigure a Module

```bash
# Run the same module again
bash kasm-post-install-wizard.sh
# Select: 03

# Wizard detects it's already configured
# Asks if you want to reconfigure
# Applies new settings
```

### Example 3: Automated Setup with MCP Variables

```bash
# Set environment variables
export KASM_BACKUP_ENABLED=true
export KASM_BACKUP_RCLONE_REMOTE=backblaze
export KASM_BACKUP_RCLONE_BUCKET=production-backups
export KASM_BACKUP_INTERVAL_MINUTES=240

# Run module directly (uses variables, minimal prompts)
bash modules/03-backup-configuration.sh
```

### Example 4: Check System Status

```bash
bash kasm-post-install-wizard.sh
# Select: I (System Information)

# Shows:
# - CPU and memory
# - KASM containers
# - Disk usage
```

### Example 5: View Configuration State

```bash
bash kasm-post-install-wizard.sh
# Select: S (Show Wizard State)

# Shows JSON with all module configurations
```

### Example 6: Reset Everything

```bash
bash kasm-post-install-wizard.sh
# Select: R (Reset Wizard State)

# Confirms before deleting all module status
# Fresh start
```

---

## Monitoring Backups

After configuring Module 03, you can monitor backups:

```bash
# View live backup logs
tail -f /var/log/kasm-backup.log

# Generate monitoring report
sudo /opt/kasm-sync/kasm-backup-monitor.sh report

# Check backup statistics
sudo /opt/kasm-sync/kasm-backup-monitor.sh stats

# Run all monitoring checks
sudo /opt/kasm-sync/kasm-backup-monitor.sh all

# Manual backup test
sudo /opt/kasm-sync/kasm-backup-manager.sh
```

---

## Troubleshooting

### Wizard won't start

```bash
# Check prerequisites
which docker  # Should return path
which jq      # Should return path

# Check KASM is running
docker ps | grep kasm

# Check permissions
ls -la kasm-post-install-wizard.sh
# Should be executable: chmod +x kasm-post-install-wizard.sh
```

### Module 03 fails to install backups

```bash
# Check rclone configuration
rclone config
rclone about backblaze:kasm-s3

# Check disk space
df -h /opt/kasm-sync
df -h /var/log

# Check sudo access
sudo -v

# View detailed logs
tail -100 /var/log/kasm-wizard.log
```

### State file issues

```bash
# View current state
cat /opt/kasm-sync/configs/interview-state.json

# Reset state
rm -f /opt/kasm-sync/configs/interview-state.json

# Reinitialize
bash kasm-post-install-wizard.sh
# Select: S (creates new state file)
```

---

## Development Guide

### Creating a New Module

Follow Module 03 as a template:

1. **Create module file**: `modules/XX-module-name.sh`
2. **Load libraries**:
   ```bash
   source "$SKILL_DIR/lib/prompts.sh"
   source "$SKILL_DIR/lib/utils.sh"
   source "$SKILL_DIR/lib/kasm-api.sh"  # If needed
   ```

3. **Define module info**:
   ```bash
   MODULE_NAME="XX-module-name"
   MODULE_TITLE="Module Title"
   MODULE_VERSION="1.0"
   ```

4. **Implement functions**:
   - `show_module_header()` - Display module info
   - `ask_interview_questions()` - Interactive Q&A, returns JSON config
   - `implement_configuration()` - Apply the config
   - `verify_configuration()` - Check it worked
   - `main()` - Orchestrate the flow

5. **Update main wizard**:
   - Add to `IMPLEMENTED_MODULES` array
   - Add module info to `MODULES` associative array

6. **Test**:
   ```bash
   # Test standalone
   bash modules/XX-module-name.sh

   # Test via wizard
   bash kasm-post-install-wizard.sh
   ```

### Library Functions Available

**prompts.sh**:
- `ask_yes_no()` - Yes/no questions
- `ask_input()` - Text input
- `ask_choice()` - Multiple choice
- `ask_number()` - Numeric input
- `ask_path()` - Path with validation
- `print_success/error/warning/info()` - Colored messages
- `show_progress()` - Progress bars

**utils.sh**:
- `load_state()` / `save_state()` - State persistence
- `get_module_status()` / `update_module_status()` - Module tracking
- `check_required_commands()` - Dependency checking
- `create_directory()` - Directory creation with permissions
- `log_message()` - Logging

**kasm-api.sh**:
- `get_kasm_api_creds()` - Extract API credentials
- `get_workspaces()` - List workspaces
- `update_workspace_config()` - Modify workspace settings
- `apply_volume_mapping()` - Add volume mounts
- `apply_persistent_profile()` - Configure profiles

---

## Contributing

To add new modules or improve existing ones:

1. Follow the Module 03 pattern
2. Use MCP variables for all configurable values
3. Implement interview questions from the spec
4. Add verification checks
5. Update this README
6. Test thoroughly

---

## Related Documentation

- **Full Specification**: `specs/post-installation-interview-spec.md`
- **Integration Summary**: `docs/kasm-backup-module-integration-summary.md`
- **Backup Scripts Overview**: `docs/kasm-backup-script-map.md`
- **MCP Variables**: `assets/env-template`
- **KASM Skill Documentation**: `SKILL.md`

---

## Roadmap

### Phase 1: Core Framework ✅
- ✅ Main orchestrator script
- ✅ Module loading system
- ✅ State persistence
- ✅ Library functions (prompts, utils, kasm-api)

### Phase 2: Essential Modules (Current)
- ✅ Module 03: Backup Configuration
- 🔜 Module 01: Persistent Profiles
- 🔜 Module 02: Shared Storage
- 🔜 Module 08: Resource Optimization

### Phase 3: Advanced Features
- 🔜 Module 04: Docker-in-Docker
- 🔜 Module 05: Storage Providers
- 🔜 Module 09: Monitoring

### Phase 4: Enterprise Features
- 🔜 Module 06: SSL Certificates
- 🔜 Module 07: Authentication
- 🔜 Module 10: Workspace Templates

### Phase 5: Polish
- 🔜 Comprehensive testing
- 🔜 Video tutorials
- 🔜 Web-based interface option

---

## License

MIT License - Same as KASM Workspaces Skill

---

## Support

- **Issues**: https://github.com/anthropics/claude-code/issues
- **Skill Documentation**: `.claude/skills/kasm/SKILL.md`
- **KASM Documentation**: https://kasmweb.com/docs/latest/

---

**Status**: Production Ready (Module 03) ✅
**Framework**: Complete ✅
**Ready for**: Additional module development ✅

### kasm: references/cloudflare-tunnel.md

# Cloudflare Tunnel for KASM

Secure HTTPS access to KASM Workspaces via Cloudflare Tunnel.

## Contents
- Prerequisites
- Quick Setup
- Troubleshooting
- References

---

## Prerequisites

```bash
# Required environment variables
CLOUDFLARE_API_TOKEN=your_api_token      # Needs: Tunnel:Edit, DNS:Edit
CLOUDFLARE_ACCOUNT_ID=your_account_id
TUNNEL_NAME=kasm-tunnel
TUNNEL_HOSTNAME=kasm.yourdomain.com
KASM_SERVER_IP=your_server_ip
SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/id_rsa
```

---

## Quick Setup

### Step 1: Create Tunnel

```bash
TUNNEL_RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$TUNNEL_NAME\",\"config_src\":\"cloudflare\"}")

TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Tunnel ID: $TUNNEL_ID"
```

### Step 2: Create DNS Record

```bash
TUNNEL_DOMAIN=$(echo "$TUNNEL_HOSTNAME" | rev | cut -d'.' -f1-2 | rev)
HOSTNAME_PART=$(echo "$TUNNEL_HOSTNAME" | cut -d'.' -f1)

ZONE_ID=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones?name=$TUNNEL_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"CNAME\",
    \"name\":\"$HOSTNAME_PART\",
    \"content\":\"$TUNNEL_ID.cfargotunnel.com\",
    \"proxied\":true
  }"
```

### Step 3: Configure Ingress (KASM-specific)

> **CRITICAL**: KASM uses self-signed certificates. Must use `noTLSVerify: true`.

```bash
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {
          "hostname": "'$TUNNEL_HOSTNAME'",
          "service": "https://localhost:443",
          "originRequest": {
            "noTLSVerify": true,
            "connectTimeout": 30,
            "tlsTimeout": 30,
            "keepAliveTimeout": 90
          }
        },
        {"service": "http_status:404"}
      ]
    }
  }'
```

### Step 4: Get Token & Deploy

```bash
# Get tunnel token
TUNNEL_TOKEN=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
  grep -o '"result":"[^"]*"' | cut -d'"' -f4)

# Install cloudflared on server
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP '
  ARCH=$(uname -m)
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    BINARY="cloudflared-linux-arm64"
  else
    BINARY="cloudflared-linux-amd64"
  fi
  curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/$BINARY" -o /tmp/cloudflared
  sudo mv /tmp/cloudflared /usr/local/bin/
  sudo chmod +x /usr/local/bin/cloudflared
'

# Create systemd service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP "cat > /tmp/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel for KASM
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/cloudflared.service /etc/systemd/system/"

# Start service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP 'sudo systemctl daemon-reload && sudo systemctl enable cloudflared && sudo systemctl start cloudflared'
```

### Step 5: Verify

```bash
# Check service
ssh -i $SSH_KEY_PATH $SSH_USER@$KASM_SERVER_IP 'sudo systemctl status cloudflared'

# Test access
curl -I https://$TUNNEL_HOSTNAME
```

---

## Troubleshooting

### x509: certificate signed by unknown authority

**Cause**: Missing `noTLSVerify: true` in ingress config.

**Fix**: Update tunnel configuration via API or Cloudflare Dashboard → Zero Trust → Tunnels → Edit → Public Hostname → TLS settings → Enable "No TLS Verify".

### Black screen / WebSocket errors

**Cause**: Session ports (3000-4000) blocked or timeout too short.

**Fix**: Increase timeouts in ingress:
```yaml
originRequest:
  noTLSVerify: true
  connectTimeout: 120
  keepAliveTimeout: 180
```

### DNS_PROBE_FINISHED_NXDOMAIN

**Cause**: DNS CNAME not proxied (gray cloud instead of orange).

**Fix**: Update DNS record to `proxied: true` or enable in Cloudflare Dashboard.

---

## References

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared GitHub](https://github.com/cloudflare/cloudflared)

### kasm: references/post-installation-interview-spec.md

# KASM Post-Installation Interview System - Specification

**Version**: 1.0
**Status**: Draft Specification
**Created**: 2025-11-19
**Purpose**: Interactive customization wizard for KASM Workspaces after successful installation

## Contents
- Executive Summary
- System Architecture
- Module Specifications
- Interview System Flow
- API Integration
- Configuration Templates
- User Experience Features
- Testing Requirements
- Implementation Phases
- Success Metrics
- Future Enhancements
- Documentation Requirements
- Conclusion

---

## Executive Summary

This specification defines an interactive interview system that guides users through KASM Workspaces customization and optimization after successful installation. The system is modular, allowing users to select which customizations to apply and in what order.

### Design Principles

1. **Guided & Interactive**: Ask questions, don't require configuration file editing
2. **Modular**: Each customization module can run independently
3. **Idempotent**: Safe to re-run without breaking existing configurations
4. **Documented**: Every step explains what it does and why
5. **Reversible**: Ability to undo or modify applied configurations
6. **Progressive**: Start simple, advance to complex features over time

---

## System Architecture

### Core Components

```
kasm-post-install-wizard.sh (Main orchestrator)
├── modules/
│   ├── 01-persistent-profiles.sh
│   ├── 02-shared-storage.sh
│   ├── 03-backup-configuration.sh
│   ├── 04-docker-in-docker.sh
│   ├── 05-storage-providers.sh (Nextcloud, S3, etc.)
│   ├── 06-ssl-certificates.sh
│   ├── 07-user-authentication.sh
│   ├── 08-resource-optimization.sh
│   ├── 09-monitoring-setup.sh
│   └── 10-workspace-templates.sh
├── lib/
│   ├── kasm-api.sh (KASM API wrapper functions)
│   ├── prompts.sh (Interactive prompt helpers)
│   ├── validators.sh (Input validation)
│   └── utils.sh (Common utilities)
├── templates/
│   ├── docker-run-config.json.tmpl
│   ├── docker-exec-config.json.tmpl
│   ├── volume-mappings.json.tmpl
│   └── storage-provider.json.tmpl
└── configs/
    └── interview-state.json (Tracks completed modules and user choices)
```

---

## Module Specifications

### Module 01: Persistent Profiles

**Purpose**: Configure persistent user profiles across KASM sessions

**Interview Questions**:
1. "Do you want to enable persistent user profiles? (y/n)"
2. "Where should user profiles be stored?"
   - Options: Local directory, NFS mount, Block storage
3. "What is the storage path?" (default: `/mnt/kasm_profiles`)
4. "Should profiles be user-specific or shared?" (user/shared)
5. "Set storage quota per user? (optional, in GB)"

**Generated Configuration**:
```json
{
  "persistent_profiles": {
    "enabled": true,
    "path": "/mnt/kasm_profiles/{username}/{image_id}",
    "quota_gb": 10,
    "permissions": {
      "uid": 1000,
      "gid": 1000,
      "mode": "0755"
    }
  }
}
```

**Implementation Steps**:
1. Create storage directory: `sudo mkdir -p /mnt/kasm_profiles`
2. Set ownership: `sudo chown -R 1000:1000 /mnt/kasm_profiles`
3. Set permissions: `sudo chmod 755 /mnt/kasm_profiles`
4. Update workspace configurations via KASM API
5. Test profile persistence with sample workspace

**Verification**:
- Directory created with correct permissions
- Test user can write to profile directory
- Workspace configuration updated in KASM database
- Sample file persists across workspace sessions

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 160-169)
- `/docs/docker-in-kasm.md` (Lines 95-98)

---

### Module 02: Shared Storage

**Purpose**: Configure shared directories accessible across multiple workspaces

**Interview Questions**:
1. "Do you want to set up shared storage? (y/n)"
2. "What type of shared storage?"
   - Options: Development workspace (/dv), Shared documents, Project files, Custom
3. "Source directory on host?" (e.g., `/mnt/dev_shared`)
4. "Target mount point in containers?" (e.g., `/home/kasm-user/dv`)
5. "Should this be read-only or read-write?" (ro/rw)
6. "Which user groups should have access?" (all/specific groups)

**Generated Configuration**:
```json
{
  "volume_mappings": {
    "/mnt/dev_shared": {
      "bind": "/home/kasm-user/dv",
      "mode": "rw",
      "uid": 1000,
      "gid": 1000,
      "required": true,
      "skip_check": false
    }
  }
}
```

**Implementation Steps**:
1. Create host directory: `sudo mkdir -p /mnt/dev_shared`
2. Set permissions: `sudo chown -R 1000:1000 /mnt/dev_shared && sudo chmod 775 /mnt/dev_shared`
3. Apply volume mapping to workspace configurations via KASM API
4. Optionally create subdirectories (projects/, docs/, shared/)
5. Test read/write access from workspace

**Verification**:
- Host directory exists with correct permissions
- Volume mapping appears in workspace container
- Files created in workspace persist to host
- Multiple workspaces can access shared directory

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 166-168)
- `/docs/docker-in-kasm.md` (Lines 100-112)

---

### Module 03: Backup Configuration

**Purpose**: Automated backup of KASM configurations, databases, and user data

**Interview Questions**:
1. "Do you want to configure automated backups? (y/n)"
2. "What should be backed up?"
   - Options: Database only, Configuration only, User profiles, All of the above
3. "Backup destination?"
   - Options: Local directory, S3-compatible storage (Backblaze B2, AWS S3), SFTP server
4. "Backup frequency?" (hourly/daily/weekly)
5. "Retention policy?" (keep last X backups)

**Generated Configuration**:
```json
{
  "backup": {
    "enabled": true,
    "schedule": "0 2 * * *",
    "destination": "s3://bucket-name/kasm-backups/",
    "includes": [
      "/opt/kasm/current/conf",
      "database:kasm",
      "/mnt/kasm_profiles"
    ],
    "retention": {
      "daily": 7,
      "weekly": 4,
      "monthly": 12
    }
  }
}
```

**Implementation Steps**:
1. Install backup dependencies (rclone, aws-cli, or custom)
2. Configure backup credentials (S3 keys, SFTP credentials)
3. Create backup script based on user choices
4. Set up cron job for automated backups
5. Test backup and restoration procedure
6. Generate backup verification report

**Verification**:
- Backup script created and executable
- Cron job scheduled correctly
- Test backup completes successfully
- Test restore from backup works

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 170-173)
- `/docs/backblaze-sync.md`

---

### Module 04: Docker-in-Docker (DinD)

**Purpose**: Configure workspaces to run Docker containers inside KASM workspaces

**Interview Questions**:
1. "Do you want to enable Docker-in-Docker for development workspaces? (y/n)"
2. "Should Docker daemon auto-start in workspaces?" (y/n)
3. "Resource allocation for DinD workspaces:"
   - Memory (default: 4096MB, recommended: 4096-6144MB)
   - CPU cores (default: 2, recommended: 3)
4. "Should workspaces run in privileged mode?" (required for DinD) (y/n)
5. "Enable Docker Compose?" (y/n)

**Generated Configuration**:
```json
{
  "docker_in_docker": {
    "enabled": true,
    "auto_start": true,
    "resources": {
      "memory_mb": 4096,
      "cpu_cores": 3,
      "shm_size": "1g"
    },
    "docker_run_config": {
      "privileged": true,
      "shm_size": "1g",
      "environment": {
        "DOCKER_HOST": "unix:///var/run/docker.sock"
      }
    },
    "docker_exec_config": {
      "first_launch": {
        "user": "root",
        "privileged": true,
        "cmd": "bash -c 'dockerd & sleep 5 && /usr/bin/desktop_ready'"
      }
    }
  }
}
```

**Implementation Steps**:
1. Create/update DinD workspace configuration
2. Apply Docker Run Config Override for privileged mode
3. Configure Docker Exec Config for auto-start
4. Set resource limits (memory, CPU)
5. Test Docker functionality in workspace
6. Verify Docker Compose works (if enabled)

**Verification**:
- Workspace launches with privileged mode
- `docker ps` works in workspace
- `docker run hello-world` succeeds
- Docker Compose commands work (if enabled)
- Resources allocated correctly

**Documentation References**:
- `/docs/docker-in-kasm.md` (Complete guide, lines 1-297)

---

### Module 05: Storage Providers (Nextcloud, S3, etc.)

**Purpose**: Configure external storage providers for workspace access

**Interview Questions**:
1. "Do you want to connect external storage providers? (y/n)"
2. "Which provider?"
   - Options: Nextcloud, S3-compatible (AWS, Backblaze), SFTP, WebDAV, Custom
3. For Nextcloud:
   - "Nextcloud server URL?" (e.g., `https://nextcloud.example.com`)
   - "Default username format?" (e.g., `user@domain.com`)
   - "Use application passwords?" (recommended: yes)
4. "Where should storage be mounted in workspaces?" (e.g., `/nextcloud`)
5. "Should storage be user-specific or shared?" (user/shared)

**Generated Configuration**:
```json
{
  "storage_providers": {
    "nextcloud": {
      "enabled": true,
      "driver": "rclone",
      "driver_opts": {
        "type": "webdav",
        "url": "https://nextcloud.example.com/remote.php/dav/files/",
        "vendor": "nextcloud",
        "uid": "1000",
        "gid": "1000",
        "allow_other": "true"
      },
      "mount_point": "/nextcloud",
      "user_specific": true
    }
  }
}
```

**Implementation Steps**:
1. Install rclone Docker plugin (if not already installed)
2. Create storage provider in KASM via API
3. Create storage mapping configuration
4. Test storage provider connection
5. Assign to user groups or workspaces
6. Generate user instructions for authentication

**Verification**:
- Storage provider appears in KASM admin panel
- Test user can authenticate and mount storage
- Files created in workspace sync to external storage
- Read/write permissions work correctly

**Documentation References**:
- `/docs/kasm-nextcloud-troubleshooting.md` (Complete guide, lines 1-218)

---

### Module 06: SSL Certificates

**Purpose**: Configure SSL certificates for secure HTTPS access

**Interview Questions**:
1. "Do you want to configure SSL certificates? (y/n)"
2. "Which method?"
   - Options: Let's Encrypt (automatic), Custom certificate, Self-signed (development)
3. For Let's Encrypt:
   - "Domain name for KASM?" (e.g., `kasm.example.com`)
   - "Email for certificate notifications?"
4. For Custom certificate:
   - "Path to certificate file?"
   - "Path to private key file?"
   - "Path to CA bundle?" (optional)

**Generated Configuration**:
```json
{
  "ssl": {
    "enabled": true,
    "method": "letsencrypt",
    "domain": "kasm.example.com",
    "email": "admin@example.com",
    "auto_renew": true,
    "redirect_http": true
  }
}
```

**Implementation Steps**:
1. Install certbot (for Let's Encrypt)
2. Obtain SSL certificate
3. Update KASM configuration to use certificate
4. Configure automatic renewal
5. Set up HTTP to HTTPS redirect
6. Test HTTPS access

**Verification**:
- Certificate obtained successfully
- HTTPS works with valid certificate
- HTTP redirects to HTTPS
- Auto-renewal configured correctly

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 143-146)

---

### Module 07: User Authentication

**Purpose**: Configure advanced authentication methods

**Interview Questions**:
1. "Do you want to configure advanced authentication? (y/n)"
2. "Which authentication method?"
   - Options: Local (default), LDAP, Active Directory, SAML, OIDC
3. For LDAP/AD:
   - "LDAP server URL?"
   - "Base DN?"
   - "Bind DN and password?"
   - "User filter?"
4. For SAML/OIDC:
   - "Provider URL?"
   - "Client ID and secret?"
   - "Attribute mappings?"

**Generated Configuration**:
```json
{
  "authentication": {
    "method": "ldap",
    "ldap": {
      "server": "ldaps://ldap.example.com:636",
      "base_dn": "dc=example,dc=com",
      "bind_dn": "cn=admin,dc=example,dc=com",
      "user_filter": "(uid={username})",
      "group_filter": "(memberUid={username})"
    }
  }
}
```

**Implementation Steps**:
1. Test authentication provider connectivity
2. Configure KASM authentication settings via API
3. Create test user account
4. Verify authentication works
5. Configure group mappings (if applicable)
6. Document user login procedures

**Verification**:
- Test user can authenticate
- Group memberships sync correctly
- Existing local users still work
- Authentication logs show successful connections

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 148-152)

---

### Module 08: Resource Optimization

**Purpose**: Optimize resource allocation for workspaces and server

**Interview Questions**:
1. "Do you want to optimize resource allocation? (y/n)"
2. "Server total resources:"
   - CPU cores available: (auto-detect or manual)
   - RAM available: (auto-detect or manual)
3. "Default workspace allocation:"
   - Memory per workspace (MB): (default: 2048)
   - CPU cores per workspace: (default: 1)
4. "Maximum concurrent sessions?" (default: based on resources)
5. "Enable resource usage monitoring?" (y/n)

**Generated Configuration**:
```json
{
  "resources": {
    "server": {
      "cpu_cores": 12,
      "memory_gb": 24
    },
    "defaults": {
      "memory_mb": 2048,
      "cpu_cores": 2,
      "concurrent_limit": 8
    },
    "monitoring": {
      "enabled": true,
      "alerts": {
        "cpu_threshold": 80,
        "memory_threshold": 85
      }
    }
  }
}
```

**Implementation Steps**:
1. Analyze current server resources
2. Calculate optimal defaults based on capacity
3. Update workspace default resources
4. Configure resource limits
5. Enable monitoring (if selected)
6. Generate resource utilization report

**Verification**:
- Workspace resource settings updated
- Test workspace launches with new resources
- Resource limits enforced correctly
- Monitoring shows accurate metrics

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 176-182)

---

### Module 09: Monitoring Setup

**Purpose**: Configure health monitoring and alerting

**Interview Questions**:
1. "Do you want to set up monitoring? (y/n)"
2. "What should be monitored?"
   - Options: Container health, Resource usage, User sessions, Database, All
3. "Enable email alerts?" (y/n)
4. "Alert email address?"
5. "Alert thresholds:"
   - CPU usage: (default: 80%)
   - Memory usage: (default: 85%)
   - Disk usage: (default: 90%)

**Generated Configuration**:
```json
{
  "monitoring": {
    "enabled": true,
    "checks": [
      "container_health",
      "resource_usage",
      "user_sessions",
      "database_connectivity"
    ],
    "alerts": {
      "email": "admin@example.com",
      "thresholds": {
        "cpu_percent": 80,
        "memory_percent": 85,
        "disk_percent": 90
      }
    },
    "schedule": "*/5 * * * *"
  }
}
```

**Implementation Steps**:
1. Create monitoring script
2. Configure email alerting (if enabled)
3. Set up cron job for periodic checks
4. Test monitoring and alerts
5. Generate initial health report
6. Document monitoring procedures

**Verification**:
- Monitoring script runs successfully
- Test alert triggers correctly
- Logs show monitoring activity
- Health reports generated

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 223-231)

---

### Module 10: Workspace Templates

**Purpose**: Create custom workspace templates for common use cases

**Interview Questions**:
1. "Do you want to create custom workspace templates? (y/n)"
2. "Which template types?"
   - Options: Development (Node.js, Python, etc.), Docker-in-Docker, Browser isolation, Office productivity, Custom
3. For Development template:
   - "Programming languages?" (Node.js, Python, Go, Java, etc.)
   - "Include development tools?" (git, vim, VS Code, etc.)
   - "Enable Docker?" (y/n)
4. "Default resources for this template?"
   - Memory (MB)
   - CPU cores

**Generated Configuration**:
```json
{
  "workspace_templates": {
    "dev-nodejs": {
      "base_image": "kasmweb/ubuntu-jammy-desktop:1.17.0",
      "packages": [
        "nodejs",
        "npm",
        "git",
        "build-essential"
      ],
      "resources": {
        "memory_mb": 3072,
        "cpu_cores": 2
      },
      "volume_mappings": {
        "/mnt/dev_shared": {
          "bind": "/home/kasm-user/projects",
          "mode": "rw"
        }
      }
    }
  }
}
```

**Implementation Steps**:
1. Create workspace configuration
2. Install specified packages/tools
3. Configure resource allocation
4. Apply volume mappings
5. Test workspace launch
6. Save as template for users

**Verification**:
- Template appears in workspace list
- All specified tools installed
- Resources allocated correctly
- Volume mappings work

**Documentation References**:
- `/docs/kasm-installation-verification-and-customization-guide.md` (Lines 197-202)

---

## Interview System Flow

### Main Menu

```
╔════════════════════════════════════════════════════════════╗
║       KASM Workspaces Post-Installation Wizard             ║
║                    Version 1.0                             ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  Welcome! This wizard will help you customize your KASM   ║
║  installation with advanced features and optimizations.   ║
║                                                            ║
║  Installation detected:                                    ║
║  ✓ KASM Version: 1.17.0                                   ║
║  ✓ Server IP: <SERVER_IP>                                 ║
║  ✓ Resources: 2 CPU, 12GB RAM                             ║
║  ✓ Containers: 10/10 running                              ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  Select customization modules to configure:                ║
║                                                            ║
║  [ ] 01. Persistent Profiles                              ║
║  [ ] 02. Shared Storage                                   ║
║  [ ] 03. Backup Configuration                             ║
║  [ ] 04. Docker-in-Docker                                 ║
║  [ ] 05. Storage Providers (Nextcloud, S3)                ║
║  [ ] 06. SSL Certificates                                 ║
║  [ ] 07. User Authentication                              ║
║  [ ] 08. Resource Optimization                            ║
║  [ ] 09. Monitoring Setup                                 ║
║  [ ] 10. Workspace Templates                              ║
║                                                            ║
║  [A] Select All  [N] Select None  [R] Run Selected        ║
║  [S] Save Progress  [Q] Quit                              ║
╚════════════════════════════════════════════════════════════╝
```

### Interview Progress Tracking

```json
{
  "interview_state": {
    "version": "1.0",
    "started": "2025-11-19T00:00:00Z",
    "last_updated": "2025-11-19T00:30:00Z",
    "modules": {
      "01-persistent-profiles": {
        "status": "completed",
        "completed_at": "2025-11-19T00:10:00Z",
        "config": {...}
      },
      "02-shared-storage": {
        "status": "in_progress",
        "started_at": "2025-11-19T00:25:00Z",
        "config": {...}
      },
      "03-backup-configuration": {
        "status": "pending"
      }
    }
  }
}
```

---

## API Integration

### KASM API Wrapper Functions

The wizard will use KASM's REST API to apply configurations:

```bash
# lib/kasm-api.sh

# Get KASM API credentials from installation
get_kasm_api_creds() {
    KASM_API_URL="https://localhost/api"
    KASM_API_KEY=$(sudo grep "api_key" /opt/kasm/current/conf/app/api.app.config.yaml | awk '{print $2}')
    KASM_API_SECRET=$(sudo grep "api_key_secret" /opt/kasm/current/conf/app/api.app.config.yaml | awk '{print $2}')
}

# Update workspace configuration
update_workspace_config() {
    local workspace_id="$1"
    local config_json="$2"

    curl -X POST "$KASM_API_URL/api/public/update_workspace" \
        -H "Content-Type: application/json" \
        -u "$KASM_API_KEY:$KASM_API_SECRET" \
        -d "$config_json"
}

# Create storage mapping
create_storage_mapping() {
    local mapping_json="$1"

    curl -X POST "$KASM_API_URL/api/public/create_storage_mapping" \
        -H "Content-Type: application/json" \
        -u "$KASM_API_KEY:$KASM_API_SECRET" \
        -d "$mapping_json"
}
```

---

## Configuration Templates

### Docker Run Config Template

```json
{
  "hostname": "kasm",
  "privileged": {{PRIVILEGED}},
  "shm_size": "{{SHM_SIZE}}",
  "environment": {
    {{#if DOCKER_ENABLED}}
    "DOCKER_HOST": "unix:///var/run/docker.sock",
    {{/if}}
    "KASMVNC_DESKTOP_ALLOW_RESIZE": "{{ALLOW_RESIZE}}",
    "KASMVNC_DESKTOP_RESOLUTION_WIDTH": "{{WIDTH}}",
    "KASMVNC_DESKTOP_RESOLUTION_HEIGHT": "{{HEIGHT}}"
  }
}
```

### Volume Mappings Template

```json
{
  "{{HOST_PATH}}": {
    "bind": "{{CONTAINER_PATH}}",
    "mode": "{{MODE}}",
    "uid": {{UID}},
    "gid": {{GID}},
    "required": {{REQUIRED}},
    "skip_check": {{SKIP_CHECK}}
  }
}
```

---

## User Experience Features

### Visual Progress Indicators

```bash
Installing persistent profiles...
[████████████████████████████░░░░] 80% - Setting permissions
```

### Validation and Error Handling

- **Pre-validation**: Check prerequisites before applying (disk space, network, permissions)
- **Live validation**: Validate inputs as user enters them
- **Post-validation**: Verify configuration was applied successfully
- **Rollback**: Automatic rollback if configuration fails
- **Error reporting**: Clear error messages with suggested fixes

### Help System

- **Contextual help**: `?` at any prompt shows detailed help
- **Examples**: Show example values for each input
- **Documentation links**: Reference to relevant docs
- **Preview**: Show what will be configured before applying

---

## Testing Requirements

### Unit Tests

- Each module can be tested independently
- Mock KASM API responses for testing
- Validate configuration generation
- Test rollback procedures

### Integration Tests

- Test full interview flow
- Test with actual KASM installation
- Verify configurations apply correctly
- Test concurrent module execution

### User Acceptance Tests

- Real users complete interview
- Measure completion time
- Gather feedback on clarity
- Test with various configurations

---

## Implementation Phases

### Phase 1: Core Framework (Week 1)
- Main orchestrator script
- Module loading system
- State persistence
- Basic prompts and validation

### Phase 2: Essential Modules (Week 2)
- Module 01: Persistent Profiles
- Module 02: Shared Storage
- Module 08: Resource Optimization

### Phase 3: Advanced Features (Week 3-4)
- Module 04: Docker-in-Docker
- Module 05: Storage Providers
- Module 09: Monitoring

### Phase 4: Enterprise Features (Week 5-6)
- Module 06: SSL Certificates
- Module 07: Authentication
- Module 03: Backup Configuration

### Phase 5: Polish & Documentation (Week 7)
- Module 10: Workspace Templates
- Comprehensive testing
- User documentation
- Video tutorials

---

## Success Metrics

1. **Completion Rate**: % of users who complete interview
2. **Time to Complete**: Average time to configure all modules
3. **Error Rate**: Configuration failures requiring manual intervention
4. **User Satisfaction**: Survey rating of interview experience
5. **Support Tickets**: Reduction in configuration-related support requests

---

## Future Enhancements

1. **Web-based Interface**: Browser-based wizard instead of CLI
2. **Import/Export**: Share configurations between installations
3. **Preset Profiles**: Pre-configured sets for common use cases (development, training, enterprise)
4. **Auto-discovery**: Detect optimal settings based on server resources
5. **Health Checks**: Periodic re-validation of configurations
6. **Configuration Diff**: Show changes before applying
7. **Multi-language Support**: Internationalization
8. **Integration Testing**: Built-in verification after each module

---

## Documentation Requirements

### For Developers

- API documentation for all modules
- Architecture decision records
- Testing procedures
- Contribution guidelines

### For Users

- Quick start guide
- Module-specific guides
- Troubleshooting FAQ
- Video walkthroughs

### For Administrators

- Installation guide
- Configuration reference
- Backup/restore procedures
- Security considerations

---

## Conclusion

This post-installation interview system transforms KASM Workspaces from a basic installation into a fully customized, production-ready VDI platform through an intuitive, guided process. By leveraging existing documentation and proven configurations, users can confidently optimize their KASM deployment without deep technical expertise.

The modular design ensures flexibility while the interactive approach reduces configuration errors and accelerates time to value.
