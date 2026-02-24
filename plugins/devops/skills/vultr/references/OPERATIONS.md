# Vultr Operations Reference

Troubleshooting, best practices, configuration variables, and cost snapshots for Vultr.

## Contents
- Troubleshooting
- Best Practices
- Configuration Reference
- Cost Comparison

---

## Troubleshooting

<details>
<summary><strong>Instance creation fails</strong></summary>

**Common causes**:
1. Invalid region (check `vultr-cli regions list`)
2. Invalid plan for region (check `vultr-cli plans list`)
3. SSH key not found (check `vultr-cli ssh-key list`)
4. API key permissions (needs full access)

**Fix**: Verify each component separately:
```bash
vultr-cli regions list
vultr-cli plans list
vultr-cli ssh-key list
vultr-cli account
```

</details>

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Checklist**:
1. Instance is running: `vultr-cli instance list`
2. Firewall allows port 22: `vultr-cli firewall rule list --id $FW_GROUP_ID`
3. Correct SSH key used
4. Wait 60-90 seconds after creation

**Debug**:
```bash
# Check instance status
vultr-cli instance get "$INSTANCE_ID"

# Check firewall
vultr-cli firewall rule list --id "$FW_GROUP_ID"

# Try with verbose SSH
ssh -v root@$SERVER_IP
```

</details>

<details>
<summary><strong>Plan not available in region</strong></summary>

Not all plans are available in every region.

**Check availability**:
```bash
vultr-cli plans list --type vc2
```

Use a different region or plan if unavailable.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

- Use High-Frequency plans for I/O intensive workloads
- Create dedicated firewall groups
- Use SSH keys (not password auth)
- Choose region closest to your users
- Enable backups for production
- Use labels to organize instances

</details>

<details>
<summary><strong>Never do</strong></summary>

- Share API keys across projects
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
VULTR_API_KEY=...                # API key from settings

# Deployment configuration
VULTR_REGION=ewr                 # Region code
VULTR_PLAN=vc2-2c-4gb            # Plan ID
VULTR_OS_ID=1743                 # OS ID (Ubuntu 22.04)
SERVER_NAME=my-server   # Instance label
SSH_KEY_NAME=my-key       # SSH key name in Vultr

# Outputs (set after deployment)
SERVER_IP=...                    # Public IP
SSH_USER=root                    # SSH username
SSH_KEY_PATH=~/.ssh/id_rsa       # Local private key path
```

</details>

<details>
<summary><strong>Plan reference</strong></summary>

**Cloud Compute (VC2)**:
| Plan | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| vc2-1c-1gb | 1 | 1GB | 25GB | $6 |
| vc2-1c-2gb | 1 | 2GB | 55GB | $12 |
| vc2-2c-4gb | 2 | 4GB | 80GB | $24 |
| vc2-4c-8gb | 4 | 8GB | 160GB | $48 |
| vc2-6c-16gb | 6 | 16GB | 320GB | $96 |
| vc2-8c-32gb | 8 | 32GB | 640GB | $192 |

**High-Frequency (VHF)**:
| Plan | vCPU | RAM | Disk | Price/month |
|------|------|-----|------|-------------|
| vhf-1c-2gb | 1 | 2GB | 32GB NVMe | $12 |
| vhf-2c-4gb | 2 | 4GB | 64GB NVMe | $24 |
| vhf-3c-8gb | 3 | 8GB | 128GB NVMe | $48 |
| vhf-4c-16gb | 4 | 16GB | 256GB NVMe | $72 |
| vhf-6c-24gb | 6 | 24GB | 384GB NVMe | $108 |

</details>

---

## Cost Comparison

_Prices below are snapshots and may change; verify in the Vultr console._

| Provider | 4 vCPU, 8GB | Monthly |
|----------|-------------|---------|
| **Vultr vc2-4c-8gb** | 4 vCPU, 8GB | **$48** |
| DigitalOcean s-4vcpu-8gb | 4 vCPU, 8GB | $48 |
| Hetzner CAX21 | 4 vCPU ARM, 8GB | ~$8 |
| Contabo VPS 20 SP | 6 vCPU, 18GB | ~$8 |

Vultr offers excellent performance with High-Frequency NVMe plans and extensive global coverage.

