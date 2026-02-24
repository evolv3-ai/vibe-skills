# OCI Infrastructure

_Consolidated from `skills/admin-devops (oci)` on 2026-02-02_

## Skill Body

# Oracle Cloud Infrastructure (OCI)

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Status**: Production Ready | **Dependencies**: OCI CLI, SSH key pair

---

## Navigation

- Operations, troubleshooting, config, and cleanup: `references/OPERATIONS.md`
- CLI install/config/capacity/networking details: `docs/`

---

## Step 0: Gather Required Information (MANDATORY)

**STOP. Before ANY deployment commands, collect ALL parameters from the user.**

Copy this checklist and confirm each item:

```
Required Parameters:
- [ ] SERVER_NAME       - Unique name for this server
- [ ] OCI_REGION        - Region (us-ashburn-1, us-phoenix-1, ca-toronto-1, etc.)
- [ ] OCI_SHAPE         - Instance shape (see profiles below)
- [ ] OCI_OCPUS         - Number of OCPUs (1-4 for Always Free)
- [ ] OCI_MEMORY_GB     - Memory in GB (1-24 for Always Free)
- [ ] SSH_KEY_PATH      - Path to SSH public key (default: ~/.ssh/id_rsa.pub)

Deployment Purpose (determines recommended profile):
- [ ] Purpose: coolify / kasm / both / custom
      coolify → 2 OCPU, 12GB RAM (Always Free eligible)
      kasm    → 4 OCPU, 24GB RAM (Always Free eligible)
      both    → 4 OCPU, 24GB RAM (Always Free eligible)

Always Free Tier Limits:
- Shape: VM.Standard.A1.Flex (ARM64)
- Max: 4 OCPUs, 24GB RAM total (can split across instances)
```

**Recommended profiles by purpose:**

| Purpose | OCPUs | RAM | Shape | Cost |
|---------|-------|-----|-------|------|
| coolify | 2 | 12GB | VM.Standard.A1.Flex | FREE |
| kasm | 4 | 24GB | VM.Standard.A1.Flex | FREE |
| both | 4 | 24GB | VM.Standard.A1.Flex | FREE |

**DO NOT proceed to Prerequisites until ALL parameters are confirmed.**

---

## Prerequisites

Before using this skill, verify the following:

### 1. OCI CLI Installed

```bash
oci --version
```

**If missing**, install with:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
source ~/.bashrc  # or restart terminal
```

### 2. OCI CLI Configured

```bash
ls ~/.oci/config
```

**If missing**, configure with:
```bash
oci setup config
```

You'll need:
- Tenancy OCID (OCI Console → Profile → Tenancy)
- User OCID (OCI Console → Profile → My Profile)
- Region (e.g., us-ashburn-1)
- API key pair (wizard generates this)

### 3. SSH Key Pair

```bash
ls ~/.ssh/id_rsa.pub
```

**If missing**, generate with:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 4. SSH Key Permissions

```bash
stat -c %a ~/.ssh/id_rsa  # Should be 600
```

**If wrong**, fix with:
```bash
chmod 600 ~/.ssh/id_rsa
```

### 5. Test Authentication

```bash
oci iam availability-domain list
```

**If this fails**: API key may not be uploaded to OCI Console → Profile → API Keys

---

## Quick Start

### 1. Check Capacity First

OCI Always Free ARM instances are highly demanded. **Always check before deploying:**

```bash
./scripts/oci-check-oci-capacity.sh
```

<details>
<summary><strong>Options and troubleshooting</strong></summary>

```bash
# Check specific region
./scripts/oci-check-oci-capacity.sh us-ashburn-1

# Use different OCI profile
./scripts/oci-check-oci-capacity.sh --profile PRODUCTION

# Check multiple regions
for region in us-ashburn-1 us-phoenix-1 ca-toronto-1; do
  echo "=== $region ==="
  ./scripts/oci-check-oci-capacity.sh "$region"
done
```

**No capacity?** Use automated monitoring:

```bash
./scripts/oci-monitor-and-deploy.sh --stack-id <STACK_OCID>
```

</details>

### 2. Deploy Infrastructure

```bash
# Configure environment
cp scripts/.env.example scripts/.env
# Edit scripts/.env with your values

# Deploy
./scripts/oci-infrastructure-setup.sh
```

---

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `oci-check-oci-capacity.sh` | Check ARM instance availability | `./scripts/oci-check-oci-capacity.sh [region]` |
| `oci-infrastructure-setup.sh` | Full infrastructure deployment | `./scripts/oci-infrastructure-setup.sh` |
| `oci-monitor-and-deploy.sh` | Auto-deploy when capacity available | `./scripts/oci-monitor-and-deploy.sh --stack-id <ID>` |
| `oci-cleanup-compartment.sh` | Delete all resources | `./scripts/oci-cleanup-compartment.sh <COMPARTMENT_OCID>` |

<details>
<summary><strong>Script details</strong></summary>

### oci-check-oci-capacity.sh

Checks VM.Standard.A1.Flex availability across availability domains.

```bash
./scripts/oci-check-oci-capacity.sh                    # Home region
./scripts/oci-check-oci-capacity.sh us-ashburn-1       # Specific region
./scripts/oci-check-oci-capacity.sh --profile DANIEL   # With profile
```

Tests 4 OCPU / 24GB RAM (full free tier), falls back to 2/12 if unavailable.

### oci-monitor-and-deploy.sh

Continuously monitors and auto-deploys when capacity found.

```bash
./scripts/oci-monitor-and-deploy.sh \
  --stack-id <STACK_OCID> \
  --profile DANIEL \
  --interval 300 \
  --max-attempts 100
```

### oci-infrastructure-setup.sh

Creates complete infrastructure: compartment → VCN → subnet → IGW → security list → instance.

Requires `.env` file with OCI credentials and configuration.

### oci-cleanup-compartment.sh

Safely deletes compartment and all resources (requires confirmation).

```bash
./scripts/oci-cleanup-compartment.sh ocid1.compartment.oc1..xxx
```

</details>

---

## Operations

Common issues, best practices, configuration variables, and cleanup ordering are in `references/OPERATIONS.md`.

---

## Logging Integration

When performing infrastructure operations, log to the centralized system:

```bash
# After provisioning
log_admin "SUCCESS" "operation" "Provisioned OCI instance" "id=$INSTANCE_ID provider=OCI"

