# Provider Discovery and Setup

## Contents
- Discover installed provider skills
- Known provider skills
- Add a new provider block

---

## Discover Installed Provider Skills

Provider guidance lives in dedicated sibling skills under the same plugin. List them:

Bash:

```bash
ls -d "${SKILL_DIR}/../"{oci,hetzner,linode,digital-ocean,contabo,vultr} 2>/dev/null
```

PowerShell:

```powershell
Get-ChildItem (Split-Path $env:SKILL_DIR) -Directory |
  Where-Object { $_.Name -in @('oci','hetzner','linode','digital-ocean','contabo','vultr') } |
  Select-Object -ExpandProperty Name
```

---

## Known Provider Skills

| Provider | Skill | Notes |
|----------|-------|-------|
| Oracle Cloud | `oci` | Always Free ARM64 tier; capacity can be limited |
| Hetzner | `hetzner` | EU-centric, strong ARM value |
| DigitalOcean | `digital-ocean` | Good US availability; native Kasm autoscale |
| Vultr | `vultr` | x86 cloud provider |
| Linode | `linode` | Akamai edge integration |
| Contabo | `contabo` | Best paid price/perf in many regions |

Use the dedicated provider skill for exact CLI steps.

---

## Add a New Provider Block

Example: add Hetzner provider to inventory.

Bash:

```bash
cat >> .agent-devops.env << 'EOF'

# Hetzner Cloud
PROVIDER_HETZNER_TYPE=hetzner
PROVIDER_HETZNER_AUTH_METHOD=file
PROVIDER_HETZNER_AUTH_FILE=~/.config/hcloud/token
PROVIDER_HETZNER_DEFAULT_REGION=nbg1
PROVIDER_HETZNER_LABEL=Hetzner Cloud
EOF
```

PowerShell:

```powershell
@"

# Hetzner Cloud
PROVIDER_HETZNER_TYPE=hetzner
PROVIDER_HETZNER_AUTH_METHOD=file
PROVIDER_HETZNER_AUTH_FILE=~/.config/hcloud/token
PROVIDER_HETZNER_DEFAULT_REGION=nbg1
PROVIDER_HETZNER_LABEL=Hetzner Cloud
"@ | Add-Content .agent-devops.env
```
