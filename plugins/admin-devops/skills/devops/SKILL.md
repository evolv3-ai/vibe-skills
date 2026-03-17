---
name: devops
description: |
  REMOTE infrastructure administration (alpha v0.0.2). Server inventory, cloud provisioning
  (OCI, Hetzner, Linode, DigitalOcean, Contabo), and application deployment
  (Coolify, KASM). Profile-aware - reads servers from device profile.

  Use when: provisioning VPS, deploying to cloud, installing Coolify/KASM,
  managing remote servers.

  NOT for: local installs, Windows/WSL/macOS admin, MCP servers → use admin.
---

# Admin DevOps - Remote Infrastructure (Alpha)

**Script path resolution**: When Claude Code loads this file, it provides the full
path. Derive `SKILL_DIR` from this file's directory. Admin scripts (profile gate,
logging, secrets) live in the sibling admin skill at `${SKILL_DIR}/../admin/scripts/`.

---

## CRITICAL: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `assets/` within a skill.
- Store live secrets in `~/.admin/.env` and reference from there.

## Secrets Management

Three backends available, configured via `ADMIN_SECRETS_BACKEND` in `~/.admin/.env`:

| Backend | Storage | Best For |
|---------|---------|----------|
| `infisical` | Infisical Cloud | Multi-device, audit trail |
| `vault` (default) | `$ADMIN_ROOT/vault.age` | Single device, offline |
| `env` | `$ADMIN_ROOT/.env` | Legacy |

**Fallback chain**: infisical → vault → env. If the primary backend is unavailable, scripts automatically try the next.

**CLI**: Use the admin skill's `secrets` script to retrieve provider API keys:

```bash
# Retrieve a single provider token
HCLOUD_TOKEN=$(${SKILL_DIR}/../admin/scripts/secrets HCLOUD_TOKEN)

# Or if secrets is on PATH
export HCLOUD_TOKEN=$(secrets HCLOUD_TOKEN)
```

### Provider Secrets Map

| Secret Key | Infisical URI | Provider | Used By |
|---|---|---|---|
| `HCLOUD_TOKEN` | `infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN` | Hetzner | hcloud CLI auth |
| `DIGITALOCEAN_ACCESS_TOKEN` | `infisical://admin-operator/prod/providers/digitalocean/ACCESS_TOKEN` | DigitalOcean | doctl auth |
| `CNTB_OAUTH2_CLIENT_SECRET` | `infisical://admin-operator/prod/providers/contabo/CLIENT_SECRET` | Contabo | cntb config |
| `CNTB_OAUTH2_PASS` | `infisical://admin-operator/prod/providers/contabo/OAUTH_PASS` | Contabo | cntb config |
| `LINODE_API_TOKEN` | `infisical://admin-operator/prod/providers/linode/API_TOKEN` | Linode | linode-cli |
| `VULTR_API_KEY` | `infisical://admin-operator/prod/providers/vultr/API_KEY` | Vultr | vultr-cli |
| `CF_API_TOKEN` | `infisical://admin-operator/prod/network/cloudflare/API_TOKEN` | Cloudflare | Tunnel setup |

**Retrieval** (v4.0+):
```bash
# URI-based (recommended)
HCLOUD_TOKEN=$(resolve-secret-ref.sh "infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN")

# Multi-project secrets CLI
HCLOUD_TOKEN=$(secrets --project admin-operator --path /providers/hetzner HCLOUD_TOKEN)

# Legacy (still works via fallback chain)
HCLOUD_TOKEN=$(secrets HCLOUD_TOKEN)
```

**Guides**: `references/secrets-architecture.md` (full 4-layer model), `references/infisical.md` (Infisical setup), `references/vault-guide.md` (age vault fallback)

---

## Profile Gate (MANDATORY First Step)

Check for a profile before any operation. No profile means no server inventory, no preferences, no logging path.

```bash
${SKILL_DIR}/../admin/scripts/test-admin-profile.sh
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...","platform":"..."}`

If `exists: false` — stop and hand off to **admin** skill for `/setup-profile`. Do not proceed without a profile.

Full details: `references/profile-gate.md`

---

## Task Qualification (MANDATORY)

