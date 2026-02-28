# DigitalOcean Operations Reference

Troubleshooting, best practices, configuration variables, and cost snapshots for DigitalOcean.

## Contents
- Troubleshooting
- Best Practices
- Configuration Reference
- Cost Comparison

---

## Troubleshooting

<details>
<summary><strong>Droplet creation fails</strong></summary>

**Common causes**:
1. Invalid region (check `doctl compute region list`)
2. Invalid size for region (check `doctl compute size list`)
3. SSH key not found (check `doctl compute ssh-key list`)
4. API token permissions (needs Read & Write)

**Fix**: Verify each component separately:
```bash
doctl compute region list
doctl compute size list
doctl compute ssh-key list
doctl account get
```

</details>

<details>
<summary><strong>Cannot SSH to droplet</strong></summary>

**Checklist**:
1. Droplet is running: `doctl compute droplet list`
2. Firewall allows port 22: `doctl compute firewall list-by-droplet $DROPLET_ID`
3. Correct SSH key used
4. Wait 30-60 seconds after creation

**Debug**:
```bash
# Check droplet status
doctl compute droplet get "$SERVER_NAME"

# Check firewall
doctl compute firewall get "$FIREWALL_ID"

# Try with verbose SSH
ssh -v root@$SERVER_IP
```

</details>

<details>
<summary><strong>Droplet size not available</strong></summary>

Some droplet sizes aren't available in all regions.

**Check availability**:
```bash
doctl compute size list --output json | jq '.[] | select(.regions[] == "nyc1") | .slug'
```

Replace `nyc1` with your target region.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

- Use tags to organize resources (`--tag-names "myproject"`)
- Create dedicated firewall rules (don't use default)
- Use SSH keys (not password auth)
- Choose region closest to your users
- Enable backups for production (`--enable-backups`)
- Use VPC for multi-droplet setups

</details>

<details>
<summary><strong>Never do</strong></summary>

- Share API tokens across projects
- Leave all ports open (use firewall)
- Use password authentication
- Delete resources without confirming
- Skip firewall configuration

</details>

---

## Configuration Reference

<details>
<summary><strong>Environment variables</strong></summary>

```bash
# Required
DIGITALOCEAN_ACCESS_TOKEN=...    # API token from console

# Deployment configuration
DO_REGION=nyc1                   # Region code
DO_SIZE=s-2vcpu-4gb              # Droplet size
DO_IMAGE=ubuntu-22-04-x64        # OS image
SERVER_NAME=my-server    # Droplet name
SSH_KEY_NAME=my-key       # SSH key name in DigitalOcean

# Outputs (set after deployment)
SERVER_IP=...                    # Public IP
SSH_USER=root                    # SSH username
SSH_KEY_PATH=~/.ssh/id_rsa       # Local private key path
```

</details>

<details>
<summary><strong>Droplet size reference</strong></summary>

**Basic (Shared CPU)**:
| Size | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| s-1vcpu-1gb | 1 | 1GB | 25GB | $6 |
| s-1vcpu-2gb | 1 | 2GB | 50GB | $12 |
| s-2vcpu-4gb | 2 | 4GB | 80GB | $24 |
| s-4vcpu-8gb | 4 | 8GB | 160GB | $48 |
| s-8vcpu-16gb | 8 | 16GB | 320GB | $96 |

**Premium (Dedicated CPU)**:
| Size | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| c-2-4gib | 2 | 4GB | 25GB | $42 |
| c-4-8gib | 4 | 8GB | 50GB | $84 |
| c-8-16gib | 8 | 16GB | 100GB | $168 |
| c-16-32gib | 16 | 32GB | 200GB | $336 |

</details>

---

## Cost Comparison

_Prices below are snapshots and may change; verify in the DigitalOcean console._

| Provider | 4 vCPU, 8GB | Monthly |
|----------|-------------|---------|
| **DigitalOcean s-4vcpu-8gb** | 4 vCPU, 8GB | **$48** |
| Hetzner CAX21 | 4 vCPU ARM, 8GB | ~$8 |
| Vultr High-Frequency | 6 vCPU, 16GB | $96 |
| Linode Dedicated 4GB | 6 vCPU, 12GB | $108 |

DigitalOcean offers excellent US availability and native Kasm integration at competitive pricing.

