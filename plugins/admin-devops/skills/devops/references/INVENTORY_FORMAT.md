# Agent DevOps Inventory v1 Format

## Contents
- Overview
- File locations
- General rules
- Metadata keys
- Provider keys
- Server keys
- SSH connection fields
- Agent behavior

---

## Overview

Agent DevOps Inventory v1 is a minimal `.env`-style text file for tracking:

- Cloud providers (OCI, Hetzner, Contabo, DigitalOcean, Vultr, Linode, etc.)
- Local/network providers (home lab, LAN)
- Nodes/servers (remote VMs, physical machines, local dev boxes)
- Connection methods (local vs SSH)
- Metadata (env, role, status, tags)

The inventory is the single source of truth for admin-servers and the provider skills (oci, hetzner, contabo, etc.).

---

## File Locations

Recommended names (check in order):
1. `.agent-devops.env` (project root)
2. `agent-devops.env.local` (project root)
3. `~/.agent-devops.env` (user home)

---

## General Rules

- One entry per line: `KEY=VALUE`
- Lines starting with `#` are comments (ignored)
- Blank lines are allowed (ignored)
- Keys use **UPPER_SNAKE_CASE**: `A-Z`, `0-9`, `_`
- Values are arbitrary strings

---

## Metadata Keys

| Key | Required | Description |
|-----|----------|-------------|
| `AGENT_DEVOPS_VERSION` | No | Version of spec (default: `1`) |
| `AGENT_DEVOPS_PROJECT` | No | Project name (e.g., `infra-lab`) |
| `AGENT_DEVOPS_OWNER` | No | Owner identifier |
| `AGENT_DEVOPS_NOTES` | No | Short notes about inventory |

---

## Provider Keys

Pattern: `PROVIDER_<NAME>_<FIELD>`

| Field | Required | Description |
|-------|----------|-------------|
| `PROVIDER_<NAME>_TYPE` | **Yes** | Provider type: `oci`, `hetzner`, `gcp`, `contabo`, `digitalocean`, `vultr`, `linode`, `local_network` |
| `PROVIDER_<NAME>_AUTH_METHOD` | No | Auth type: `file`, `env`, `inline`, `none` |
| `PROVIDER_<NAME>_AUTH_FILE` | No | Path to credentials file |
| `PROVIDER_<NAME>_DEFAULT_REGION` | No | Default region/zone |
| `PROVIDER_<NAME>_LABEL` | No | Human‑friendly label |
| `PROVIDER_<NAME>_NOTES` | No | Notes about provider |

Special provider names:
- `LOCALNET` – local network/home lab
- `LOCAL_AGENT` – this machine

---

## Server Keys

Pattern: `SERVER_<ID>_<FIELD>`

Required fields:

| Field | Description |
|-------|-------------|
| `SERVER_<ID>_PROVIDER` | Provider name (must match a `PROVIDER_<NAME>`) |
| `SERVER_<ID>_KIND` | Node type: `vm`, `physical`, `local_pc`, `container_host`, `other` |
| `SERVER_<ID>_NAME` | Human‑friendly name |
| `SERVER_<ID>_CONNECT_VIA` | Connection method: `local` or `ssh` |

Recommended metadata:

| Field | Description |
|-------|-------------|
| `SERVER_<ID>_ENV` | `prod`, `staging`, `dev`, `test`, `personal`, `lab` |
| `SERVER_<ID>_ROLE` | `web`, `db`, `dev`, `desktop`, `coolify`, `kasm` |
| `SERVER_<ID>_OS` | `linux`, `windows`, `macos`, `bsd` |
| `SERVER_<ID>_STATUS` | `active`, `stopped`, `retired`, `unreachable` |
| `SERVER_<ID>_TAGS` | Comma‑separated tags |
| `SERVER_<ID>_NOTES` | Short notes |

---

## SSH Connection Fields

When `SERVER_<ID>_CONNECT_VIA=ssh`:

| Field | Description |
|-------|-------------|
| `SERVER_<ID>_HOST` | IP or DNS hostname |
| `SERVER_<ID>_PORT` | SSH port (default 22) |
| `SERVER_<ID>_USER` | SSH username |
| `SERVER_<ID>_SSH_KEY_PATH` | Path to private key |

---

## Agent Behavior

### Reading Inventory

1. Read all lines, skip blank and `#` comments
2. Split each line on first `=` into key and value
3. For `PROVIDER_*` keys: extract provider name and field
4. For `SERVER_*` keys: extract server ID and field
5. Build in‑memory maps for providers and servers

### Before Provisioning

When asked to create a new server, check existing inventory first:

```bash
grep -E "SERVER_.*_(ENV|ROLE|PROVIDER|STATUS)" .agent-devops.env
```

Look for matches on env/role/provider/status to decide reuse vs new provisioning.

### After Provisioning

When a node is created:

1. Choose a new server ID (e.g., `WEB02`)
2. Add a block of `SERVER_<ID>_*` keys
3. Minimum required fields example:

```env
SERVER_WEB02_PROVIDER=OCI
SERVER_WEB02_KIND=vm
SERVER_WEB02_NAME=prod-web-2
SERVER_WEB02_CONNECT_VIA=ssh
SERVER_WEB02_HOST=203.0.113.11
SERVER_WEB02_PORT=22
SERVER_WEB02_USER=ubuntu
SERVER_WEB02_SSH_KEY_PATH=~/.ssh/id_rsa
SERVER_WEB02_ENV=prod
SERVER_WEB02_OS=linux
SERVER_WEB02_ROLE=web
SERVER_WEB02_STATUS=active
```

### Retiring Nodes

- Set `SERVER_<ID>_STATUS=stopped` for stopped VMs.
- Set `SERVER_<ID>_STATUS=retired` for destroyed nodes.
- Do not delete the block; preserve history.
- Avoid reusing IDs of retired nodes.
