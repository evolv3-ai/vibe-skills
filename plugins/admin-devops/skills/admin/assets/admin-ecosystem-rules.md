# Admin Ecosystem Correction Rules

Rules specific to the admin-devops plugin's conventions: MCP HTTP session protocol, agent-roster integrity, profile schema parity, satellite `.env` contracts. Not portable outside admin-devops.

## MCP HTTP Session Init Protocol (ISSUE-0008)

WRONG - Calling MCP tools directly without session initialization:
```bash
curl -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"ping","arguments":{}},"id":1}'
# Fails: server returns "Session not initialized" or similar error
```

RIGHT - Initialize session first, then use the returned Mcp-Session-Id:
```bash
# Step 1: Initialize and capture session ID
SESSION_ID=$(curl -s -D - -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"cli","version":"1.0"}},"id":1}' \
  | grep -i 'mcp-session-id' | awk '{print $2}' | tr -d '\r')

# Step 2: Call tools with session ID
curl -X POST https://mcp.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"ping","arguments":{}},"id":2}'
```

## SKILL.md Agent Roster Must Match Actual Agent Files (GitHub #17)

WRONG - Listing an agent in SKILL.md that has no corresponding file in `agents/`:
```markdown
| fake-bot | sonnet | <some role> | Read, Write, Bash |
```
No `agents/fake-bot.md` file exists. Any delegation to `fake-bot` fails at runtime with no useful error.

RIGHT - Only list agents that have actual `.md` files in `agents/`. Verify before editing SKILL.md:
```bash
ls plugins/admin-devops/agents/*.md
# Only list agents that appear in this output — one row per file
```

There's no compile-time check for agent roster accuracy. Phantom entries fail silently at the moment of delegation. After adding or removing an agent file, immediately update the SKILL.md roster to match.

## PowerShell/Bash Schema Version Parity (GitHub #12)

WRONG - Bash handles v4.1 schema; PS1 counterpart is never updated and only handles v4.0:
```powershell
# Render-Runtime.ps1 — reads flat v4.0 secretRefs only
if ($profile.secretRefs) {
    foreach ($prop in $profile.secretRefs.PSObject.Properties) { ... }
}
# Silent failure on v4.1 profiles: $profile.secretRefs is null, loop is skipped,
# output file is empty. No error is raised.
```

RIGHT - Mirror the bash logic in PS1, handling both schema versions:
```powershell
# v4.1 bindings first (takes priority, dedup via $seenKeys)
if ($profile.bindings) {
    foreach ($bindType in $profile.bindings.PSObject.Properties) {
        foreach ($component in $bindType.Value.PSObject.Properties) {
            if ($component.Value.secretRefs) {
                foreach ($ref in $component.Value.secretRefs.PSObject.Properties) {
                    # resolve $ref.Value; track key in $seenKeys
                }
            }
        }
    }
}
# v4.0 flat fallback — skip keys already resolved from bindings
if ($profile.secretRefs) {
    foreach ($prop in $profile.secretRefs.PSObject.Properties) {
        if (-not $seenKeys.ContainsKey($prop.Name)) { ... }
    }
}
```

When the profile schema evolves, bash scripts and their PS1 counterparts must be updated together. Schema drift produces empty output (not errors) — making the failure invisible until someone notices missing secrets on Windows.

## Satellite .env Must Include All Keys Downstream Scripts Read (GitHub #22, #23, #24)

WRONG - Creating a satellite `.env` that omits optional keys:
```bash
cat > "$HOME/.admin/.env" <<EOF
ADMIN_ROOT=$ADMIN_ROOT
ADMIN_DEVICE=$DEVICE_NAME
ADMIN_PLATFORM=wsl
EOF
# Missing: ADMIN_SECRETS_BACKEND, ADMIN_PROFILE_REPO, and other optional keys.
# Any downstream script that greps for these keys under pipefail will crash.
```

RIGHT - Include ALL keys that any downstream script may grep for, even with empty values:
```bash
cat > "$HOME/.admin/.env" <<EOF
ADMIN_ROOT=$ADMIN_ROOT
ADMIN_DEVICE=$DEVICE_NAME
ADMIN_PLATFORM=wsl
ADMIN_SECRETS_BACKEND=${SECRETS_BACKEND:-}
ADMIN_PROFILE_REPO=${PROFILE_REPO:-}
EOF
```

Use `assets/satellite-env.template` as the canonical list of required keys. The two-part fix: (1) the writer includes all keys (even empty); (2) the reader appends `|| true` to grep calls for optional keys (see the `grep/pipefail` rule in `platform-cli-rules.md`). Both are required — either alone is insufficient.
