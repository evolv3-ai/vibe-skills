# OCI CLI Installation Guide

**Purpose**: Install the Oracle Cloud Infrastructure CLI on your system.
**Time**: 5-10 minutes
**Next Step**: [Configure OCI CLI](./CONFIG.md)

---

## Contents
- Quick Check
- Installation by Operating System
- Verify Installation
- Troubleshooting
- Next Steps
- Official Resources

---

## Quick Check

First, verify if OCI CLI is already installed:

```bash
oci --version
```

If you see a version number (e.g., `3.x.x`), skip to [Configuration](./CONFIG.md).

---

## Installation by Operating System

<details>
<summary><strong>🐧 Linux</strong></summary>

### Automatic Installation (Recommended)

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Manual Installation

```bash
# Download installer
curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o install.sh

# Run with options
bash install.sh --install-dir ~/lib/oracle-cli --exec-dir ~/bin/oci-cli
```

### Package Managers

**Ubuntu/Debian:**
```bash
# Add Oracle repository key
curl -sL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install_oci_cli_ubuntu.sh | bash
```

**RHEL/CentOS/Fedora:**
```bash
# Using dnf
sudo dnf install oraclelinux-developer-release-el8
sudo dnf install python36-oci-cli

# Or using yum
sudo yum install python36-oci-cli
```

### Post-Install: Update PATH

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export PATH=$PATH:~/bin
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

</details>

<details>
<summary><strong>🍎 macOS</strong></summary>

### Automatic Installation (Recommended)

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Using Homebrew

```bash
brew install oci-cli
```

### Manual Installation

```bash
# Download installer
curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o install.sh

# Run installer
bash install.sh
```

### Post-Install: Update PATH

Add to `~/.zshrc` (default macOS shell):

```bash
export PATH=$PATH:~/bin
```

Reload:
```bash
source ~/.zshrc
```

</details>

<details>
<summary><strong>🪟 Windows</strong></summary>

### MSI Installer (Recommended)

1. Download the latest MSI from [OCI CLI Releases](https://github.com/oracle/oci-cli/releases)
2. Run the MSI installer
3. Follow the installation wizard
4. Open a **new** PowerShell or Command Prompt window

### PowerShell Script

```powershell
# Run in PowerShell as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-WebRequest https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1 -OutFile install.ps1
.\install.ps1 -AcceptAllDefaults
```

### Git Bash / MSYS2

```bash
# From Git Bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Post-Install

Open a **new** terminal window to ensure PATH is updated.

</details>

<details>
<summary><strong>🐳 Docker</strong></summary>

### Using Official Docker Image

```bash
# Pull official image
docker pull ghcr.io/oracle/oci-cli:latest

# Run OCI CLI command
docker run --rm -v ~/.oci:/root/.oci ghcr.io/oracle/oci-cli oci --version

# Create alias for convenience
alias oci='docker run --rm -v ~/.oci:/root/.oci ghcr.io/oracle/oci-cli oci'
```

### Custom Dockerfile

```dockerfile
FROM python:3.11-slim
RUN pip install oci-cli
ENTRYPOINT ["oci"]
```

</details>

<details>
<summary><strong>☁️ Cloud Shell</strong></summary>

OCI Cloud Shell has OCI CLI **pre-installed**. No installation needed.

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click the Cloud Shell icon (top-right terminal icon)
3. CLI is ready to use with your credentials

</details>

---

## Verify Installation

After installation, verify:

```bash
# Check version
oci --version

# Expected output: 3.x.x
```

---

## Troubleshooting

<details>
<summary><strong>Command not found</strong></summary>

**Cause**: PATH not updated or terminal not restarted.

**Fix**:
```bash
# Linux/macOS - reload shell profile
source ~/.bashrc  # or ~/.zshrc

# Or restart your terminal
```

For Windows, open a **new** PowerShell/Command Prompt window.

</details>

<details>
<summary><strong>Python version errors</strong></summary>

**Cause**: OCI CLI requires Python 3.6+.

**Fix**:
```bash
# Check Python version
python3 --version

# Install Python if needed
# Ubuntu/Debian
sudo apt install python3 python3-pip

# macOS
brew install python3

# Then reinstall OCI CLI
```

</details>

<details>
<summary><strong>Permission denied</strong></summary>

**Cause**: Install script needs write permissions.

**Fix**:
```bash
# Use user-level installation (no sudo needed)
bash install.sh --install-dir ~/lib/oracle-cli --exec-dir ~/bin

# Or fix permissions
chmod +x install.sh
```

</details>

<details>
<summary><strong>SSL/TLS errors</strong></summary>

**Cause**: Outdated certificates or proxy issues.

**Fix**:
```bash
# Update CA certificates
# Ubuntu/Debian
sudo apt update && sudo apt install ca-certificates

# macOS
brew install ca-certificates

# If behind proxy, set environment variables
export HTTPS_PROXY=http://proxy.example.com:8080
```

</details>

---

## Next Steps

Once OCI CLI is installed, proceed to **[Configuration](./CONFIG.md)** to set up your credentials.

---

## Official Resources

- [OCI CLI Installation Docs](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- [OCI CLI GitHub](https://github.com/oracle/oci-cli)
- [OCI CLI Releases](https://github.com/oracle/oci-cli/releases)
