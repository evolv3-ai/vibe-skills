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

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `assets/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.

---

## ⚠️ PROFILE GATE (MANDATORY)
See `references/profile-gate.md` (synced from admin).

## Task Qualification (MANDATORY)
- If the task is **local OS/MCP/skills**, stop and hand off to **admin**.
- If the task is **remote infrastructure**, continue.
- If ambiguous, ask a clarifying question before proceeding.

## Task Routing

| Task | Reference |
|------|-----------|
| Server inventory | Server Operations |
| OCI provisioning | references/oci.md |
| Hetzner provisioning | references/hetzner.md |
| Linode provisioning | references/linode.md |
| DigitalOcean provisioning | references/digitalocean.md |
| Contabo provisioning | references/contabo.md |
| Coolify deployment | references/coolify.md |
| KASM deployment | references/kasm.md |
| **Local machine tasks** | **→ Use admin skill** |

## Server Operations

Use profile.servers for inventory; do not maintain a separate list.

## Provisioning Workflow (5 Steps)

1. Choose provider
2. Load deployment env (`.env.local`)
3. Run provider workflow
4. Update profile servers/deployments
5. Log the operation

## Logging (MANDATORY)

Uses local logging scripts (synced from admin):

Logging scripts are synced from the admin plugin. Source them relative to the admin skill:

```bash
source scripts/log-admin-event.sh  # if synced from admin
log_admin_event "Provisioned Hetzner server" "OK"
```

```powershell
. "scripts\Log-AdminEvent.ps1"  # if synced from admin
Log-AdminEvent -Message "Provisioned Hetzner server" -Level OK
```

## Scripts / References

- Inventory scripts: `scripts/agentDevopsInventory.ts`, `scripts/agent_devops_inventory.py`
- Provider references: `references/*.md` (per-provider deployment guides)
- Provider skills: sibling skills under this plugin (oci, hetzner, coolify, etc.)
