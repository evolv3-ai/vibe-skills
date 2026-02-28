# Linode Operations Reference

Troubleshooting, best practices, configuration variables, and cost snapshots for Linode (Akamai Cloud).

## Contents
- Troubleshooting
- Best Practices
- Configuration Reference
- Cost Comparison

---

## Troubleshooting

<details>
<summary><strong>Linode creation fails</strong></summary>

**Common causes**:
1. Invalid region (check `linode-cli regions list`)
2. Invalid type for region (check `linode-cli linodes types`)
3. SSH key not found (check `linode-cli sshkeys list`)
4. API token permissions (needs Read/Write)

**Fix**: Verify each component separately:
```bash
linode-cli regions list
linode-cli linodes types
linode-cli sshkeys list
linode-cli account view
```

</details>

<details>
<summary><strong>Cannot SSH to Linode</strong></summary>

**Checklist**:
1. Linode is running: `linode-cli linodes list`
2. Firewall allows port 22: `linode-cli firewalls rules-list $FIREWALL_ID`
3. Correct SSH key used
4. Wait 60-90 seconds after creation

**Debug**:
```bash
# Check Linode status
linode-cli linodes view "$LINODE_ID"

# Check firewall rules
linode-cli firewalls rules-list "$FIREWALL_ID"

# Try with verbose SSH
ssh -v root@$SERVER_IP
```

</details>

<details>
<summary><strong>Type not available in region</strong></summary>

Not all Linode types are available in every region.

**Check availability**:
```bash
linode-cli linodes types --format id,label,region_prices
```

Use a different region or type if unavailable.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

- Use Dedicated CPU for production workloads
- Create dedicated firewall rules
- Use SSH keys (not password auth)
- Choose region closest to your users
- Enable backups for production
- Use VLANs for private networking

</details>

<details>
<summary><strong>Never do</strong></summary>

- Share API tokens across projects
- Leave all ports open (use firewall)
- Use password authentication alone
- Delete resources without confirming
- Skip firewall configuration

</details>

---

## Configuration Reference

<details>
<summary><strong>Environment variables</strong></summary>

```bash
# Required
LINODE_CLI_TOKEN=...             # API token from profile

# Deployment configuration
LINODE_REGION=us-east            # Region code
LINODE_TYPE=g6-standard-2        # Linode type
LINODE_IMAGE=linode/ubuntu22.04  # OS image
SERVER_NAME=my-server    # Linode label
SSH_KEY_LABEL=my-key      # SSH key label

# Outputs (set after deployment)
SERVER_IP=...                    # Public IP
SSH_USER=root                    # SSH username
SSH_KEY_PATH=~/.ssh/id_rsa       # Local private key path
```

</details>

<details>
<summary><strong>Linode type reference</strong></summary>

**Shared CPU (Standard)**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| g6-nanode-1 | 1 | 1GB | 25GB | $5 |
| g6-standard-1 | 1 | 2GB | 50GB | $12 |
| g6-standard-2 | 2 | 4GB | 80GB | $24 |
| g6-standard-4 | 4 | 8GB | 160GB | $48 |
| g6-standard-6 | 6 | 16GB | 320GB | $96 |
| g6-standard-8 | 8 | 32GB | 640GB | $192 |

**Dedicated CPU**:
| Type | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| g6-dedicated-2 | 2 | 4GB | 80GB | $36 |
| g6-dedicated-4 | 4 | 8GB | 160GB | $72 |
| g6-dedicated-8 | 8 | 16GB | 320GB | $144 |
| g6-dedicated-16 | 16 | 32GB | 640GB | $288 |

</details>

---

## Cost Comparison

_Prices below are snapshots and may change; verify in the Linode console._

| Provider | 4 vCPU, 8GB | Monthly |
|----------|-------------|---------|
| **Linode g6-standard-4** | 4 vCPU, 8GB | **$48** |
| DigitalOcean s-4vcpu-8gb | 4 vCPU, 8GB | $48 |
| Vultr vc2-4c-8gb | 4 vCPU, 8GB | $48 |
| Hetzner CAX21 | 4 vCPU ARM, 8GB | ~$8 |

Linode offers strong Kubernetes support with Akamai edge network integration.

