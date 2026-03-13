# Install ripgrep on WSL — Transcript (Without Skill)

**Date:** 2026-03-13
**Platform:** WSL2 Ubuntu 24.04 on Windows 11 Pro (WOPR3)
**Method:** General knowledge, no skill assistance

---

## Step 1: Check if ripgrep is already installed

```bash
which rg
rg --version
dpkg -l ripgrep
```

**Expected outcome:** Determine whether ripgrep is present and how it was installed (apt package vs standalone binary). On this machine, `rg` is currently aliased through Claude Code's bundled binary at `~/.local/share/claude/versions/2.1.74`, and there is no `ripgrep` apt package installed. A system-level install would make `rg` available globally regardless of Claude Code's presence.

---

## Step 2: Check available version in apt

```bash
apt-cache show ripgrep | grep -E '^Version|^Package'
```

**Expected outcome:** Shows the version available in Ubuntu 24.04 repositories. Ubuntu 24.04 (Noble) should have ripgrep 14.x available.

---

## Step 3: Update package index

```bash
sudo apt update
```

**Expected outcome:** Refreshes the package list so we install the latest available version.

---

## Step 4: Install ripgrep via apt

```bash
sudo apt install -y ripgrep
```

**Expected outcome:** Installs the `ripgrep` package, which provides the `rg` binary at `/usr/bin/rg`.

---

## Step 5: Verify installation

```bash
which rg
rg --version
dpkg -l ripgrep
```

**Expected outcome:** `/usr/bin/rg` exists, version is reported, and `dpkg` shows the package as installed (`ii` status).

---

## Step 6: Quick functional test

```bash
echo "hello world" | rg "hello"
```

**Expected outcome:** Outputs `hello world` with "hello" highlighted, confirming ripgrep works.

---

## Alternative: Install latest version from GitHub (if apt version is too old)

If the apt version is outdated and a newer release is needed:

```bash
# Check latest release
curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep tag_name

# Download the .deb for amd64
curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep_14.1.1-1_amd64.deb

# Install the .deb
sudo dpkg -i ripgrep_14.1.1-1_amd64.deb

# Verify
rg --version
```

---

## Notes

- Used `apt` as the package manager per workspace preferences (apt over snap).
- No snap, cargo, or other install methods attempted — apt is the preferred route.
- The install is straightforward: single package, no dependencies to worry about, no configuration needed.
- Total commands: 6 (check, cache, update, install, verify, test). Estimated time: under 60 seconds.
