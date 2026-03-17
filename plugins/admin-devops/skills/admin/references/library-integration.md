# Library + Profile + Infisical Integration

How The Library, device profiles, and Infisical work together to distribute agentics across devices.

## Three Planes

| Plane | What it distributes | Repo | Format |
|-------|-------------------|------|--------|
| **Library** | Skills, agents, prompts, MCP servers | `the-library` (private) | `library.yaml` + `library.json` |
| **Profile** | Device config, bindings, consumer identity | `admin-profiles` (private) | `DEVICE.json` |
| **Infisical** | Actual secret values, scoped by project | Cloud | `infisical://` URIs |

## Data Ownership

| Data | Owner | Example |
|------|-------|---------|
| "simplemem exists and needs SIMPLEMEM_TOKEN" | Library (`library.yaml`) | `requiredSecrets.SIMPLEMEM_TOKEN.defaultUri` |
| "WOPR3 has simplemem configured, token is at this URI" | Profile (`bindings.mcp.simplemem`) | `secretRefs.SIMPLEMEM_TOKEN: "infisical://..."` |
| "The actual token value" | Infisical / vault | Resolved at render time |

## Bindings Model (v4.1)

The profile's `bindings` object maps library entries to device-specific state:

```json
{
  "bindings": {
    "mcp": {
      "simplemem": {
        "secretRefs": {
          "SIMPLEMEM_TOKEN": "infisical://admin-operator/prod/shared/SIMPLEMEM_TOKEN"
        },
        "status": "active",
        "installedAt": "2026-03-17T...",
        "installPolicy": "library"
      }
    },
    "skill": {
      "admin": {
        "status": "active",
        "installedAt": "2026-03-17T...",
        "installPolicy": "plugin"
      }
    }
  }
}
```

Every `/library use` writes a binding — even for entries with no secrets. The profile's bindings ARE the install state. No separate state file needed.

## installPolicy

| Value | Meaning | `/library use` behavior |
|-------|---------|------------------------|
| `library` | Library copies files | Full fetch + bind |
| `plugin` | Claude Code plugin manages files | Bind only (no file copy) |
| `manual` | User manages | Skip entirely |

## Post-Use Hook

The Library calls a post-use hook after `/library use` completes. The hook is owned by admin-devops:

```
Library: /library use simplemem
  → Steps 1-7: fetch, install, verify
  → Step 8: Call hooks/post-use.sh simplemem mcp library.json
  → (admin-devops hook writes binding to profile)
```

Hook location: `~/.claude/skills/library/hooks/post-use.sh` (symlink to admin-devops's `library-post-use-hook.sh`)

## Render Pipeline

After bindings exist, three renderers materialize runtime files:

```
Profile (bindings)  →  render-runtime.sh      →  generated/.env (secrets as KEY=value)
Library (catalog)   →  render-mcp-config.sh   →  ~/.claude/.mcp.json (MCP client config)
Both                →  generate-agents-md.sh  →  ~/.claude/AGENTS.md (passive context)
```

`--skip-unresolvable` flag allows renders during bootstrap before Infisical is configured.

## Reconcile

`reconcile-library.sh` compares library.json against profile bindings to produce three lists:

- **Should install**: targets match, not yet bound
- **Installed**: binding exists with active/pending status
- **Not eligible**: target/trust mismatch

For `installPolicy: plugin` entries, install status is checked via `installed_plugins.json`.

Output: `--json` for agent consumption, human table to stderr.

## Device Targeting

Profile's `consumer` field determines eligibility:

| Consumer Type | Trust Boundary | Typical Library Entries |
|--------------|----------------|----------------------|
| `workstation` | `operator` | Everything |
| `runtime` | `runtime` | admin, MCP servers targeted at runtime |
| `customer-pc` | `customer` | admin, openclaw, customer MCP |

Library entries declare `targets: [workstation, runtime]` and `trustBoundary: operator`. The reconciler checks both.

## Bootstrap Sequence

```
1. Install Claude Code
2. Install The Library (git clone to ~/.claude/skills/library/)
3. Install plugin (claude plugin add)
4. Create profile (/setup-profile --headless) ← MUST come before reconcile
5. Reconcile (reconcile-library.sh --json)
6. /library use for each needed entry (hook writes bindings)
7. render-runtime.sh --skip-unresolvable
8. render-mcp-config.sh --skip-unresolvable
9. generate-agents-md.sh
10. Verify (test-admin-profile.sh)
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `reconcile-library.sh` | Compare catalog vs bindings |
| `render-mcp-config.sh` | Library MCP entries → client config |
| `render-runtime.sh` | Bindings secretRefs → generated/.env |
| `diagnose-mcp.sh` | Standalone MCP health checker |
| `generate-agents-md.sh` | Build passive context for Claude Code |
| `library-post-use-hook.sh` | Write bindings after /library use |
| `resolve-secret-ref.sh` | Parse infisical:// URIs, resolve secrets |