# After destroying
log_admin "SUCCESS" "operation" "Terminated OCI instance" "id=$INSTANCE_ID"

# On error
log_admin "ERROR" "operation" "OCI deployment failed" "error=OUT_OF_HOST_CAPACITY"
```

See `admin` skill's `references/logging.md` for full logging documentation.

---

## Additional Documentation

- [Installation Guide](docs/INSTALL.md) - Install OCI CLI on any OS
- [Configuration Guide](docs/CONFIG.md) - Set up OCI credentials
- [Capacity Guide](docs/CAPACITY.md) - Handling capacity issues
- [Networking Guide](docs/NETWORKING.md) - VCN, subnets, security lists
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions

---

## Official Resources

- [OCI Documentation](https://docs.oracle.com/en-us/iaas/Content/home.htm)
- [OCI CLI Reference](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/)
- [Always Free Tier](https://www.oracle.com/cloud/free/)
- [ARM Instances Guide](https://docs.oracle.com/en-us/iaas/Content/Compute/References/arm.htm)

## Reference Appendices

### oci: references/OPERATIONS.md

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
   ./scripts/oci-check-oci-capacity.sh
   ```
2. Use automated monitoring:
   ```bash
   ./scripts/oci-monitor-and-deploy.sh --stack-id <STACK_OCID>
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

See [Configuration Guide](docs/CONFIG.md) for details.

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
./scripts/oci-cleanup-compartment.sh $COMPARTMENT_OCID
```

This script handles the ordering automatically but requires confirmation.

### oci: docs/CAPACITY.md

# OCI Capacity Guide

**Purpose**: Handle ARM instance capacity issues on OCI Always Free tier.
**Prerequisites**: [OCI CLI configured](./CONFIG.md)

---

## Contents
- Understanding Capacity
- Checking Capacity
- Automated Monitoring
- Strategies for Getting Capacity
- Understanding Availability Domains
- Error Messages
- Creating Resource Manager Stacks
- Quick Reference
- Next Steps

---

## Understanding Capacity

ARM A1.Flex instances on OCI Always Free tier are highly demanded. "OUT_OF_HOST_CAPACITY" errors are common and expected.

### Key Points

- Capacity varies by **availability domain** (AD) within a region
- Capacity fluctuates throughout the day
- Different regions have different availability
- You can split resources across ADs (e.g., 2 OCPU in AD-1, 2 OCPU in AD-2)

---

## Checking Capacity

### Quick Check

```bash
./scripts/oci-check-oci-capacity.sh
```

### Options

```bash
# Specific region
./scripts/oci-check-oci-capacity.sh us-ashburn-1

# With specific OCI profile
./scripts/oci-check-oci-capacity.sh --profile PRODUCTION

# Check multiple regions
for region in us-ashburn-1 us-phoenix-1 ca-toronto-1 ca-montreal-1; do
  echo "=== Checking $region ==="
  ./scripts/oci-check-oci-capacity.sh "$region"
done
```

<details>
<summary><strong>Manual capacity check</strong></summary>

```bash
# List availability domains
oci iam availability-domain list --query 'data[*].name' --output table

# Try to launch (dry-run style) - will fail with OUT_OF_HOST_CAPACITY if unavailable
oci compute instance launch \
  --availability-domain "xxxx:US-ASHBURN-AD-1" \
  --compartment-id $COMPARTMENT_ID \
  --shape VM.Standard.A1.Flex \
  --shape-config '{"ocpus":4,"memoryInGBs":24}' \
  --dry-run
```

</details>

---

## Automated Monitoring

When capacity is unavailable, use automated monitoring to deploy when it becomes available:

```bash
./scripts/oci-monitor-and-deploy.sh --stack-id <STACK_OCID>
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--stack-id` | Resource Manager stack OCID (required) | - |
| `--profile` | OCI CLI profile | DEFAULT |
| `--interval` | Check interval in seconds | 180 (3 min) |
| `--region` | Region to check | Profile default |
| `--ocpus` | OCPUs to check for | 4 |
| `--memory-gb` | Memory to check for | 24 |
| `--max-attempts` | Stop after N attempts | unlimited |
| `--notify-command` | Command to run on success | - |

### Examples

```bash
# Basic monitoring
./scripts/oci-monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1..xxx

# Custom interval and limits
./scripts/oci-monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --interval 300 \
  --max-attempts 100

# With notification
./scripts/oci-monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --notify-command "curl -X POST https://hooks.slack.com/..."

# Check for smaller config
./scripts/oci-monitor-and-deploy.sh \
  --stack-id ocid1.ormstack.oc1..xxx \
  --ocpus 2 \
  --memory-gb 12
```

---

## Strategies for Getting Capacity

<details>
<summary><strong>1. Try different availability domains</strong></summary>

Each region has 1-3 availability domains. Check all of them:

```bash
./scripts/oci-check-oci-capacity.sh
```

The script automatically checks all ADs in your region.

</details>

<details>
<summary><strong>2. Try different regions</strong></summary>

Some regions have more capacity than others. Good options:

| Region | Identifier | Notes |
|--------|------------|-------|
| US East (Ashburn) | us-ashburn-1 | Popular but large |
| US West (Phoenix) | us-phoenix-1 | Often available |
| Canada (Toronto) | ca-toronto-1 | Good availability |
| Canada (Montreal) | ca-montreal-1 | Good availability |
| UK (London) | uk-london-1 | European option |
| Germany (Frankfurt) | eu-frankfurt-1 | European option |

```bash
# Add new region to your OCI config
oci setup config  # and add new profile for each region

# Or use region override
oci compute instance launch --region ca-montreal-1 ...
```

</details>

<details>
<summary><strong>3. Use smaller configuration</strong></summary>

Instead of full 4 OCPU / 24GB, try:
- 2 OCPU / 12GB (often more available)
- 1 OCPU / 6GB (highest availability)

```bash
# Check for 2 OCPU availability
./scripts/oci-monitor-and-deploy.sh \
  --stack-id <STACK_OCID> \
  --ocpus 2 \
  --memory-gb 12
```

</details>

