---
name: kasm-admin
description: |
  Day-to-day operations for a running KASM Workspaces server. Workspace CRUD via API,
  session monitoring, user/group management, bulk config updates, agent provisioning,
  capacity planning, and multi-agent bot deployment patterns.

  Use when: managing workspaces (create/clone/update/delete), monitoring active sessions,
  managing users and groups, bulk-updating Docker Exec/Run configs, provisioning bot agents,
  checking server capacity, or deploying multi-agent architectures on KASM.

  NOT for: KASM installation, initial setup, networking/tunnels, or basic troubleshooting
  (use the /kasm skill for those).
license: MIT
---

# KASM Admin — Operational Management

**Purpose**: Manage a running KASM server — workspaces, users, sessions, resources, and bot agents.

**Prerequisite**: KASM is already installed and configured. For installation, use `/kasm`.

## Step 0: Determine What the Admin Needs

| Task | Reference |
|------|-----------|
| Workspace CRUD (create, clone, update, delete) | `references/workspace-management.md` |
| Session monitoring and management | `references/session-management.md` |
| User and group management | `references/user-group-management.md` |
| Bulk operations (update configs across workspaces) | `references/bulk-operations.md` |
| Resource monitoring and capacity planning | `references/capacity-planning.md` |
| Multi-agent bot deployment patterns | `references/multi-agent-patterns.md` |
| Backup, restore, and S3/B2 profile sync | `references/backup-operations.md` |
| Common Docker configs (copy-paste ready) | `references/config-templates.md` |

## API Authentication

All KASM API calls use JSON payload auth (NOT HTTP Basic Auth):

```bash
curl -k -X POST "https://$KASM_HOST/api/admin/$ENDPOINT"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KASM_API_KEY",
    "api_key_secret": "$KASM_API_SECRET"
  }'
```

API credentials are stored in the admin vault (`KASM_API_KEY`, `KASM_API_SECRET`).

## Key Terminology

| UI Term | API Term | DB Table |
|---------|----------|----------|
| Workspaces | Images | `images` |
| Sessions | Kasms | `kasms` |
| Storage Mappings | Storage Providers | `storage_providers` |
| API Keys | API Configs | `api_configs` |

## Quick Reference — Most Common Operations

### Check server health
```bash
# Via sentinelctl (recommended)
sentinelctl pull --config fleet.json --token $TOKEN --connection-mode direct

# Via KASM API
curl -k -X POST "https://$KASM_HOST/api/admin/system_info"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### List all workspaces
```bash
curl -k -X POST "https://$KASM_HOST/api/public/get_images"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### List active sessions
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/get_kasms"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### Quick DB queries
```bash
# List workspaces with resources
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT image_id, friendly_name, cores, memory, enabled FROM images ORDER BY friendly_name;"

# Active sessions with resource usage
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT k.kasm_id, i.friendly_name, u.username, k.start_date FROM kasms k JOIN images i ON k.image_id = i.image_id JOIN users u ON k.user_id = u.user_id WHERE k.operational_status = 'running';"

# Users and groups
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT u.user_id, u.username, string_agg(g.name, ', ') as groups FROM users u LEFT JOIN group_membership gm ON u.user_id = gm.user_id LEFT JOIN groups g ON gm.group_id = g.group_id GROUP BY u.user_id, u.username ORDER BY u.username;"
```
