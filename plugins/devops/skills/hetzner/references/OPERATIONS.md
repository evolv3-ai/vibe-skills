# Hetzner Operations Reference

Troubleshooting, best practices, configuration variables, and cost snapshots for Hetzner Cloud.

## Contents
- Troubleshooting
- Best Practices
- Configuration Reference
- Cost Comparison

---

## Troubleshooting

<details>
<summary><strong>Server creation fails</strong></summary>

**Common causes**:
1. Invalid server type for location (check `hcloud server-type list --location $HETZNER_LOCATION`)
2. SSH key not found (check `hcloud ssh-key list`)
3. API token permissions (needs Read & Write)

**Fix**: Verify each component separately:
```bash
hcloud server-type list --location "$HETZNER_LOCATION"
hcloud ssh-key list
hcloud context active
```

</details>

<details>
<summary><strong>Cannot SSH to server</strong></summary>

**Checklist**:
1. Server is running: `hcloud server list`
2. Firewall allows port 22: `hcloud firewall describe my-firewall`
3. Correct SSH key used
4. Wait 30-60 seconds after creation

**Debug**:
```bash
# Check server status
hcloud server describe "$SERVER_NAME"

# Verify firewall
hcloud firewall describe my-firewall

# Try with verbose SSH
ssh -v root@$SERVER_IP
```

</details>

<details>
<summary><strong>Server type not available</strong></summary>

Some server types aren't available in all locations.

**Check availability**:
```bash
hcloud server-type list --location "$HETZNER_LOCATION"
```

**ARM servers (CAX)** are available in: nbg1, fsn1, hel1 (not US locations)

For US locations, use x86 types: CX22, CX32, etc.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

- Use ARM servers (CAX) for best price/performance
- Create dedicated firewall rules (don't use default)
- Use SSH keys (not password auth)
- Choose location closest to your users
- Use meaningful server names

</details>

<details>
<summary><strong>Never do</strong></summary>

- Share API tokens across projects
- Leave all ports open (use firewall)
- Use password authentication
- Delete resources without confirming

</details>

---

## Configuration Reference

<details>
<summary><strong>Environment variables</strong></summary>

```bash
# Required
HETZNER_API_TOKEN=...           # API token from console

# Deployment configuration
HETZNER_LOCATION=nbg1           # nbg1, fsn1, hel1, ash, hil
HETZNER_SERVER_TYPE=cax21       # Server type
HETZNER_IMAGE=ubuntu-22.04      # OS image
SERVER_NAME=my-server   # Server name
SSH_KEY_NAME=my-key      # SSH key name in Hetzner

# Outputs (set after deployment)
SERVER_IP=...                   # Public IP
SSH_USER=root                   # SSH username
SSH_KEY_PATH=~/.ssh/id_rsa      # Local private key path
```

</details>

<details>
<summary><strong>Server type reference</strong></summary>

**ARM (Ampere) - Best value**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| cax11 | 2 | 4GB | 40GB | ~$4 |
| cax21 | 4 | 8GB | 80GB | ~$8 |
| cax31 | 8 | 16GB | 160GB | ~$16 |
| cax41 | 16 | 32GB | 320GB | ~$30 |

**x86 (Intel/AMD)**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| cx22 | 2 | 4GB | 40GB | ~$5 |
| cx32 | 4 | 8GB | 80GB | ~$10 |
| cx42 | 8 | 16GB | 160GB | ~$20 |
| cx52 | 16 | 32GB | 320GB | ~$40 |

</details>

---

## Cost Comparison

_Prices below are snapshots and may change; verify in the Hetzner console._

| Provider | 4 vCPU ARM, 8GB | Monthly |
|----------|-----------------|---------|
| **Hetzner CAX21** | 4 vCPU ARM, 8GB | **~$8** |
| OCI Always Free | 4 OCPU ARM, 24GB | $0 |
| DigitalOcean | 4 vCPU, 8GB | $48 |
| AWS t4g.medium | 2 vCPU ARM, 4GB | ~$25 |

Hetzner offers the best paid option when OCI capacity is unavailable.