<details>
<summary><strong>4. Split across availability domains</strong></summary>

Total free tier is 4 OCPU + 24GB. You can split across instances:

- 2 instances × 2 OCPU / 12GB each
- 4 instances × 1 OCPU / 6GB each
- Mix: 1×3 OCPU + 1×1 OCPU

This increases chances of finding capacity in at least one AD.

</details>

<details>
<summary><strong>5. Optimal timing</strong></summary>

Capacity tends to be more available:
- Early morning (UTC)
- Weekends
- Beginning of month (when free tier resets)

Run the monitor script during these times for best results.

</details>

---

## Understanding Availability Domains

Each region has 1-3 availability domains (ADs). ADs are isolated data centers.

```bash
# List your region's ADs
oci iam availability-domain list --query 'data[*].name' --output table
```

Example output:
```
+----------------------------+
| name                       |
+----------------------------+
| xxxx:US-ASHBURN-AD-1      |
| xxxx:US-ASHBURN-AD-2      |
| xxxx:US-ASHBURN-AD-3      |
+----------------------------+
```

When launching instances, specify the full AD name:
```bash
--availability-domain "xxxx:US-ASHBURN-AD-1"
```

---

## Error Messages

<details>
<summary><strong>OUT_OF_HOST_CAPACITY</strong></summary>

```
ServiceError: Out of host capacity
```

**Meaning**: No physical servers available in that AD for A1 shape.

**Action**: Try different AD, region, or smaller config.

</details>

<details>
<summary><strong>LimitExceeded</strong></summary>

```
ServiceError: LimitExceeded
```

**Meaning**: You've hit your account's service limit.

**Action**: Check existing A1 instances. Free tier is 4 OCPU + 24GB total.

```bash
oci compute instance list --compartment-id $COMPARTMENT_ID \
  --query 'data[?contains(shape,`A1`)].{name:"display-name",ocpus:"shape-config".ocpus}'
```

</details>

<details>
<summary><strong>InternalError</strong></summary>

```
ServiceError: InternalError
```

**Meaning**: OCI backend issue, often capacity-related.

**Action**: Wait and retry. Usually resolves in minutes.

</details>

---

## Creating Resource Manager Stacks

For use with `oci-monitor-and-deploy.sh`, you need a Resource Manager stack:

<details>
<summary><strong>Creating a stack</strong></summary>

1. **Prepare Terraform configuration** (or use OCI templates)

2. **Create stack via CLI**:
```bash
oci resource-manager stack create \
  --compartment-id $COMPARTMENT_ID \
  --config-source '{"configSourceType":"ZIP_UPLOAD"}' \
  --display-name "my-arm-stack" \
  --terraform-version "1.0.x"
```

3. **Or via Console**:
   - Go to Resource Manager → Stacks → Create Stack
   - Upload your Terraform files or use a template
   - Note the stack OCID

4. **Use with monitor script**:
```bash
./scripts/oci-monitor-and-deploy.sh --stack-id ocid1.ormstack.oc1..xxx
```

</details>

---

## Quick Reference

| Scenario | Solution |
|----------|----------|
| OUT_OF_HOST_CAPACITY | Try different AD or region |
| Need to wait for capacity | Use `oci-monitor-and-deploy.sh` |
| Can't get full 4 OCPU | Try 2 OCPU config |
| Need 4 OCPU urgently | Split across 2 instances |
| Recurring capacity issues | Consider different region |

---

## Next Steps

- Return to [main skill](../SKILL.md)
- See [Networking Guide](./NETWORKING.md) for VCN setup
- See [Troubleshooting Guide](./TROUBLESHOOTING.md) for other issues

### oci: docs/CONFIG.md

# OCI CLI Configuration Guide

**Purpose**: Configure OCI CLI credentials and authentication.
**Prerequisites**: [OCI CLI Installed](./INSTALL.md)
**Time**: 5-10 minutes
**Next Step**: Return to [SKILL.md](../SKILL.md) for deployment

---

## Contents
- Quick Check
- Configuration Methods
- Finding Your OCIDs
- Multiple Profiles
- Verify Configuration
- Troubleshooting
- Environment Variables (Alternative)
- Instance Principal Authentication
- Security Best Practices
- Next Steps
- Official Resources

---

## Quick Check

First, verify if OCI CLI is already configured:

```bash
oci iam availability-domain list
```

If you see availability domains listed, you're already configured. Return to [main skill](../SKILL.md).

---

## Configuration Methods

### Method 1: Interactive Setup (Recommended)

```bash
oci setup config
```

This wizard will prompt you for:

| Prompt | Value | Where to Find |
|--------|-------|---------------|
| Config file location | `~/.oci/config` (default) | Press Enter |
| User OCID | `ocid1.user.oc1..xxx` | OCI Console → Profile → My Profile |
| Tenancy OCID | `ocid1.tenancy.oc1..xxx` | OCI Console → Profile → Tenancy |
| Region | e.g., `us-ashburn-1` | OCI Console → top bar |
| Generate API key? | `Y` (yes) | Creates new key pair |
| Key file location | `~/.oci/oci_api_key.pem` | Press Enter |

After completion, **upload your public key to OCI**:
```bash
cat ~/.oci/oci_api_key_public.pem
```

Copy the output and add it in: **OCI Console → Profile → API Keys → Add API Key → Paste Public Key**

---

### Method 2: Manual Configuration

<details>
<summary><strong>Create config file manually</strong></summary>

