# OCI Operations Reference

Common issues, best practices, configuration variables, and cleanup guidance for Oracle Cloud Infrastructure (OCI).

## Contents
- Common Issues
- Best Practices
- Configuration Reference
- Infrastructure Cleanup

---

## Common Issues

<details>
<summary><strong>OUT_OF_HOST_CAPACITY</strong></summary>

**Error**: "Out of host capacity" when launching ARM64 instances

**Cause**: ARM64 Always Free instances are in high demand

**Solutions**:
1. Try different availability domains:
   ```bash
   ./scripts/check-oci-capacity.sh
   ```
2. Use automated monitoring:
   ```bash
   ./scripts/monitor-and-deploy.sh --stack-id <STACK_OCID>
   ```
3. Try different regions
4. Try smaller configuration (2 OCPU / 12GB)

</details>

<details>
<summary><strong>Authentication failures</strong></summary>

**Error**: `ServiceError: NotAuthenticated`

**Causes & fixes**:
- API key not uploaded: Add public key in OCI Console → Profile → API Keys
- Wrong fingerprint: Verify `~/.oci/config` matches OCI Console
- Key permissions: Run `chmod 600 ~/.oci/oci_api_key.pem`
- Clock skew: Sync system time

See [Configuration Guide](references/CONFIG.md) for details.

</details>

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Error**: Connection refused or timeout

**Checklist**:
1. Security list has port 22 ingress rule
2. Instance has public IP assigned
3. Internet gateway exists and route table configured
4. Correct SSH key pair used
5. Wait 1-2 minutes after instance launch

```bash
# Verify instance state
oci compute instance get --instance-id <INSTANCE_OCID> --query 'data."lifecycle-state"'

# Check public IP
oci compute instance list-vnics --instance-id <INSTANCE_OCID> --query 'data[0]."public-ip"'
```

</details>

<details>
<summary><strong>Shape not available</strong></summary>

**Error**: "Shape VM.Standard.A1.Flex not available"

**Cause**: Using incompatible image/shape combination

**Fix**: Match image architecture to shape:
- ARM64 shape (A1.Flex) → ARM64 image
- x86 shape → x86 image

```bash
# Find ARM64 Ubuntu images
oci compute image list \
  --compartment-id $TENANCY_OCID \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --query 'data[?contains("display-name", `22.04`)].id'
```

</details>

<details>
<summary><strong>Service limit exceeded</strong></summary>

**Error**: "Service limit exceeded" for A1 instances

**Cause**: Total OCPUs/memory exceeds Always Free limit (4 OCPU / 24GB)

**Fix**: Check existing instances:
```bash
oci compute instance list \
  --compartment-id $COMPARTMENT_ID \
  --query 'data[?contains("shape", `A1`)].{name:"display-name", shape:"shape", state:"lifecycle-state"}'
```

Stay within 4 OCPU + 24GB total across all A1 instances.

</details>

---

## Best Practices

<details>
<summary><strong>Always do</strong></summary>

✅ Use `VM.Standard.A1.Flex` for Always Free tier
✅ Check capacity before deployment
✅ Create dedicated compartments (not tenancy root)
✅ Use 10.0.0.0/8 private IP ranges
✅ Enable internet gateway for outbound access
✅ Add SSH security rule (port 22)
✅ Save all OCIDs for future reference
✅ Use `--wait-for-state` flags for reliability

</details>

<details>
<summary><strong>Never do</strong></summary>

❌ Use x86 shapes for Always Free (only ARM64 qualifies)
❌ Exceed 4 OCPUs / 24GB RAM total for A1 instances
❌ Delete compartment with active resources
❌ Delete resources out of order (see "Infrastructure Cleanup" section)
❌ Use overlapping CIDR blocks between VCNs
❌ Hardcode OCIDs (use environment variables)
❌ Skip `--wait-for-state` (resources need time to provision)

</details>

---

## Configuration Reference

<details>
<summary><strong>Environment variables</strong></summary>

Required:
```bash
TENANCY_OCID=ocid1.tenancy.oc1..xxx
USER_OCID=ocid1.user.oc1..xxx
REGION=us-ashburn-1
FINGERPRINT=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
PRIVATE_KEY_PATH=~/.oci/oci_api_key.pem
```

Optional (with defaults):
```bash
COMPARTMENT_NAME=coolify-compartment
VCN_CIDR=10.0.0.0/16
SUBNET_CIDR=10.0.1.0/24
INSTANCE_SHAPE=VM.Standard.A1.Flex
INSTANCE_OCPUS=2        # 1-4
INSTANCE_MEMORY_GB=12   # 1-24
SERVICE_TYPE=coolify    # coolify|kasm|both
```