- If the task is **local OS/MCP/skills**, stop and hand off to **admin**.
- If the task is **remote infrastructure**, continue.
- If ambiguous, ask a clarifying question before proceeding.

## SimpleMem Integration (Optional, Graceful Degradation)

SimpleMem enhances provisioning decisions but never blocks operations. If unavailable, skip silently.

**Query before provisioning:**
```
memory_query: "What issues have occurred provisioning on {provider} in {region}?"
memory_query: "What happened last time I deployed {app} to {provider}?"
```

**Store after provisioning (success):**
```
memory_add:
  speaker: "devops:server-provisioner"
  content: "Provisioned {provider} {server_type} in {region}: {IP}. Purpose: {purpose}. Cost: {cost}/mo."
```

**Store after provisioning (failure):**
```
memory_add:
  speaker: "devops:server-provisioner"
  content: "{provider} provisioning failed in {region}: {error}. Workaround: {fix_if_any}."
```

**Store after deployment:**
```
memory_add:
  speaker: "devops:deployment-coordinator"
  content: "Deployed {app} to {server_id}: {outcome}. {notes}"
```

---

## Task Routing

| Task | Reference |
|------|-----------|
| Server inventory | Server Operations (use profile.servers) |
| OCI provisioning | references/oci.md |
| Hetzner provisioning | references/hetzner.md |
| Linode provisioning | references/linode.md |
| DigitalOcean provisioning | references/digitalocean.md |
| Contabo provisioning | references/contabo.md |
| Coolify deployment | references/coolify.md |
| KASM deployment | references/kasm.md |
| Secrets / Infisical setup | **→ Use admin skill** |
| **Local machine tasks** | **→ Use admin skill** |

## Server Operations

Use `profile.servers[]` for inventory; do not maintain a separate list. Profile is the source of truth.

## Provisioning Workflow (7 Steps)

1. Choose provider
2. Load secrets via `secrets` CLI (provider API key)
3. Query SimpleMem for past experience with this provider/region
4. Run provider workflow (see provider reference)
5. Update `profile.servers[]` and `profile.deployments{}`
6. Log the operation via `log_admin_event`
7. Store outcome in SimpleMem

## Logging (MANDATORY)

Log every operation. Logging scripts live in the admin sibling skill.

```bash
source "${SKILL_DIR}/../admin/scripts/log-admin-event.sh"
log_admin_event "Provisioned Hetzner server hzn-01-203-42" "OK"
log_admin_event "OCI provisioning failed: OUT_OF_HOST_CAPACITY" "ERROR"
```

Levels: `OK` (success), `INFO`, `WARN`, `ERROR`

---

## Architecture

### Relationship to Admin

devops is a satellite of admin. It depends on admin for:
- **Profile gate** (`test-admin-profile.sh`) — mandatory first step
- **Logging** (`log-admin-event.sh`) — mandatory operation logging
- **Secrets** (`secrets` CLI) — provider API key retrieval with fallback chain
- **Profile data** (`profile.servers[]`, `profile.deployments{}`) — server inventory

### Sibling Skill Resolution

```
plugins/admin-devops/
  skills/
    admin/      ← core (scripts, secrets, logging live here)
    devops/     ← this skill (references admin scripts via ../admin/)
    oci/        ← provider skill
    hetzner/    ← provider skill
    ...
```

### Agent Roster

| Agent | Model | Role |
|---|---|---|
| server-provisioner | sonnet | Cloud VM provisioning via provider CLIs |
| deployment-coordinator | sonnet | End-to-end app deployment (Coolify/KASM) |

Both agents use SimpleMem graceful degradation and profile gate as first step.

---

## Scripts / References

- Inventory scripts: `scripts/agentDevopsInventory.ts`, `scripts/agent_devops_inventory.py`
- Provider references: `references/*.md` (per-provider deployment guides)
- Provider skills: sibling skills under this plugin (oci, hetzner, coolify, etc.)
- Inventory format spec: `references/INVENTORY_FORMAT.md`
- Deployment workflows: `references/DEPLOYMENT_WORKFLOWS.md`
- Troubleshooting: `references/TROUBLESHOOTING.md`