Create `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

Set proper permissions:
```bash
chmod 600 ~/.oci/config
chmod 600 ~/.oci/oci_api_key.pem
```

</details>

---

## Finding Your OCIDs

<details>
<summary><strong>🔑 User OCID</strong></summary>

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click Profile icon (top-right) → **My Profile**
3. Under **User Information**, copy the **OCID**

Format: `ocid1.user.oc1..aaaaaaaxxxxxxxxx`

</details>

<details>
<summary><strong>🏢 Tenancy OCID</strong></summary>

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click Profile icon (top-right) → **Tenancy: [name]**
3. Under **Tenancy Information**, copy the **OCID**

Format: `ocid1.tenancy.oc1..aaaaaaaxxxxxxxxx`

</details>

<details>
<summary><strong>🌍 Region Identifier</strong></summary>

1. Look at the top bar of OCI Console
2. Click the region dropdown
3. Note the region identifier (not the friendly name)

Common regions:
| Friendly Name | Identifier |
|--------------|------------|
| US East (Ashburn) | `us-ashburn-1` |
| US West (Phoenix) | `us-phoenix-1` |
| Canada (Toronto) | `ca-toronto-1` |
| Canada (Montreal) | `ca-montreal-1` |
| UK (London) | `uk-london-1` |
| Germany (Frankfurt) | `eu-frankfurt-1` |

[Full region list](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm)

</details>

<details>
<summary><strong>🔐 API Key Fingerprint</strong></summary>

After uploading your public key:

1. OCI Console → Profile → **API Keys**
2. Find your key in the list
3. Copy the **Fingerprint**

Format: `xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx`

</details>

---

## Multiple Profiles

Use named profiles for multiple accounts or environments:

```ini
[DEFAULT]
user=ocid1.user.oc1..default_user
tenancy=ocid1.tenancy.oc1..default_tenancy
region=us-ashburn-1
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
key_file=~/.oci/default_api_key.pem

[PRODUCTION]
user=ocid1.user.oc1..prod_user
tenancy=ocid1.tenancy.oc1..prod_tenancy
region=us-phoenix-1
fingerprint=yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy
key_file=~/.oci/prod_api_key.pem

[DANIEL]
user=ocid1.user.oc1..daniel_user
tenancy=ocid1.tenancy.oc1..daniel_tenancy
region=ca-montreal-1
fingerprint=zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz:zz
key_file=~/.oci/daniel_api_key.pem
```

Use a specific profile:
```bash
oci iam region list --profile PRODUCTION
```

---

## Verify Configuration

```bash
# Test default profile
oci iam availability-domain list

# Test specific profile
oci iam availability-domain list --profile DANIEL

# List regions accessible to your account
oci iam region list
```

Expected output: JSON with availability domains or regions.

---

## Troubleshooting

<details>
<summary><strong>NotAuthenticated Error</strong></summary>

**Error**: `ServiceError: NotAuthenticated`

**Causes & Fixes**:

1. **API key not uploaded to OCI**
   ```bash
   # Show public key to upload
   cat ~/.oci/oci_api_key_public.pem
   ```
   Add in: OCI Console → Profile → API Keys → Add API Key

2. **Wrong fingerprint in config**
   - Compare fingerprint in `~/.oci/config` with OCI Console

3. **Clock skew**
   ```bash
   # Check system time
   date
   # Sync time (Linux)
   sudo ntpdate pool.ntp.org
   ```

</details>

<details>
<summary><strong>Config file not found</strong></summary>

**Error**: `Could not find config file at ~/.oci/config`

**Fix**:
```bash
# Create directory
mkdir -p ~/.oci

# Run setup
oci setup config
```

</details>

<details>
<summary><strong>Private key file not found</strong></summary>

**Error**: `Could not find private key file`

**Fix**:
```bash
# Check if key exists
ls -la ~/.oci/

# If missing, generate new key pair
oci setup keys

# Then upload public key to OCI Console
```

</details>

<details>
<summary><strong>Permission denied on key file</strong></summary>

**Error**: `Permission denied` or `key file permissions too open`

**Fix**:
```bash
chmod 600 ~/.oci/config
chmod 600 ~/.oci/oci_api_key.pem
```

</details>

<details>
<summary><strong>Invalid region</strong></summary>

**Error**: `region not in valid_regions`

**Fix**:
```bash
# List valid regions
oci iam region list

# Use exact region identifier in config
region=us-ashburn-1  # correct
region=US-Ashburn-1  # wrong (case sensitive)
```

</details>

---

## Environment Variables (Alternative)

Instead of config file, use environment variables:

```bash
export OCI_CLI_USER=ocid1.user.oc1..xxx
export OCI_CLI_TENANCY=ocid1.tenancy.oc1..xxx
export OCI_CLI_FINGERPRINT=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
export OCI_CLI_KEY_FILE=~/.oci/oci_api_key.pem
export OCI_CLI_REGION=us-ashburn-1
```

---

## Instance Principal Authentication

For scripts running on OCI compute instances:

<details>
<summary><strong>Set up Instance Principal</strong></summary>

1. Create a Dynamic Group:
   ```
   OCI Console → Identity → Dynamic Groups → Create
   Name: MyInstanceGroup
   Rule: instance.compartment.id = 'ocid1.compartment.oc1..xxx'
   ```

2. Create Policy:
   ```
   Allow dynamic-group MyInstanceGroup to manage all-resources in compartment MyCompartment
   ```

3. Use in CLI:
   ```bash
   oci --auth instance_principal iam region list
   ```

No config file needed when running on the instance.

</details>

---

## Security Best Practices

- **Never commit** `~/.oci/config` or private keys to git
- **Rotate API keys** periodically (OCI Console → API Keys → Add/Remove)
- **Use instance principals** when running on OCI compute
- **Limit permissions** with IAM policies (least privilege)
- **Use separate profiles** for dev/staging/prod

---

## Next Steps

Once configured, return to the [main skill](../SKILL.md) for deployment instructions.

---

## Official Resources

- [OCI CLI Configuration](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliconfigure.htm)
- [API Key Management](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm)
- [Instance Principal Authentication](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm)

### oci: docs/INSTALL.md

# OCI CLI Installation Guide

**Purpose**: Install the Oracle Cloud Infrastructure CLI on your system.
**Time**: 5-10 minutes
**Next Step**: [Configure OCI CLI](./CONFIG.md)

---

## Contents
- Quick Check
- Installation by Operating System
- Verify Installation
- Troubleshooting
- Next Steps
- Official Resources

---

## Quick Check

First, verify if OCI CLI is already installed:

```bash
oci --version
```

If you see a version number (e.g., `3.x.x`), skip to [Configuration](./CONFIG.md).

---

## Installation by Operating System

<details>
<summary><strong>🐧 Linux</strong></summary>

### Automatic Installation (Recommended)

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Manual Installation

```bash
# Download installer
curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o install.sh

