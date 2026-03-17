# Secrets Architecture (v4.0)

The admin-devops secrets system uses a 4-layer model with 3 Infisical projects, folder-based organization, URI-based references, and portable runtime rendering.

## Contents

- [4-Layer Model](#4-layer-model)
- [3 Infisical Projects](#3-infisical-projects)
- [Folder Taxonomy](#folder-taxonomy)
- [URI Format](#uri-format)
- [Profile Schema: secretRefs and fileRefs](#profile-schema-secretrefs-and-filerefs)
- [Runtime Rendering](#runtime-rendering)
- [Machine Identities](#machine-identities)
- [Fallback Chain](#fallback-chain)
- [Consumer Types](#consumer-types)

## 4-Layer Model

```
Layer 1: Age Key (local file, never leaves device)
  └── Layer 2: Vault (age-encrypted, contains Infisical bootstrap creds)
        └── Layer 3: Infisical Cloud (3 projects, folder-organized)
              └── Layer 4: Generated Runtime (resolved .env + credential files)
```

- **Layer 1** (age key): The root of trust. One file per device at `~/.age/key.txt`.
- **Layer 2** (vault): Contains `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID` and `CLIENT_SECRET` for bootstrap. Also serves as offline fallback for all secrets.
- **Layer 3** (Infisical): Three projects with folder hierarchies. Source of truth for all secrets during normal operation.
- **Layer 4** (generated): Output of `render-runtime.sh`. Pre-resolved `.env` files that scripts source without needing Infisical access at runtime.

## 3 Infisical Projects

| Project | Trust Boundary | Contents |
|---|---|---|
| `admin-operator` | Operator (full access) | Provider API keys, LLM tokens, Cloudflare, Mattermost, Google credentials |
| `admin-runtime` | Runtime (scoped) | Agent bot tokens, deployment passwords, tunnel tokens |
| `customer-*` | Customer (isolated) | Per-customer OpenClaw config, workspace settings, Google ADC |

### Why split?

- **Least privilege**: A KASM runtime only needs its own deployment secrets, not all provider keys
- **Customer isolation**: Customer credentials never touch operator infrastructure
- **Audit trail**: Per-project access logs show who accessed what

## Folder Taxonomy

### admin-operator
```
/shared/llm/          OPENROUTER_API_KEY, OPENAI_API_KEY
/shared/mattermost/   ADMIN_TOKEN, URL
/shared/sentinel/     TOKEN
/shared/              GITHUB_TOKEN
/providers/hetzner/   HCLOUD_TOKEN
/providers/contabo/   CLIENT_SECRET, OAUTH_PASS
/providers/digitalocean/ ACCESS_TOKEN
/providers/vultr/     API_KEY
/providers/linode/    API_TOKEN
/providers/oci/       (OCI uses config files, not tokens)
/network/cloudflare/  API_TOKEN, ZONE_ID, ACCOUNT_ID
/files/gcloud/        Base64-encoded JSON credentials
```

### admin-runtime
```
/agents/lia/          MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/shane/        MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/terra/        MM_BOT_TOKEN, GATEWAY_TOKEN, AUTH_PASSWORD
/agents/taco/         MM_BOT_TOKEN
/agents/picoclaw/     DISCORD_BOT_TOKEN, MM_BOT_TOKEN, BRAVE_API_KEY
/deployments/kasm-contabo-01/    ADMIN_PASSWORD, CF_TUNNEL_TOKEN
/deployments/kasm-hetzner-01/    ADMIN_PASSWORD, CF_TUNNEL_TOKEN
/deployments/kasm-hetzner-02/    ADMIN_PASSWORD, CF_TUNNEL_TOKEN
/deployments/nanoclaw-contabo-01/ CF_TUNNEL_TOKEN
```

### customer-larrysinteriors
```
/apps/openclaw/       Gateway config, channel tokens
/workspace/           Workspace preferences
/files/gcloud/        Customer-specific Google ADC
/local/               Customer-local overrides
```

## URI Format

```
infisical://PROJECT_SLUG/ENVIRONMENT/FOLDER.../KEY
```

Examples:
```
infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN
infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN
infisical://customer-larrysinteriors/prod/apps/openclaw/GATEWAY_TOKEN
```

Resolution:
1. Parse URI into: project slug, environment, folder path, key name
2. Look up project slug in `$ADMIN_ROOT/config/infisical-projects.json` for project ID
3. Call `infisical secrets get KEY --projectId ID --env ENV --path /FOLDER`
4. If Infisical fails, fall back to vault (flat key lookup)

## Profile Schema: secretRefs and fileRefs

Schema version 4.0 adds these to the device profile:

```json
{
  "schemaVersion": "4.0",
  "secretRefs": {
    "lia_mm_bot_token": "infisical://admin-runtime/prod/agents/lia/MM_BOT_TOKEN",
    "hcloud_token": "infisical://admin-operator/prod/providers/hetzner/HCLOUD_TOKEN"
  },
  "fileRefs": {
    "gcloud_adc_larrys": {
      "uri": "infisical://admin-operator/prod/files/gcloud/ADC_LARRYS",
      "renderTo": "/home/user/.config/gcloud/adc-larrys.json",
      "mode": "0600"
    }
  },
  "secretsConfig": {
    "backend": "infisical",
    "fallback": "vault",
    "multiProject": true,
    "projectsConfig": "config/infisical-projects.json"
  }
}
```

- `secretRefs`: Maps logical names to `infisical://` URIs. Resolved by `render-runtime.sh` into `generated/.env`.
- `fileRefs`: Maps logical names to URIs + file paths. Resolved by `render-secret-file.sh` into actual credential files.
- `secretsConfig`: Declares which backend is primary, the fallback, and whether multi-project mode is active.

## Runtime Rendering

`render-runtime.sh` (bash) / `Render-Runtime.ps1` (PowerShell):

1. Load device profile
2. Iterate `secretRefs` → resolve each URI → write to `$ADMIN_ROOT/generated/.env`
3. Iterate `fileRefs` → resolve each URI → decode base64 → write to `renderTo` path
4. Generate `$ADMIN_ROOT/generated/compat.env` with original flat key names

**Why render?** Remote servers and KASM runtimes may not have Infisical CLI. The render step runs on the operator workstation and ships pre-resolved files.

### Loading order in scripts

`load-profile.sh` checks for `generated/.env` first:
```
generated/.env exists? → source it (no Infisical needed)
  ↓ (no)
Infisical backend? → call infisical export
  ↓ (fail)
Vault fallback → age -d vault.age
  ↓ (fail)
Plaintext .env → last resort
```

## Machine Identities

For headless environments (runtimes, customer PCs), machine identities provide scoped access:

| Identity | Projects | Scope |
|---|---|---|
| `wopr3-operator` | admin-operator (read), admin-runtime (read) | Full operator access |
| `runtime-kasm-hetzner-02` | admin-runtime | `/deployments/kasm-hetzner-02/` only |
| `runtime-openclaw-contabo-01` | admin-runtime | `/agents/lia/`, `/agents/shane/`, `/agents/terra/` |
| `customer-larrysinteriors-pc` | customer-larrysinteriors | Read all |

Machine identity credentials (`CLIENT_ID`, `CLIENT_SECRET`) are stored in the age vault on each device — this is the bootstrap chain anchor.

## Fallback Chain

Every resolve function follows this order:

1. **Generated file** (`generated/.env`): Pre-rendered, no network needed
2. **Infisical**: Live lookup via CLI (requires auth + network)
3. **Vault**: Age-encrypted local file (requires age key)
4. **Plaintext .env**: Legacy, last resort

The vault is never deleted. It serves as:
- Offline fallback when Infisical is unreachable
- Bootstrap anchor for Infisical credentials
- Emergency recovery path

## Consumer Types

Profile v4.0 adds a `consumer` field to identify what type of environment the profile represents:

| Type | Trust Boundary | Typical Access |
|---|---|---|
| `workstation` | `operator` | All 3 projects, full read |
| `runtime` | `runtime` | admin-runtime only, scoped to deployment folder |
| `customer-pc` | `customer` | Customer project only |

The `access` field in the profile explicitly declares which projects and folders this consumer can reach:

```json
{
  "consumer": {
    "type": "runtime",
    "runtime": "kasm-hetzner-02",
    "trustBoundary": "runtime"
  },
  "access": {
    "projects": ["admin-runtime"],
    "folders": ["/deployments/kasm-hetzner-02/"]
  }
}
```

## Scripts Reference

| Script | Purpose | Phase |
|---|---|---|
| `resolve-secret-ref.sh` / `.ps1` | Parse `infisical://` URI, fetch secret | 0 |
| `secrets` / `secrets.ps1` | Multi-backend CLI (now with `--path`, `--project`) | 0 |
| `infisical-bootstrap.sh` | Create projects + folder hierarchy | 1 |
| `migrate-secrets-phase2.sh` | Move operator secrets | 2 |
| `migrate-secrets-phase3.sh` | Move agent secrets + update profile | 3 |
| `migrate-secrets-phase4.sh` | Move deployment secrets | 4 |
| `migrate-secrets-phase5.sh` | Move JSON credential files | 5 |
| `render-secret-file.sh` / `.ps1` | Decode base64 blob to file | 5 |
| `render-runtime.sh` / `.ps1` | Full runtime render orchestrator | 6 |

## Config Files

| File | Location | Purpose |
|---|---|---|
| `infisical-projects.json` | `$ADMIN_ROOT/config/` | Project slug → ID mapping |
| `generated/.env` | `$ADMIN_ROOT/generated/` | Pre-resolved secrets |
| `generated/compat.env` | `$ADMIN_ROOT/generated/` | Legacy flat-key format |
