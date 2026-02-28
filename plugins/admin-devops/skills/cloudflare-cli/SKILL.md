---
name: cloudflare-cli
description: |
  Manage Cloudflare DNS records and zones from the terminal with the cf CLI (coollabsio/cloudflare-cli). Full DNS CRUD, zone listing, filtered queries, proxied record toggling, and JSON output for scripting.

  Use when: managing DNS records via CLI, listing Cloudflare zones, creating/updating/deleting DNS records, automating Cloudflare DNS workflows, or troubleshooting zone-scoped token permission errors, "cf: command not found", config file issues.
---

# Cloudflare CLI (cf)

## Quick Start (3 Minutes)

### 1. Install

```bash
# Linux/macOS (global)
curl -fsSL https://raw.githubusercontent.com/coollabsio/cloudflare-cli/main/scripts/install.sh | bash

# Linux/macOS (user, no sudo)
curl -fsSL https://raw.githubusercontent.com/coollabsio/cloudflare-cli/main/scripts/install.sh | bash -s -- --user

# Via Go
go install github.com/coollabsio/cloudflare-cli@latest

# From source
git clone https://github.com/coollabsio/cloudflare-cli.git
cd cloudflare-cli && go build -o cf .
```

**Windows**: Download the binary from [GitHub Releases](https://github.com/coollabsio/cloudflare-cli/releases) or build from source with `go build -o cf.exe .`

### 2. Authenticate

Create an API token in Cloudflare Dashboard → My Profile → API Tokens with permissions:
- **Zone:Read** (listing zones)
- **DNS:Read** (viewing records)
- **DNS:Edit** (creating/updating/deleting records)

```bash
# Save token to config (recommended)
cf auth save <YOUR_API_TOKEN>

# Verify connection
cf auth verify
```

### 3. First Commands

```bash
cf zones list
cf dns list example.com
cf dns create example.com -t A -n www -c 192.0.2.1 --proxied
```

---

## Authentication

Three methods, in priority order (higher overrides lower):

### 1. Config File (Recommended)

```bash
cf auth save <token>
# Saves to ~/.cloudflare/config.yaml
```

Config file contents:
```yaml
api_token: your-api-token-here
output_format: table
```

### 2. Environment Variables

```bash
export CLOUDFLARE_API_TOKEN=your-api-token
# OR
export CF_API_TOKEN=your-api-token
```

### 3. Legacy API Key

```bash
export CLOUDFLARE_API_KEY=your-api-key
export CLOUDFLARE_API_EMAIL=your-email
```

**Priority**: Environment variables override config file values.

### Required Token Permissions

| Permission | Scope | Required For |
|-----------|-------|-------------|
| Zone:Read | All zones (recommended) | `cf zones list`, zone name resolution |
| DNS:Read | Target zones | `cf dns list`, `cf dns get`, `cf dns find` |
| DNS:Edit | Target zones | `cf dns create`, `cf dns update`, `cf dns delete` |

**CRITICAL**: Zone-scoped tokens (restricted to specific zones) cannot list zones or resolve zone names to IDs. See [Known Issues](#known-issues-prevention).

---

## Zone Management

```bash
cf zones list                            # List all zones in account
cf zones get example.com                 # Get zone details by name
cf zones get 023e105f4ecef8ad9ca31a...   # Get zone details by ID
```

Both zone names and zone IDs are accepted in all commands.

---

## DNS Record Management

### List Records

```bash
cf dns list <zone>                           # All records
cf dns list <zone> --type A                  # Filter by type
cf dns list <zone> --type A -t CNAME         # Multiple types
cf dns list <zone> --name www                # Filter by name
cf dns list <zone> --search "production"     # Search in comments/content
cf dns list <zone> -t A -n www              # Combined filters
```

### Get Record Details

```bash
cf dns get <zone> <record-id>
```

### Create Records

```bash
# A record
cf dns create <zone> -t A -n www -c 192.0.2.1

# CNAME with proxy
cf dns create <zone> -t CNAME -n blog -c example.com --proxied

# MX with priority
cf dns create <zone> -t MX -n mail -c mail.example.com --priority 10

# TXT record
cf dns create <zone> -t TXT -n _acme -c "verification-string"

# A record with comment
cf dns create <zone> -t A -n api -c 192.0.2.10 --comment "Production API"
```

**Create flags:**

| Flag | Short | Required | Purpose |
|------|-------|----------|---------|
| `--type` | `-t` | Yes | Record type (A, AAAA, CNAME, MX, TXT, etc.) |
| `--name` | `-n` | Yes | Record name (subdomain or @) |
| `--content` | `-c` | Yes | Record value (IP, hostname, text) |
| `--ttl` | | No | TTL in seconds (default: 1 = auto) |
| `--proxied` | | No | Route through Cloudflare CDN (boolean) |
| `--priority` | | No | Priority (MX, SRV records) |
| `--comment` | | No | Record comment/note |

### Update Records

```bash
cf dns update <zone> <record-id> --content 192.0.2.2
cf dns update <zone> <record-id> --proxied
cf dns update <zone> <record-id> --proxied=false
cf dns update <zone> <record-id> --comment "Updated comment"
cf dns update <zone> <record-id> --comment ""           # Clear comment
cf dns update <zone> <record-id> -t A -n newname -c 192.0.2.3  # Multiple fields
```

Update accepts the same flags as create. Only specified flags are changed.

### Delete Records

```bash
cf dns delete <zone> <record-id>
```

### Find Records

```bash
cf dns find <zone> --name www --type A
cf dns find <zone> -n api -t A
cf dns find <zone> --type MX
```

`find` returns matching records. Useful for scripting when you need to look up a record ID before updating or deleting.

---

## Configuration

```bash
cf config set <key> <value>    # Set configuration value
cf config get <key>            # Get configuration value
cf config list                 # List all settings
```

**Available keys:**

| Key | Values | Default | Purpose |
|-----|--------|---------|---------|
| `output_format` | `table`, `json` | `table` | Default output format |

---

## Output Formats & Scripting

```bash
cf dns list example.com                  # Table (default, human-readable)
cf dns list example.com --output json    # JSON for automation
cf dns list example.com -o json          # Short flag

# Set JSON as default
cf config set output_format json

# Pipe to jq for filtering
cf dns list example.com -o json | jq '.[].name'

# Extract record IDs
cf dns list example.com -o json | jq -r '.[].id'
```

---

## Critical Rules

### Always Do

- Verify auth before first use: `cf auth verify`
- Use `--output json` for scripting and piping to jq
- Use zone IDs (not names) with zone-scoped tokens
- Include `--comment` on records for documentation
- Test DNS changes on staging zones before production

### Never Do

- Use zone-scoped tokens with `cf zones list` (will fail with permission error)
- Store API tokens in shell history — use `cf auth save` instead
- Delete records without confirming the record ID first (`cf dns find` or `cf dns get`)
- Assume `--proxied` is safe for all record types (only works with A, AAAA, CNAME)

### Command Name Corrections

Claude has limited training data for cf CLI (released Dec 2024). Common hallucinations:

- Binary is `cf`, NOT `cloudflare` or `cloudflare-cli`
- `cf zones list` NOT `cf zone list` (plural "zones")
- `cf dns create` NOT `cf dns add`
- `cf dns delete` NOT `cf dns remove`
- `cf auth save <token>` NOT `cf auth login` or `cf login`
- `--output json` / `-o json` NOT `--format json` or `--json`
- Zone is a positional arg: `cf dns list example.com` NOT `cf dns list --zone example.com`

For complete correction patterns, see `references/correction-rules.md`.

---

## Known Issues Prevention

This skill prevents **3** documented issues:

### Issue #1: Zone-Scoped Token Permission Error

**Error**: Permission error when using `cf zones list` or resolving zone names
**Cause**: API token restricted to specific zones cannot list all zones or resolve names to IDs
**Prevention**: Either grant "All zones" read permission, or use zone IDs directly:
```bash
# Instead of zone name (fails with scoped token):
cf dns list example.com

# Use zone ID (always works):
cf dns list 023e105f4ecef8ad9ca31a8b...
```

### Issue #2: Config File Not Found on Windows

**Error**: Config file not found or auth not persisting
**Cause**: `~/.cloudflare/` directory doesn't exist on Windows
**Prevention**: Ensure directory exists before saving auth:
```bash
mkdir -p ~/.cloudflare
cf auth save <token>
```
Windows config location: `%USERPROFILE%\.cloudflare\config.yaml`

### Issue #3: "cf: command not found" After Install

**Error**: `cf: command not found` after running install script
**Cause**: Binary not on PATH or installed to unexpected location
**Prevention**: Check install location and add to PATH:
```bash
# Check if binary exists
which cf || ls /usr/local/bin/cf || ls ~/bin/cf

# User install adds to ~/bin — ensure it's on PATH
export PATH="$HOME/bin:$PATH"
```

---

## Self-Update

```bash
cf update    # Download and install latest version
cf version   # Show current version
```

---

## Global Flags Reference

| Flag | Short | Purpose |
|------|-------|---------|
| `--config` | | Path to config file (default: `~/.cloudflare/config.yaml`) |
| `--output` | `-o` | Output format: `table` (default) or `json` |