# Run with options
bash install.sh --install-dir ~/lib/oracle-cli --exec-dir ~/bin/oci-cli
```

### Package Managers

**Ubuntu/Debian:**
```bash
# Add Oracle repository key
curl -sL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install_oci_cli_ubuntu.sh | bash
```

**RHEL/CentOS/Fedora:**
```bash
# Using dnf
sudo dnf install oraclelinux-developer-release-el8
sudo dnf install python36-oci-cli

# Or using yum
sudo yum install python36-oci-cli
```

### Post-Install: Update PATH

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export PATH=$PATH:~/bin
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

</details>

<details>
<summary><strong>🍎 macOS</strong></summary>

### Automatic Installation (Recommended)

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Using Homebrew

```bash
brew install oci-cli
```

### Manual Installation

```bash
# Download installer
curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o install.sh

# Run installer
bash install.sh
```

### Post-Install: Update PATH

Add to `~/.zshrc` (default macOS shell):

```bash
export PATH=$PATH:~/bin
```

Reload:
```bash
source ~/.zshrc
```

</details>

<details>
<summary><strong>🪟 Windows</strong></summary>

### MSI Installer (Recommended)

1. Download the latest MSI from [OCI CLI Releases](https://github.com/oracle/oci-cli/releases)
2. Run the MSI installer
3. Follow the installation wizard
4. Open a **new** PowerShell or Command Prompt window

### PowerShell Script

```powershell
# Run in PowerShell as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-WebRequest https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1 -OutFile install.ps1
.\install.ps1 -AcceptAllDefaults
```

### Git Bash / MSYS2

```bash
# From Git Bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
```

### Post-Install

Open a **new** terminal window to ensure PATH is updated.

</details>

<details>
<summary><strong>🐳 Docker</strong></summary>

### Using Official Docker Image

```bash
# Pull official image
docker pull ghcr.io/oracle/oci-cli:latest

# Run OCI CLI command
docker run --rm -v ~/.oci:/root/.oci ghcr.io/oracle/oci-cli oci --version

# Create alias for convenience
alias oci='docker run --rm -v ~/.oci:/root/.oci ghcr.io/oracle/oci-cli oci'
```

### Custom Dockerfile

```dockerfile
FROM python:3.11-slim
RUN pip install oci-cli
ENTRYPOINT ["oci"]
```

</details>

<details>
<summary><strong>☁️ Cloud Shell</strong></summary>

OCI Cloud Shell has OCI CLI **pre-installed**. No installation needed.

1. Log in to [OCI Console](https://cloud.oracle.com)
2. Click the Cloud Shell icon (top-right terminal icon)
3. CLI is ready to use with your credentials

</details>

---

## Verify Installation

After installation, verify:

```bash
# Check version
oci --version

# Expected output: 3.x.x
```

---

## Troubleshooting

<details>
<summary><strong>Command not found</strong></summary>

**Cause**: PATH not updated or terminal not restarted.

**Fix**:
```bash
# Linux/macOS - reload shell profile
source ~/.bashrc  # or ~/.zshrc

# Or restart your terminal
```

For Windows, open a **new** PowerShell/Command Prompt window.

</details>

<details>
<summary><strong>Python version errors</strong></summary>

**Cause**: OCI CLI requires Python 3.6+.

**Fix**:
```bash
# Check Python version
python3 --version

# Install Python if needed
# Ubuntu/Debian
sudo apt install python3 python3-pip

# macOS
brew install python3

# Then reinstall OCI CLI
```

</details>

<details>
<summary><strong>Permission denied</strong></summary>

**Cause**: Install script needs write permissions.

**Fix**:
```bash
# Use user-level installation (no sudo needed)
bash install.sh --install-dir ~/lib/oracle-cli --exec-dir ~/bin

# Or fix permissions
chmod +x install.sh
```

</details>

<details>
<summary><strong>SSL/TLS errors</strong></summary>

**Cause**: Outdated certificates or proxy issues.

**Fix**:
```bash
# Update CA certificates
# Ubuntu/Debian
sudo apt update && sudo apt install ca-certificates

# macOS
brew install ca-certificates

# If behind proxy, set environment variables
export HTTPS_PROXY=http://proxy.example.com:8080
```

</details>

---

## Next Steps

Once OCI CLI is installed, proceed to **[Configuration](./CONFIG.md)** to set up your credentials.

---

## Official Resources

- [OCI CLI Installation Docs](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- [OCI CLI GitHub](https://github.com/oracle/oci-cli)
- [OCI CLI Releases](https://github.com/oracle/oci-cli/releases)

### oci: docs/NETWORKING.md

# OCI Networking Guide

**Purpose**: Configure VCNs, subnets, security lists, and internet access.
**Prerequisites**: [OCI CLI configured](./CONFIG.md)

---

## Contents
- Overview
- Quick Setup
- Creating a VCN
- Creating a Subnet
- Internet Gateway
- Security Lists
- Protocol Numbers
- Common CIDR Blocks
- Troubleshooting
- Advanced Topics
- Quick Reference
- Next Steps

---

## Overview

OCI networking components:

```
┌─────────────────────────────────────────────────────────────┐
│ VCN (10.0.0.0/16)                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Public Subnet (10.0.1.0/24)                         │   │
│  │  ┌──────────────┐  ┌──────────────┐                │   │
│  │  │  Instance    │  │  Instance    │                │   │
│  │  │  10.0.1.10   │  │  10.0.1.11   │                │   │
│  │  └──────────────┘  └──────────────┘                │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                              │
│                    ┌─────────┴─────────┐                   │
│                    │ Internet Gateway   │                   │
│                    └─────────┬─────────┘                   │
└──────────────────────────────┼──────────────────────────────┘
                               │
                          Internet
