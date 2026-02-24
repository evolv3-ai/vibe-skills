# Provider Discovery and Setup

## Contents
- Discover installed provider skills
- Known provider skills
- Add a new provider block

---

## Discover Available Provider References

`devops` stores provider guidance as reference files in `references/`.

Bash:

```bash
refs=(references/*.md)
providers=$(printf '%s\n' "${refs[@]}" | sed 's|.*/||' | sed 's|\\.md$||' | grep -E '^(oci|hetzner|linode|digitalocean|contabo)$')
echo "Available providers: $providers"
```

PowerShell:

```powershell
$refs = Get-ChildItem 'references' -Filter *.md
$providers = $refs | ForEach-Object { $_.BaseName } | Where-Object { $_ -in @('oci','hetzner','linode','digitalocean','contabo') }
Write-Host \"Available providers: $($providers -join ', ')\"\n```

---

## Known Providers (snapshot)

| Provider | Reference | Notes |
|----------|-----------|-------|
| Oracle Cloud | `references/oci.md` | Always Free ARM64 tier; capacity can be limited |
| Hetzner | `references/hetzner.md` | EU‑centric, strong ARM value |
| DigitalOcean | `references/digitalocean.md` | Good US availability; native Kasm autoscale |
| Vultr | Not bundled | Optional provider; add your own reference if needed |
| Linode | `references/linode.md` | Akamai edge integration |
| Contabo | `references/contabo.md` | Best paid price/perf in many regions |

Use the reference file for exact CLI steps.

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
