# Connecting to Flywheels

Connection identity lives in two **local-only** places — never in this skill:

1. **Your device profile** (`$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json`) — *which* hosts
   exist: one `servers[]` entry per flywheel, tagged `flywheel`.
2. **Your `~/.ssh/config`** — *how* to reach each one: a `Host` block per `sshAlias`.

If either is missing, run the one-time migration below before using any other part of
the flywheel-admin skill. **Never guess hostnames, IPs, or aliases.**

## The `servers[]` entry shape

```json
{
  "name": "flywheel-1",
  "role": "swarm-host",
  "sshAlias": "flywheel-1",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Ubuntu 24.04 LTS; watch disk headroom"
}
```

- **No IPs in the entry.** Addresses live only in `~/.ssh/config`.
- `sshAlias` is the contract: every command in this skill is `ssh <sshAlias> '...'`.
- `role` distinguishes hosts (`swarm-host`, `hermes-relay`, …).
- `notes` carries per-host facts (OS version, disk headroom, installed extras such as
  PostgreSQL or beads_rust) — the facts this skill's "pick a target" guidance reads.
- `tags` must include `"flywheel"` — fleet enumeration filters on it.

## Resolving the fleet

```bash
source ~/.admin/.env   # ADMIN_ROOT, ADMIN_DEVICE
PROFILE="$ADMIN_ROOT/profiles/$ADMIN_DEVICE.json"

# Enumerate all flywheel hosts: name, role, sshAlias, notes
jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
       | [.name, .role, .sshAlias, (.notes // "")] | @tsv' "$PROFILE"

# Select one host by role
HOST=$(jq -r '.servers[]? | select((.tags // []) | index("flywheel"))
              | select(.role == "swarm-host") | .sshAlias' "$PROFILE" | head -n1)
ssh "$HOST" 'acfs doctor'
```

No matching entries → **STOP** and run the migration below. Do not fall back to
hardcoded hosts.

## Registering your fleet (one-time migration)

Per host, append a `servers[]` entry (back the profile up first):

```bash
cp "$PROFILE" "$PROFILE.bak.$(date +%s)"
jq '.servers = ((.servers // []) + [{
  "name": "flywheel-1",
  "role": "swarm-host",
  "sshAlias": "flywheel-1",
  "provider": "oci",
  "tags": ["flywheel"],
  "notes": "Ubuntu 24.04 LTS"
}])' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
```

Then add a `Host` block per alias to `~/.ssh/config` (WSL/Linux) or
`%USERPROFILE%\.ssh\config` (Windows):

```
Host flywheel-1
  # Tailscale MagicDNS (preferred)
  HostName flywheel-1.<tailnet>.ts.net
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519_flywheel

# Fallback when Tailscale is down: the host's public IP
Host flywheel-1-public
  HostName 203.0.113.10
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519_flywheel
```

`203.0.113.x` is RFC 5737 documentation space — substitute your real values. Keep the
`-public` fallback aliases if your provider exposes a public IP.

## Cross-surface execution

```powershell
# From PowerShell (aliases from %USERPROFILE%\.ssh\config)
ssh flywheel-1 'acfs doctor'

# Force WSL from PowerShell
wsl -e bash -c "ssh flywheel-1 'acfs doctor'"
```

```bash
# From WSL / Linux / Hermes
ssh flywheel-1 'acfs doctor'
```

Each operator surface keeps its own key and ssh config; they work independently.

## VSCode Remote-SSH

Use Microsoft's `ms-vscode-remote.remote-ssh` extension. The Tailscale extension is
unnecessary on a tailnet-joined host.

1. F1 → `Remote-SSH: Connect to Host…`
2. Pick an alias (auto-loaded from your ssh config)
3. Server installs in ~10 s, new window opens

## Sanity check

If `ssh <alias> 'hostname'` works, you're in. If not, in order:

1. `tailscale status` — is the operator on the tailnet?
2. `ping <alias>` — is MagicDNS resolving the flywheel?
3. Try the `-public` alias — is it just MagicDNS that's broken?
4. Check Tailscale admin: https://login.tailscale.com/admin/machines