```

---

## Quick Setup

The `oci-infrastructure-setup.sh` script handles all networking automatically. For manual setup:

```bash
# Set variables
export TENANCY_OCID="ocid1.tenancy.oc1..xxx"
export COMPARTMENT_ID="ocid1.compartment.oc1..xxx"
export VCN_CIDR="10.0.0.0/16"
export SUBNET_CIDR="10.0.1.0/24"
```

---

## Creating a VCN

```bash
VCN_ID=$(oci network vcn create \
  --compartment-id $COMPARTMENT_ID \
  --cidr-block $VCN_CIDR \
  --display-name "my-vcn" \
  --dns-label "myvcn" \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "VCN ID: $VCN_ID"
```

<details>
<summary><strong>VCN options explained</strong></summary>

| Option | Description |
|--------|-------------|
| `--cidr-block` | IP range for the VCN (e.g., 10.0.0.0/16) |
| `--display-name` | Human-readable name |
| `--dns-label` | DNS hostname prefix (alphanumeric, max 15 chars) |
| `--is-ipv6enabled` | Enable IPv6 (optional) |

**CIDR recommendations**:
- `/16` = 65,536 addresses (recommended)
- `/20` = 4,096 addresses
- `/24` = 256 addresses (minimum for most use cases)

</details>

---

## Creating a Subnet

```bash
SUBNET_ID=$(oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --cidr-block $SUBNET_CIDR \
  --display-name "public-subnet" \
  --dns-label "public" \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "Subnet ID: $SUBNET_ID"
```

<details>
<summary><strong>Public vs Private subnets</strong></summary>

**Public subnet** (default):
- Instances can have public IPs
- Requires internet gateway for internet access
- Use for web servers, bastion hosts

**Private subnet**:
- No public IPs
- Use NAT gateway for outbound internet
- Use for databases, internal services

```bash
# Create private subnet
oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --cidr-block "10.0.2.0/24" \
  --display-name "private-subnet" \
  --prohibit-public-ip-on-vnic true
```

</details>

---

## Internet Gateway

Required for instances to access the internet:

```bash
# Create internet gateway
IGW_ID=$(oci network internet-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name "internet-gateway" \
  --is-enabled true \
  --wait-for-state AVAILABLE \
  --query 'data.id' \
  --raw-output)

echo "Internet Gateway ID: $IGW_ID"
```

### Add Route to Default Route Table

```bash
# Get default route table ID
RT_ID=$(oci network route-table list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' \
  --raw-output)

# Add route for all internet traffic
oci network route-table update \
  --rt-id $RT_ID \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW_ID\"}]" \
  --force
```

---

## Security Lists

Control inbound and outbound traffic:

```bash
# Get default security list
SL_ID=$(oci network security-list list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' \
  --raw-output)
```

### Common Rules

<details>
<summary><strong>SSH access (port 22)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}
    }
  ]' \
  --force
```

**Security note**: Restrict source to your IP for production:
```json
"source": "203.0.113.10/32"
```

</details>

<details>
<summary><strong>HTTP/HTTPS (ports 80, 443)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 80, "max": 80}}
    },
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 443, "max": 443}}
    }
  ]' \
  --force
```

</details>

<details>
<summary><strong>Coolify ports</strong></summary>

```bash
# Coolify requires: 22, 80, 443, 8000, 6001, 6002
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 80, "max": 80}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 443, "max": 443}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 8000, "max": 8000}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 6001, "max": 6002}}}
  ]' \
  --force
```

</details>

<details>
<summary><strong>KASM ports</strong></summary>

```bash
# KASM requires: 22, 8443, 3389, 3000-4000
oci network security-list update \
  --security-list-id $SL_ID \
  --ingress-security-rules '[
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 8443, "max": 8443}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 3389, "max": 3389}}},
    {"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 3000, "max": 4000}}}
  ]' \
  --force
```

</details>

<details>
<summary><strong>All outbound traffic (egress)</strong></summary>

```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --egress-security-rules '[
    {"destination": "0.0.0.0/0", "protocol": "all"}
  ]' \
  --force
```

</details>

---

## Protocol Numbers

| Protocol | Number |
|----------|--------|
| All | all |
| ICMP | 1 |
| TCP | 6 |
| UDP | 17 |

---

## Common CIDR Blocks

| CIDR | Addresses | Use Case |
|------|-----------|----------|
| 10.0.0.0/16 | 65,536 | Full VCN |
| 10.0.1.0/24 | 256 | Single subnet |
| 10.0.0.0/8 | 16.7M | Private range (RFC 1918) |
| 0.0.0.0/0 | All | Internet (any IP) |
| x.x.x.x/32 | 1 | Single IP |

---

## Troubleshooting

<details>
<summary><strong>Cannot reach internet from instance</strong></summary>

**Checklist**:
1. Internet gateway exists
2. Route table has 0.0.0.0/0 → IGW route
3. Security list allows outbound traffic
4. Instance has public IP

```bash
# Check routes
oci network route-table get --rt-id $RT_ID --query 'data."route-rules"'

# Check instance public IP
oci compute instance list-vnics --instance-id $INSTANCE_ID --query 'data[0]."public-ip"'
```

</details>

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Checklist**:
1. Security list has port 22 ingress rule
2. Instance has public IP
3. Correct SSH key used
4. Instance is RUNNING state

```bash
# Check security list ingress rules
oci network security-list get --security-list-id $SL_ID --query 'data."ingress-security-rules"'

# Test connectivity
nc -zv <public-ip> 22
```

</details>

<details>
<summary><strong>CIDR block conflicts</strong></summary>

**Error**: "CIDR block conflicts with existing VCN"

**Fix**: Use non-overlapping CIDR blocks:
- VCN 1: 10.0.0.0/16
- VCN 2: 10.1.0.0/16
- VCN 3: 10.2.0.0/16

Or use different ranges:
- 172.16.0.0/16
- 192.168.0.0/16

</details>

---

## Advanced Topics

<details>
<summary><strong>VCN Peering</strong></summary>

Connect two VCNs:

```bash
# Create local peering gateway in VCN 1
LPG1_ID=$(oci network local-peering-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN1_ID \
  --display-name "lpg-to-vcn2" \
  --query 'data.id' --raw-output)

# Create local peering gateway in VCN 2
LPG2_ID=$(oci network local-peering-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN2_ID \
  --display-name "lpg-to-vcn1" \
  --query 'data.id' --raw-output)

# Connect them
oci network local-peering-gateway connect \
  --local-peering-gateway-id $LPG1_ID \
  --peer-id $LPG2_ID
```

</details>

<details>
<summary><strong>NAT Gateway (for private subnets)</strong></summary>

```bash
# Create NAT gateway
NAT_ID=$(oci network nat-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name "nat-gateway" \
  --query 'data.id' --raw-output)

# Add route for private subnet
oci network route-table update \
  --rt-id $PRIVATE_RT_ID \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$NAT_ID\"}]" \
  --force