</details>

<details>
<summary><strong>Server type configurations</strong></summary>

**Coolify** (default):
- 2 OCPU, 12GB RAM, 100GB storage
- Ports: 22, 80, 443, 8000, 6001, 6002

**KASM**:
- 4 OCPU, 24GB RAM, 80GB storage
- Ports: 22, 8443, 3389, 3000-4000

**Both**:
- 4 OCPU, 24GB RAM, 150GB storage
- All ports from both configurations

</details>

<details>
<summary><strong>Always Free tier limits</strong></summary>

| Resource | Limit |
|----------|-------|
| ARM Compute (A1.Flex) | 4 OCPUs + 24GB RAM total |
| Block Storage | 200GB total |
| Object Storage | 20GB |
| Outbound Data | 10TB/month |

Split across instances as needed (e.g., 2×2 OCPU or 1×4 OCPU).

</details>

---

## Infrastructure Cleanup

> **CRITICAL**: OCI resources have strict dependency ordering. Deleting in the wrong order causes "Conflict" errors. **Always follow this exact sequence.**

### Resource Dependency Chain

```
Compartment (delete last, or keep)
└── VCN
    ├── Internet Gateway ← referenced by Route Table
    ├── Route Table ← references Internet Gateway
    ├── Security List ← referenced by Subnet
    └── Subnet ← references Security List, Route Table
        └── Compute Instance (delete first)
```

### Correct Deletion Order

**Step 1: Terminate Compute Instances**
```bash
oci compute instance terminate \
  --instance-id $INSTANCE_ID \
  --preserve-boot-volume false \
  --force \
  --wait-for-state TERMINATED
```

**Step 2: Delete Subnet**
```bash
oci network subnet delete \
  --subnet-id $SUBNET_ID \
  --force \
  --wait-for-state TERMINATED
```

**Step 3: Clear Route Table Rules** (removes gateway reference)
```bash
oci network route-table update \
  --route-table-id $ROUTE_TABLE_ID \
  --route-rules '[]' \
  --force
```

**Step 4: Delete Internet Gateway**
```bash
oci network internet-gateway delete \
  --ig-id $INTERNET_GATEWAY_ID \
  --force \
  --wait-for-state TERMINATED
```

**Step 5: Delete Security List** (if custom, not default)
```bash
oci network security-list delete \
  --security-list-id $SECURITY_LIST_ID \
  --force \
  --wait-for-state TERMINATED
```

**Step 6: Delete Route Table** (if custom, not default)
```bash
oci network route-table delete \
  --rt-id $ROUTE_TABLE_ID \
  --force \
  --wait-for-state TERMINATED
```

**Step 7: Delete VCN**
```bash
oci network vcn delete \
  --vcn-id $VCN_ID \
  --force \
  --wait-for-state TERMINATED
```

**Step 8: Delete Compartment** (optional - only if explicitly requested)
```bash
# WARNING: This is permanent! Only delete if user explicitly confirms.
oci iam compartment delete \
  --compartment-id $COMPARTMENT_ID \
  --force
```

### Quick Reference Table

| Order | Resource | Delete Command | Wait State |
|-------|----------|----------------|------------|
| 1 | Instance | `oci compute instance terminate` | TERMINATED |
| 2 | Subnet | `oci network subnet delete` | TERMINATED |
| 3 | Route Table | `oci network route-table update --route-rules '[]'` | (none) |
| 4 | Internet Gateway | `oci network internet-gateway delete` | TERMINATED |
| 5 | Security List | `oci network security-list delete` | TERMINATED |
| 6 | Route Table | `oci network route-table delete` | TERMINATED |
| 7 | VCN | `oci network vcn delete` | TERMINATED |
| 8 | Compartment | `oci iam compartment delete` | (async) |

### Common Cleanup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Subnet ... references Security List" | Deleting security list before subnet | Delete subnet first |
| "Route Table ... references Internet Gateway" | Deleting IGW before clearing routes | Clear route rules first |
| "VCN still has resources" | Resources still attached | Delete all children first |
| "Compartment not empty" | Resources in compartment | Delete all resources first |

### Using the Cleanup Script

For automated cleanup with dependency handling:

```bash
./scripts/cleanup-compartment.sh $COMPARTMENT_OCID
```

This script handles the ordering automatically but requires confirmation.

