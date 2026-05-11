# Connecting to Flywheels

The fleet is on tailnet `dwelf-stork.ts.net`. Prefer Tailscale hostnames over IPs from any tailnet-joined client. Public IPs are the fallback when Tailscale is down.

## From the Windows host (WOPR3)

SSH config at `C:\Users\Owner\.ssh\config` defines four aliases. Key is `C:\Users\Owner\.ssh\id_rsa_flywheel` (Owner-read-only).

```powershell
ssh flywheel-1-oci          # Tailscale (preferred)
ssh flywheel-2-oci
ssh flywheel-1-public       # public-IP fallback
ssh flywheel-2-public
```

## From WSL (wsl-hermes)

WSL is on the tailnet too. Key is `~/.ssh/id_rsa` (the original OCI provisioning key).

```bash
ssh ubuntu@flywheel-1-oci
ssh ubuntu@flywheel-2-oci
# Or fully qualified:
ssh ubuntu@flywheel-1-oci.dwelf-stork.ts.net
ssh ubuntu@flywheel-2-oci.dwelf-stork.ts.net
```

## From any tailnet-joined client (no special config)

```bash
ssh ubuntu@100.109.227.110   # flywheel-1
ssh ubuntu@100.73.168.25     # flywheel-2
```

## Without Tailscale (public IPs)

```bash
ssh -i <key> ubuntu@129.153.5.16     # flywheel-1
ssh -i <key> ubuntu@129.213.138.247  # flywheel-2
```

## VSCode Remote-SSH

Use Microsoft's `ms-vscode-remote.remote-ssh` extension. The Tailscale extension is unnecessary on a tailnet-joined host.

1. F1 → `Remote-SSH: Connect to Host…`
2. Pick `flywheel-1-oci` or `flywheel-2-oci` (aliases auto-loaded from `~/.ssh/config`)
3. Server installs in ~10 s, new window opens

Both host keys are already in `known_hosts`.

## Cross-surface execution

```powershell
# From PowerShell
ssh flywheel-2-oci 'acfs doctor'

# Force WSL from PowerShell
wsl -e bash -c "ssh ubuntu@flywheel-2-oci 'acfs doctor'"
```

```bash
# From WSL/Hermes
ssh ubuntu@flywheel-2-oci 'acfs doctor'
```

## Sanity check

If `ssh flywheel-N-oci 'hostname'` works, you're in. If not, in order:

1. `tailscale status` — is the operator on the tailnet?
2. Ping the Tailscale IP — is the flywheel up on the tailnet?
3. Try the public-IP alias — is it just MagicDNS that's broken?
4. Check Tailscale admin: https://login.tailscale.com/admin/machines