```

</details>

<details>
<summary><strong>Service Gateway (for OCI services)</strong></summary>

Access OCI services (Object Storage, etc.) without internet:

```bash
# Get service OCID
SERVICE_ID=$(oci network service list --query 'data[0].id' --raw-output)

# Create service gateway
SGW_ID=$(oci network service-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --services "[{\"serviceId\":\"$SERVICE_ID\"}]" \
  --display-name "service-gateway" \
  --query 'data.id' --raw-output)
```

</details>

---

## Quick Reference

| Component | Purpose |
|-----------|---------|
| VCN | Virtual network container |
| Subnet | IP address range within VCN |
| Internet Gateway | Connect to internet |
| NAT Gateway | Outbound internet for private subnets |
| Route Table | Traffic routing rules |
| Security List | Firewall rules (stateful) |

---

## Next Steps

- Return to [main skill](../SKILL.md)
- See [Troubleshooting Guide](./TROUBLESHOOTING.md) for more help

### oci: docs/TROUBLESHOOTING.md

# OCI Troubleshooting Guide

**Purpose**: Quick solutions for common OCI deployment issues.

---

## Contents
- Quick Diagnostic
- Issue Categories
- CLI & Authentication
- Capacity & Limits
- Networking
- Compute
- General Errors
- Debug Mode
- Getting Help
- Quick Fixes Summary

---

## Quick Diagnostic

Run this first to identify issues:

```bash
oci --version
oci iam availability-domain list
./scripts/oci-check-oci-capacity.sh
```

---

## Issue Categories

- [CLI & Authentication](#cli--authentication)
- [Capacity & Limits](#capacity--limits)
- [Networking](#networking)
- [Compute](#compute)
- [General Errors](#general-errors)

---

## CLI & Authentication

<details>
<summary><strong>oci: command not found</strong></summary>

**Cause**: OCI CLI not installed or not in PATH.

**Solutions**:

1. Install OCI CLI (see `docs/INSTALL.md`) and verify:
   ```bash
   oci --version
   ```

2. Or restart terminal to reload PATH:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

3. Check installation:
   ```bash
   which oci
   oci --version
   ```

See [Installation Guide](./INSTALL.md) for details.

</details>

<details>
<summary><strong>ServiceError: NotAuthenticated</strong></summary>

**Cause**: API key not configured or invalid.

**Checklist**:

1. **Config file exists**:
   ```bash
   cat ~/.oci/config
   ```

2. **API key uploaded to OCI**:
   - OCI Console → Profile → API Keys
   - Verify fingerprint matches config

3. **Key file exists and has correct permissions**:
   ```bash
   ls -la ~/.oci/oci_api_key.pem
   chmod 600 ~/.oci/oci_api_key.pem
   ```

4. **Test authentication**:
   ```bash
   oci iam region list
   ```

See [Configuration Guide](./CONFIG.md) for details.

</details>

<details>
<summary><strong>Config file not found</strong></summary>

**Cause**: No `~/.oci/config` file.

**Fix**:
```bash
oci setup config
```

Follow the prompts to configure credentials.

</details>

<details>
<summary><strong>Private key file not found</strong></summary>

**Cause**: Key file path in config is wrong or file missing.

**Fix**:

1. Check config:
   ```bash
   grep key_file ~/.oci/config
   ```

2. Verify file exists:
   ```bash
   ls -la ~/.oci/oci_api_key.pem
   ```

3. If missing, generate new keys:
   ```bash
   oci setup keys
   ```
   Then upload public key to OCI Console.

</details>

<details>
<summary><strong>Fingerprint mismatch</strong></summary>

**Cause**: Fingerprint in config doesn't match OCI Console.

**Fix**:

1. Get fingerprint from OCI Console:
   - Profile → API Keys → Copy fingerprint

2. Update config:
   ```bash
   nano ~/.oci/config
   # Update fingerprint= line
   ```

</details>

<details>
<summary><strong>Clock skew error</strong></summary>

**Cause**: System time differs significantly from server.

**Fix**:
```bash
# Linux
sudo timedatectl set-ntp true
# or
sudo ntpdate pool.ntp.org

# macOS
sudo sntp -sS time.apple.com
```

</details>

---

## Capacity & Limits

<details>
<summary><strong>OUT_OF_HOST_CAPACITY</strong></summary>

**Cause**: No ARM instances available in the selected AD.

**Solutions**:

1. Check other availability domains:
   ```bash
   ./scripts/oci-check-oci-capacity.sh
   ```

2. Use automated monitoring:
   ```bash
   ./scripts/oci-monitor-and-deploy.sh --stack-id <STACK_OCID>
   ```

3. Try different region

4. Try smaller config (2 OCPU / 12GB)

See [Capacity Guide](./CAPACITY.md) for details.

</details>

<details>
<summary><strong>LimitExceeded / Service limit exceeded</strong></summary>

**Cause**: Account limit reached for A1 instances.

**Check current usage**:
```bash
oci compute instance list \
  --compartment-id $COMPARTMENT_ID \
  --query 'data[?contains(shape,`A1`)].{name:"display-name", ocpus:"shape-config".ocpus, memory:"shape-config"."memory-in-gbs", state:"lifecycle-state"}' \
  --output table
