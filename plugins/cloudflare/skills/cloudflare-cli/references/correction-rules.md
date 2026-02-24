# Cloudflare CLI (cf) Corrections

Claude has limited training data for coollabsio/cloudflare-cli (released Dec 2024). Use these patterns when generating or reviewing cf CLI commands.

## Command Structure

The CLI follows: `cf <resource> <action> [args] [flags]`

Binary name is `cf`, NOT `cloudflare` or `cloudflare-cli`.

## Authentication

```bash
# Save token to config (recommended)
cf auth save <token>

# Verify credentials
cf auth verify

# WRONG - Claude may hallucinate these
# cf auth login           -> use "cf auth save <token>"
# cf login                -> use "cf auth save <token>"
# cf auth set-token       -> use "cf auth save <token>"
# cf config set api_token -> use "cf auth save <token>"
```

Config file: `~/.cloudflare/config.yaml`

## Zone Commands

```bash
# Correct patterns
cf zones list
cf zones get example.com
cf zones get 023e105f4ecef8ad...    # By zone ID

# WRONG - Claude may hallucinate these
# cf zone list         -> use "zones" not "zone"
# cf zones show        -> use "get" not "show"
# cf zones info        -> use "get" not "info"
# cf list zones        -> resource comes first: "cf zones list"
```

## DNS Commands

```bash
# List with filters
cf dns list <zone>
cf dns list <zone> --type A
cf dns list <zone> --type A -t CNAME     # Multiple types
cf dns list <zone> --name www
cf dns list <zone> --search "production"

# Get specific record
cf dns get <zone> <record-id>

# Create
cf dns create <zone> -t A -n www -c 192.0.2.1
cf dns create <zone> -t CNAME -n blog -c example.com --proxied
cf dns create <zone> -t MX -n mail -c mail.example.com --priority 10
cf dns create <zone> -t A -n api -c 192.0.2.10 --comment "Production API"

# Update (by record ID, only changed fields needed)
cf dns update <zone> <record-id> --content 192.0.2.2
cf dns update <zone> <record-id> --proxied
cf dns update <zone> <record-id> --proxied=false
cf dns update <zone> <record-id> --comment ""    # Clear comment

# Delete
cf dns delete <zone> <record-id>

# Find (lookup before update/delete)
cf dns find <zone> --name www --type A

# WRONG - Claude may hallucinate these
# cf dns add             -> use "create" not "add"
# cf dns remove          -> use "delete" not "remove"
# cf dns set             -> use "update" not "set"
# cf dns search          -> use "find" or "list --search"
# cf dns list --zone X   -> zone is a positional arg, not a flag
# cf record list         -> use "dns" not "record"
```

## Create/Update Flags

```
-t, --type       Record type (A, AAAA, CNAME, MX, TXT, SRV, etc.)
-n, --name       Record name (subdomain or @ for root)
-c, --content    Record value (IP, hostname, text)
--ttl            TTL in seconds (1 = auto, default)
--proxied        Route through Cloudflare CDN (boolean)
--priority       Priority (MX, SRV records)
--comment        Record comment/note
```

## Output Format

```bash
# Per-command
cf dns list example.com --output json
cf dns list example.com -o json

# Set default
cf config set output_format json

# WRONG
# cf dns list --format json   -> use "--output" or "-o", not "--format"
# cf dns list --json          -> use "-o json"
```

## Zone-Scoped Token Limitation

```bash
# Zone-scoped tokens CANNOT:
# - List zones (cf zones list)
# - Resolve zone names to IDs

# Workaround: use zone IDs directly
cf dns list 023e105f4ecef8ad9ca31a8b...   # Always works
cf dns list example.com                     # Fails with scoped token
```

## Config Commands

```bash
cf config set <key> <value>
cf config get <key>
cf config list

# Available keys: output_format (table or json)

# WRONG
# cf config set token X    -> use "cf auth save X"
# cf settings              -> use "cf config"
```

## Global Flags (Available on All Commands)

```
--config          Path to config file (default: ~/.cloudflare/config.yaml)
-o, --output      Output format: table (default) or json
```

## This CLI vs Others

| Tool | Binary | Purpose |
|------|--------|---------|
| **cf** (this) | `cf` | DNS & zone management (coollabsio) |
| **wrangler** | `npx wrangler` | Workers development (official) |
| **flarectl** | `flarectl` | Full API CLI (official, cloudflare-go) |
| **cloudflared** | `cloudflared` | Tunnels & Zero Trust (official) |