```

**Free tier limits**: 4 OCPUs + 24GB RAM total

**Fix**: Terminate unused A1 instances or reduce new instance size.

</details>

<details>
<summary><strong>TooManyRequests</strong></summary>

**Cause**: API rate limiting.

**Fix**: Wait and retry with exponential backoff:
```bash
sleep 60
# Then retry command
```

For scripts, add delays between API calls.

</details>

---

## Networking

<details>
<summary><strong>Cannot SSH to instance</strong></summary>

**Checklist**:

1. **Instance is running**:
   ```bash
   oci compute instance get --instance-id $INSTANCE_ID \
     --query 'data."lifecycle-state"'
   ```

2. **Has public IP**:
   ```bash
   oci compute instance list-vnics --instance-id $INSTANCE_ID \
     --query 'data[0]."public-ip"'
   ```

3. **Security list allows SSH**:
   ```bash
   oci network security-list get --security-list-id $SL_ID \
     --query 'data."ingress-security-rules"[?contains("tcp-options"."destination-port-range".min, `22`)]'
   ```

4. **Internet gateway exists**:
   ```bash
   oci network internet-gateway list --compartment-id $COMPARTMENT_ID --vcn-id $VCN_ID
   ```

5. **Route table has internet route**:
   ```bash
   oci network route-table get --rt-id $RT_ID --query 'data."route-rules"'
   ```

6. **Correct SSH key**:
   ```bash
   ssh -i ~/.ssh/your_key -o IdentitiesOnly=yes ubuntu@<public-ip>
   ```

7. **Wait after launch** (1-2 minutes for cloud-init)

</details>

<details>
<summary><strong>Instance cannot reach internet</strong></summary>

**Checklist**:

1. **Internet gateway exists**

2. **Route table has 0.0.0.0/0 route to IGW**

3. **Security list allows outbound traffic**:
   ```bash
   oci network security-list get --security-list-id $SL_ID \
     --query 'data."egress-security-rules"'
   ```

**Quick fix** - allow all outbound:
```bash
oci network security-list update \
  --security-list-id $SL_ID \
  --egress-security-rules '[{"destination": "0.0.0.0/0", "protocol": "all"}]' \
  --force
```

</details>

<details>
<summary><strong>CIDR block conflicts</strong></summary>

**Cause**: Overlapping IP ranges between VCNs.

**Fix**: Use non-overlapping CIDR blocks:
```
VCN 1: 10.0.0.0/16
VCN 2: 10.1.0.0/16
VCN 3: 10.2.0.0/16
```

</details>

<details>
<summary><strong>InvalidParameter: Security rule</strong></summary>

**Cause**: Malformed security rule JSON.

**Fix**: Validate JSON syntax:
```bash
echo '[{"source": "0.0.0.0/0", "protocol": "6", "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}}]' | jq .
```

Common issues:
- Missing quotes around keys
- Wrong field names (use camelCase)
- Protocol must be string ("6" not 6)

</details>

---

## Compute

<details>
<summary><strong>Shape not available</strong></summary>

**Cause**: Wrong image/shape combination.

**Rule**: ARM64 shape (A1.Flex) requires ARM64 image.

**Find ARM64 Ubuntu images**:
```bash
oci compute image list \
  --compartment-id $TENANCY_OCID \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --query 'data[*].{id:id, name:"display-name"}' \
  --output table
```

</details>

<details>
<summary><strong>Instance stuck in PROVISIONING</strong></summary>

**Cause**: Usually capacity issues or backend delays.

**Check status**:
```bash
oci compute instance get --instance-id $INSTANCE_ID \
  --query 'data.{state:"lifecycle-state", time:"time-created"}'
```

**If stuck > 10 minutes**: Terminate and retry in different AD.

</details>

<details>
<summary><strong>Instance terminated unexpectedly</strong></summary>

**Cause**: Could be capacity reclamation or policy.

**Check termination reason**:
```bash
oci audit event list \
  --compartment-id $COMPARTMENT_ID \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query 'data[?contains("event-type", `Terminate`)].{type:"event-type", time:"event-time", source:"event-source"}'
```

</details>

<details>
<summary><strong>Cannot attach block volume</strong></summary>

**Cause**: Volume and instance must be in same AD.

**Check**:
```bash
# Instance AD
oci compute instance get --instance-id $INSTANCE_ID \
  --query 'data."availability-domain"'

# Volume AD
oci bv volume get --volume-id $VOLUME_ID \
  --query 'data."availability-domain"'
```

</details>

---

## General Errors

<details>
<summary><strong>InvalidParameter</strong></summary>

**Cause**: Required parameter missing or invalid format.

**Debug**:
```bash
# Add --debug to see full request/response
oci compute instance launch --debug ...
```

Check:
- OCIDs are complete (start with `ocid1.`)
- Correct parameter names
- Valid JSON format for complex params

</details>

<details>
<summary><strong>NotAuthorizedOrNotFound</strong></summary>

**Cause**: Resource doesn't exist or no permission.

**Check**:

1. Resource exists:
   ```bash
   oci <service> <resource> get --<resource>-id <OCID>
   ```

2. Correct compartment:
   ```bash
   oci <service> <resource> list --compartment-id $COMPARTMENT_ID
   ```

3. IAM policies allow access

</details>

<details>
<summary><strong>InternalError</strong></summary>

**Cause**: OCI backend issue.

**Fix**: Wait 1-5 minutes and retry. Usually transient.

If persistent, check [OCI Status](https://ocistatus.oraclecloud.com/).

</details>

<details>
<summary><strong>Timeout errors</strong></summary>

**Cause**: Operation taking too long.

**Fix**:

1. Increase timeout:
   ```bash
   oci compute instance launch --wait-for-state RUNNING --wait-interval-seconds 30 --max-wait-seconds 600
   ```

2. Don't wait, poll separately:
   ```bash
   # Launch without wait
   INSTANCE_ID=$(oci compute instance launch ... --query 'data.id' --raw-output)

   # Poll for status
   while true; do
     STATE=$(oci compute instance get --instance-id $INSTANCE_ID --query 'data."lifecycle-state"' --raw-output)
     [[ "$STATE" == "RUNNING" ]] && break
     sleep 30
   done
   ```

</details>

---

## Debug Mode

For detailed troubleshooting, enable debug output:

```bash
# Full debug (very verbose)
oci --debug compute instance list

# Log to file
oci --debug compute instance list 2>&1 | tee oci-debug.log
```

---

## Getting Help

1. **Check OCI Status**: https://ocistatus.oraclecloud.com/
2. **OCI Documentation**: https://docs.oracle.com/en-us/iaas/
3. **OCI CLI Reference**: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/
4. **Support Request**: OCI Console → Help → Create Support Request

---

## Quick Fixes Summary

| Error | Quick Fix |
|-------|-----------|
| Command not found | Install OCI CLI (`docs/INSTALL.md`) |
| NotAuthenticated | Check `~/.oci/config`, upload API key |
| OUT_OF_HOST_CAPACITY | Try different AD/region |
| LimitExceeded | Check existing A1 instances |
| Cannot SSH | Check security list, public IP, IGW |
| Shape not available | Use ARM64 image with ARM64 shape |
| InternalError | Wait and retry |
